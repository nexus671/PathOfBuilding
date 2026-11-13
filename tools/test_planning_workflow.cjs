// A real MCP stdio client drives an isolated native host and explicit UI review.
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const {spawn}=require('node:child_process');
const {createInterface}=require('node:readline');
const root=path.resolve(__dirname,'..');
const directory=fs.mkdtempSync(path.join(os.tmpdir(),'pob-planning-workflow-'));
const lua=process.argv[2] || 'luajit';
const children=[];const diagnostics=[];
function connection(child,prefix='') {
  children.push(child);const pending=new Map();let next=0;let ready,rejectReady,didStart=false;
  const started=new Promise((resolve,reject)=>{ready=resolve;rejectReady=reject;});
  child.stderr.on('data',data=>diagnostics.push(data.toString()));
  createInterface({input:child.stdout}).on('line',line=>{
    if(prefix && !line.startsWith(prefix)){diagnostics.push(line);return;}
    let message;try{message=JSON.parse(line.slice(prefix.length));}catch{diagnostics.push(line);return;}
    if(message.ready){didStart=true;ready(message);}
    const waiter=pending.get(message.id);if(waiter){pending.delete(message.id);clearTimeout(waiter.timer);waiter.resolve(message);}
  });
  child.on('exit',code=>{const error=new Error(`Child exited ${code}: ${diagnostics.join('\n')}`);if(prefix && !didStart)rejectReady(error);for(const waiter of pending.values()){clearTimeout(waiter.timer);waiter.reject(error);}});
  child.on('error',error=>{if(prefix && !didStart)rejectReady(error);for(const waiter of pending.values()){clearTimeout(waiter.timer);waiter.reject(error);}});
  return {started,send(body){return new Promise((resolve,reject)=>{const id=++next;pending.set(id,{resolve,reject,timer:setTimeout(()=>{pending.delete(id);reject(new Error('Workflow response timed out'));},60000)});child.stdin.write(JSON.stringify({id,...body})+'\n');});}};
}
async function main(){
  const environment={...process.env,LUA_PATH:'../runtime/lua/?.lua;../runtime/lua/?/init.lua;;'};
  if(process.platform==='win32'){environment.LUA_CPATH=path.join(root,'runtime','?.dll')+';;';environment.PATH=path.join(root,'runtime')+path.delimiter+process.env.PATH;}
  const native=connection(spawn(lua,['../tools/planning_workflow_host.lua',directory],{cwd:path.join(root,'src'),env:environment}),'WORKFLOW\t');
  let startupTimer;
  await Promise.race([native.started,new Promise((_,reject)=>{startupTimer=setTimeout(()=>reject(new Error('Native startup timed out')),60000);})]).finally(()=>clearTimeout(startupTimer));
  const mcp=connection(spawn(process.execPath,[path.join(root,'src/AI/McpServer.cjs'),path.join(directory,'AI-encounter.json')]));
  const rpc=(method,params)=>mcp.send({jsonrpc:'2.0',method,params});
  const initialized=await rpc('initialize',{protocolVersion:'2025-11-25',capabilities:{},clientInfo:{name:'planning-workflow-test',version:'1'}});assert.ok(initialized.result);
  children[1].stdin.write(JSON.stringify({jsonrpc:'2.0',method:'notifications/initialized'})+'\n');
  async function call(name,args={}){const response=await rpc('tools/call',{name,arguments:args});assert.ok(!response.error,JSON.stringify(response));assert.ok(!response.result.isError,JSON.stringify(response));return response.result.structuredContent;}
  async function host(kind,frames){const response=await native.send({kind,frames});assert.ok(response.ok,response.error);return response.result;}
  async function queued(name,args,status){const request=await call(name,args);let result;for(let i=0;i<100;i++){await host('tick',24);result=await call('get_proposal_status');assert.equal(result.proposal.id,request.id);if(result.proposal.status===status) return result.proposal;assert.notEqual(result.proposal.status,'failed',JSON.stringify(result.proposal));}assert.fail(JSON.stringify(result.proposal));}
  let context=(await call('get_build_context')).context;const baseLife=context.stats.LifeUnreserved;
  await host('request-test');await call('get_build_connection');await host('tick',1);
  const proof=await host('connection-proof');assert.equal(proof.client,'planning-workflow-test');assert.equal(proof.tested,true);assert.equal(proof.synced,true);
  const raw='Rarity: NORMAL\nIron Hat\nItem Level: 86';
  const item=life=>`Rarity: RARE\nPlanned Hat\nIron Hat\nItem Level: 86\n+${life} to maximum Life`;
  await queued('propose_build',{mode:'edit',title:'Measured helmet',baseRevision:context.revision,operations:[{type:'equip_item',slot:'Helmet',text:item(100)}]},'review');
  assert.equal((await call('get_build_context')).context.stats.LifeUnreserved,baseLife,'Proposal changed the live fixture before UI apply');
  await host('apply');context=(await call('get_build_context')).context;assert.ok(context.stats.LifeUnreserved>baseLife);
  const inspected=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:raw,query:'maximum Life',limit:20},'inspected');assert.ok(inspected.crafting.nativeEngine.modifiers.length);
  assert.ok(inspected.crafting.nativeEngine.modifierTable.rows.some(row=>row.tier && row.groups.length && row.chance>0));
  const modifier=inspected.crafting.nativeEngine.modifiers[0].id;
  const bodyRaw='Rarity: NORMAL\nPlate Vest\nItem Level: 86\nQuality: 20';
  const bodyInspection=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:bodyRaw,query:'life',limit:20},'inspected');
  const enchantService=bodyInspection.crafting.nativeEngine.harvestEnchants.find(entry=>entry.id==='LifeBodyEnchant');
  assert.ok(bodyInspection.crafting.nativeEngine.nativeStats.Armour>0);
  assert.ok(enchantService);assert.deepEqual(enchantService.components,{wild_lifeforce:3250});
  const enchanted=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:bodyRaw,action:enchantService.action,seed:104729},'crafted');
  assert.equal(enchanted.nativeCrafting.state.harvestEnchant,'LifeBodyEnchant');assert.equal(enchanted.nativeCrafting.state.quality,20);
  assert.match(enchanted.nativeCrafting.itemText,/\{enchant\}Grants \+1 to Maximum Life per 2% Quality/);
  assert.equal((await call('get_build_context')).context.revision,context.revision,'Emulating an enchantment changed the character');
  const enchantInspection=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:bodyRaw,initialState:enchanted.nativeCrafting.state,limit:1},'inspected');
  assert.ok(enchantInspection.crafting.nativeEngine.nativeStats.Armour<bodyInspection.crafting.nativeEngine.nativeStats.Armour);
  const bodyRecipe={steps:[enchantService.action],targets:[],requirements:{harvestEnchant:'LifeBodyEnchant',nativeStats:{Armour:enchantInspection.crafting.nativeEngine.nativeStats.Armour}}};
  const bodySimulation=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:bodyRecipe,options:{trials:4,maxActions:1,prices:{wild_lifeforce:0.1},currency:'chaos'}},'crafted');
  assert.equal(bodySimulation.nativeCrafting.successes,4);assert.equal(bodySimulation.nativeCrafting.meanCost,325);
  const starterAtlas={id:'starter-atlas',title:'Starter Atlas',version:'3.29.1',budget:138,nodes:[],progression:{stage:'starter'}};
  await queued('propose_atlas_plan',{baseRevision:context.revision,plan:starterAtlas},'review');await host('apply');context=(await call('get_build_context')).context;
  const finalAtlas={id:'final-atlas',title:'Final Atlas',version:'3.29.1',budget:138,nodes:[],progression:{stage:'final',previousId:'starter-atlas'},strategy:{maps:'Chosen maps',scarabs:'Supplied consumables',requirements:'Unlocks complete',avoid:'Reflect',setupCost:{amount:25,currency:'chaos',source:'Workflow quote',quotedAt:1700000000}}};
  await queued('propose_atlas_plan',{baseRevision:context.revision,plan:finalAtlas},'review');await host('apply');context=(await call('get_build_context')).context;
  const recipe={steps:[{method:'alchemy',onFailureAction:'stop',recoveryNotes:'Stop at the recorded budget'}],targets:[{anyOf:[modifier]}]};
  const simulated=await queued('simulate_crafting',{baseRevision:context.revision,itemText:raw,recipe,options:{trials:4,maxActions:1,seed:104729}},'crafted');assert.ok(simulated.nativeCrafting);
  const project={id:'helmet',title:'Life helmet',slot:'Helmet',startingItem:raw,targetItem:item(200),goals:['More maximum Life'],steps:[{action:'Apply an Orb of Alchemy',stopWhen:'Target modifiers match',onFailure:'Stop at the recorded budget and reconsider'}],nativeRecipe:recipe};
  project.inventory=[{id:'blank-base',title:'Reusable helmet base',slot:'Helmet',baseItem:raw,at:1700000000,state:inspected.crafting.nativeEngine.initialState}];
  await queued('propose_crafting_plan',{baseRevision:context.revision,project},'review');await host('apply');context=(await call('get_build_context')).context;
  const bodyProject={id:'body-enchant',title:'Body armour quality guide',slot:'Body Armour',startingItem:bodyRaw,targetItem:enchanted.nativeCrafting.itemText,preferredMethod:'harvest_enchant',nativeRecipe:bodyRecipe,goals:['Quality grants maximum Life'],steps:[{action:'Apply the Harvest Life quality enchantment',stopWhen:'Life quality enchantment is present'}],inventory:[{id:'enchanted-body',title:'Enchanted body armour',slot:'Body Armour',baseItem:bodyRaw,at:1700000000,state:enchanted.nativeCrafting.state}]};
  await queued('propose_crafting_plan',{baseRevision:context.revision,project:bodyProject},'review');await host('apply');context=(await call('get_build_context')).context;
  const journey={schemaVersion:1,resources:[{id:'chaos',title:'Chaos Orbs'}],ledger:[{id:'holdings',resourceId:'chaos',kind:'add',amount:100,at:1}],wishlist:[{id:'helmet',title:'Next helmet',slot:'Helmet',route:'craft',projectId:'helmet',resourceId:'chaos',estimate:40,reserve:true},{id:'alternative',title:'Alternative helmet',slot:'Helmet',route:'buy',targetItem:item(300),resourceId:'chaos',estimate:90}],milestones:[{id:'craft',title:'Craft the helmet',kind:'craft',projectId:'helmet',wishlistId:'helmet'}],stages:[{id:'maps',title:'Start mapping',level:68,gems:'Keep the main links',gear:'Acquire the planned helmet',transition:'After checking requirements'}]};
  await queued('propose_journey_plan',{title:'Gear roadmap',baseRevision:context.revision,journey},'review');await host('apply');context=(await call('get_build_context')).context;
  const measured=await queued('measure_journey_upgrades',{baseRevision:context.revision},'measured');assert.ok(measured.upgrades.entries.helmet.delta.LifeUnreserved>0);assert.ok(measured.upgrades.entries.alternative.delta.LifeUnreserved>measured.upgrades.entries.helmet.delta.LifeUnreserved);
  const saved=await call('get_build_journey');assert.equal(saved.budget.chaos.available,60);assert.equal(saved.journey.milestones[0].wishlistId,'helmet');
  const lootProfile={id:'mapping',title:'Build pickups',preset:'early_maps',strictness:2,rules:[]};
  const generated=await queued('generate_loot_filter',{baseRevision:context.revision,profile:lootProfile},'generated');
  generated.profile.appearance={minimumFontSize:36,textColor:[255,220,120,255],alertId:6,alertVolume:0,effectColor:'Purple'};
  generated.profile.tiers=[{id:'currency-tier',title:'Crafting currency',text:'Show\n BaseType == "Chromatic Orb"\n SetFontSize 42',items:['Chromatic Orb']}];
  generated.profile.modules=[{id:'links',title:'Link currency',rules:[{id:'fusing',title:'Fusing',text:'Show\n BaseType == "Orb of Fusing"\n SetFontSize 40'}]}];
  generated.profile.campaign={weapons:['Bow'],defences:['Energy shield'],recipes:['Quality gems'],minAreaLevel:1,maxAreaLevel:70,upgradeWindow:15};
  generated.profile.sampleSets=[{id:'campaign-drop',title:'Early helmet',samples:[{BaseType:'Iron Hat',Class:'Helmets',Rarity:'Normal',AreaLevel:12,ItemLevel:12}]}];
  generated.profile.categoryStyles=[{category:'Currency',appearance:{minimumFontSize:40,alertVolume:0}}];
  generated.profile.palettes=[{id:'gold',title:'Gold highlights',appearance:generated.profile.appearance,theme:'default',categoryStyles:generated.profile.categoryStyles}];
  assert.ok(generated.profile.rules.some(rule=>rule.origin==='craft:helmet'));
  const tested=await queued('test_loot_filter',{baseRevision:context.revision,profile:generated.profile,sample:{BaseType:'Iron Hat',Rarity:'Rare',ItemLevel:86}},'tested');assert.equal(tested.result.action,'Show');
  const exported=await queued('export_loot_filter',{baseRevision:context.revision,profile:generated.profile},'exported');assert.ok(exported.filter.includes('PoB rule:'));assert.ok(exported.filter.includes('Frayed Thread'));
  assert.ok(exported.filter.includes('# PoB rule: Campaign /'));assert.ok(exported.filter.includes('Crude Bow'));
  await queued('propose_loot_filters',{title:'Keep pickup plan',baseRevision:context.revision,filters:{schemaVersion:1,activeId:'mapping',profiles:[generated.profile]}},'review');await host('apply');context=(await call('get_build_context')).context;
  const savedFilters=await call('get_loot_filters');assert.equal(savedFilters.filters.profiles.length,1);
  await host('save-reopen');const reopened=await call('get_build_journey');assert.deepEqual(reopened.journey,saved.journey);
  assert.deepEqual((await call('get_loot_filters')).filters,savedFilters.filters);
  const projects=await call('get_crafting_projects');assert.equal(projects.projects[0].run.actions[0].method,'alchemy');assert.equal(projects.projects[0].nativeRecipe.steps[0].method,'alchemy');assert.equal(projects.projects[0].nativeRecipe.steps[0].onFailureAction,'stop');
  assert.equal(projects.projects[0].inventory[0].title,'Reusable helmet base');assert.equal(projects.projects[0].inventory[0].state.rarity,'NORMAL');
  assert.equal(projects.projects.length,2);const savedBody=projects.projects.find(entry=>entry.id==='body-enchant');
  assert.equal(savedBody.nativeRecipe.steps[0].enchantId,'LifeBodyEnchant');assert.equal(savedBody.nativeRecipe.requirements.harvestEnchant,'LifeBodyEnchant');
  assert.equal(savedBody.inventory[0].state.harvestEnchant,'LifeBodyEnchant');assert.equal(savedBody.targetItem,enchanted.nativeCrafting.itemText);
  const atlasPlans=await call('get_atlas_plans');assert.equal(atlasPlans.plans[1].strategy.setupCost.amount,25);assert.equal(atlasPlans.plans[1].progression.previousId,'starter-atlas');await host('bundle-roundtrip');
  await host('quit');
  console.log('PLANNING_WORKFLOW_OK: real MCP stdio, native calculations, UI review, crafting simulation, Journey ranking, Atlas strategy, save/reopen, checkpoint undo and portable bundle import');
}
main().catch(error=>{console.error(error.stack);console.error(diagnostics.join('\n'));process.exitCode=1;}).finally(()=>{
  for(const child of children)child.kill();
  assert.equal(path.dirname(path.resolve(directory)),path.resolve(os.tmpdir()));assert.ok(path.basename(directory).startsWith('pob-planning-workflow-'));
  fs.rmSync(directory,{recursive:true,force:true});
});
