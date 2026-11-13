// A real MCP stdio client drives an isolated native host and explicit UI review.
// cspell:ignore GGGRRW
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
  return {started,send(body){return new Promise((resolve,reject)=>{const id=++next;pending.set(id,{resolve,reject,timer:setTimeout(()=>{pending.delete(id);reject(new Error(`Workflow response timed out: ${prefix ? 'native '+body.kind : body.method+(body.params?.name ? ' / '+body.params.name : '')}`));},60000)});child.stdin.write(JSON.stringify({id,...body})+'\n');});}};
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
  async function host(kind,frames){
    const response=await native.send({kind,frames});assert.ok(response.ok,response.error);
    // The fixture draws about 9,200 commands per frame. Leave room for larger
    // views, while rejecting accumulation across the 24-frame polling batches.
    if(kind==='tick') assert.ok(response.result.drawCommands<100000,'Native recorder retained earlier frames');
    return response.result;
  }
  async function queued(name,args,status){diagnostics.push('Workflow request: '+name);const request=await call(name,args);let result;for(let i=0;i<100;i++){await host('tick',24);result=await call('get_proposal_status');assert.equal(result.proposal.id,request.id);if(result.proposal.status===status) return result.proposal;assert.notEqual(result.proposal.status,'failed',JSON.stringify(result.proposal));}assert.fail(JSON.stringify(result.proposal));}
  let context=(await call('get_build_context')).context;const baseLife=context.stats.LifeUnreserved;
  await host('request-test');await call('get_build_connection');await host('tick',1);
  const proof=await host('connection-proof');assert.equal(proof.client,'planning-workflow-test');assert.equal(proof.tested,true);assert.equal(proof.synced,true);
  const raw='Rarity: NORMAL\nIron Hat\nItem Level: 86';
  const item=life=>`Rarity: RARE\nPlanned Hat\nIron Hat\nItem Level: 86\n+${life} to maximum Life`;
  await queued('propose_build',{mode:'edit',title:'Measured helmet',baseRevision:context.revision,operations:[{type:'equip_item',slot:'Helmet',text:item(100)}]},'review');
  assert.equal((await call('get_build_context')).context.stats.LifeUnreserved,baseLife,'Proposal changed the live fixture before UI apply');
  await host('apply');context=(await call('get_build_context')).context;assert.ok(context.stats.LifeUnreserved>baseLife);
  const inspected=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:raw,query:'maximum Life',limit:20},'inspected');assert.ok(inspected.crafting.nativeEngine.modifiers.length);
  assert.equal(inspected.crafting.nativeEngine.harvestOptions.find(entry=>entry.method==='harvest_reforge').available,false);
  assert.ok(inspected.crafting.nativeEngine.bench.every(entry=>typeof entry.available==='boolean'));
  assert.ok(inspected.crafting.nativeEngine.modifierTable.rows.some(row=>row.tier && row.groups.length && row.chance>0));
  const modifier=inspected.crafting.nativeEngine.modifiers[0].id;
  const bodyRaw='Rarity: NORMAL\nPlate Vest\nItem Level: 86\nQuality: 20\nSockets: W W W W W W';
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
  const linksInspection=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:bodyRaw,query:'connections',limit:5},'inspected');
  const linksService=linksInspection.crafting.nativeEngine.socketCrafts.find(entry=>entry.method==='omen_connections');
  assert.ok(linksService.available && linksService.deterministic);assert.deepEqual(linksService.components,{'Metadata/Items/Currency/AncestralOmenOnFusingMakeFullLinks':1,'Metadata/Items/Currency/CurrencyRerollSocketLinks':1});
  const linkAction=linksService.action;
  const rgbInspection=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:bodyRaw,query:'RGB',limit:5},'inspected');
  const rgbService=rgbInspection.crafting.nativeEngine.socketCrafts.find(entry=>entry.method==='omen_trichromatism');
  assert.ok(rgbService.available && !rgbService.deterministic);assert.equal(rgbService.guaranteedColours,'RGB');
  const rgbAction=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:bodyRaw,action:rgbService.action},'crafted');
  for(const colour of ['R','G','B'])assert.ok(rgbAction.nativeCrafting.state.sockets.some(socket=>socket.color===colour));
  const invalidSockets={rarity:'NORMAL',affixes:[],sockets:[{color:'R',group:0},{color:'G',group:1},{color:'B',group:0}]};
  const rejectedSockets=await queued('calculate_crafting',{baseRevision:context.revision,itemText:bodyRaw,action:{method:'chromatic'},initialState:invalidSockets,targets:[],options:{requirements:{socketColours:'RB',linkedColours:true},trials:2}},'failed');
  assert.match(rejectedSockets.error,/contiguous group/);
  assert.equal((await call('get_build_context')).context.revision,context.revision);
  const abyssSockets={rarity:'NORMAL',affixes:[],sockets:[{color:'R',group:0},{color:'A',group:0}]};
  const rejectedAbyss=await queued('calculate_crafting',{baseRevision:context.revision,itemText:bodyRaw,action:{method:'chromatic'},initialState:abyssSockets,targets:[],options:{requirements:{links:2},trials:2}},'failed');
  assert.match(rejectedAbyss.error,/Abyssal sockets cannot be linked/);
  assert.equal((await call('get_build_context')).context.revision,context.revision);
  const stygianRaw='Rarity: NORMAL\nStygian Vise\nItem Level: 86\nSockets: A\nImplicits: 1\nHas 1 Abyssal Socket';
  const stygian=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:stygianRaw,action:{method:'alchemy'}},'crafted');
  assert.equal(stygian.nativeCrafting.state.sockets[0].color,'A');
  const stygianAgain=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:stygianRaw,action:{method:'chaos'},initialState:stygian.nativeCrafting.state},'crafted');
  assert.equal(stygianAgain.nativeCrafting.state.sockets[0].color,'A');
  assert.equal((await call('get_build_context')).context.revision,context.revision);
  const twiceRaw='Rarity: NORMAL\nIron Hat\nItem Level: 86\nSockets: W-W-W\nTwice Corrupted';
  const twiceAction=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:twiceRaw,action:{method:'tainted_chromatic'}},'crafted');
  assert.equal(twiceAction.nativeCrafting.state.corrupted,true);assert.equal(twiceAction.nativeCrafting.state.twiceCorrupted,true);
  assert.ok(twiceAction.nativeCrafting.itemText.includes('Twice Corrupted'));
  assert.equal((await call('get_build_context')).context.revision,context.revision);
  const implicitRaw='Rarity: NORMAL\nIron Hat\nItem Level: 86\nSockets: W W W\nImplicits: 2\n0.5% of Cold Damage Leeched as Life\n+10% to Damage over Time Multiplier\nTwice Corrupted';
  const implicitTarget={anyOf:['V2ColdDamageLifeLeechPermyriadCorrupted_'],scope:'implicit'};
  const implicitAction=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:implicitRaw,action:{method:'tainted_chromatic'}},'crafted');
  assert.equal(implicitAction.nativeCrafting.state.corruptedImplicits.length,2);
  assert.ok(implicitAction.nativeCrafting.state.corruptedImplicits.some(entry=>entry.id===implicitTarget.anyOf[0]));
  const implicitOdds=await queued('calculate_crafting',{baseRevision:context.revision,itemText:implicitRaw,action:{method:'tainted_chromatic'},targets:[implicitTarget],options:{trials:10}},'crafted');
  assert.equal(implicitOdds.nativeCrafting.successChance,100);
  const rgbPlan=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:{steps:[rgbService.action,linkAction],targets:[],requirements:{socketColours:'RGB',linkedColours:true,links:6}},options:{trials:4,maxActions:2,currency:'chaos',prices:{'Metadata/Items/Currency/AncestralOmenOnChromaticAddWhiteSockets':2,'Metadata/Items/Currency/CurrencyRerollSocketColours':0.5,'Metadata/Items/Currency/AncestralOmenOnFusingMakeFullLinks':2,'Metadata/Items/Currency/CurrencyRerollSocketLinks':0.25}}},'crafted');
  assert.equal(rgbPlan.nativeCrafting.successes,4);assert.equal(rgbPlan.nativeCrafting.meanCost,4.75);assert.equal(rgbPlan.nativeCrafting.resourceUsage.length,4);
  assert.ok(rgbPlan.nativeCrafting.resourceUsage.every(entry=>entry.amount===4));
  assert.equal((await call('get_build_context')).context.revision,context.revision,'Omen crafting changed the live character');
  const bodyPriceBook={currency:'chaos',source:'Workflow resource quotes',quotedAt:1700000000,values:{wild_lifeforce:0.1,'Metadata/Items/Currency/AncestralOmenOnFusingMakeFullLinks':2,'Metadata/Items/Currency/CurrencyRerollSocketLinks':0.25}};
  const bodyRecipe={steps:[enchantService.action,linkAction],targets:[],requirements:{links:6,harvestEnchant:'LifeBodyEnchant',nativeStats:{Armour:enchantInspection.crafting.nativeEngine.nativeStats.Armour}}};
  const bodySimulation=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:bodyRecipe,options:{trials:4,maxActions:2,priceBook:bodyPriceBook}},'crafted');
  assert.equal(bodySimulation.nativeCrafting.successes,4);assert.equal(bodySimulation.nativeCrafting.meanCost,327.25);assert.equal(bodySimulation.nativeCrafting.priceSource,bodyPriceBook.source);

  const benchInspection=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:bodyRaw,query:'maximum Life',limit:100},'inspected');
  const benchService=benchInspection.crafting.nativeEngine.bench.find(entry=>entry.id==='bench:1');
  assert.equal(benchService.ingredientCostsKnown,true);assert.deepEqual(benchService.components,{'Metadata/Items/Currency/CurrencyRerollMagic':1});
  const benchBudget=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:{steps:[{method:'bench',modId:'bench:1'}],targets:[],requirements:{minAffixes:1}},options:{trials:2,maxActions:1,priceBook:{currency:'chaos',source:'Workflow bench quotes',quotedAt:1700000000,values:{'Metadata/Items/Currency/CurrencyRerollMagic':0.5}}}},'crafted');
  assert.equal(benchBudget.nativeCrafting.meanCost,0.5);assert.equal(benchBudget.nativeCrafting.currencySpent['Metadata/Items/Currency/CurrencyRerollMagic'],2);
  const alchemyCurrency='Metadata/Items/Currency/CurrencyUpgradeToRare';
  const scopeCatalog=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:bodyRaw,limit:100},'inspected');
  const scopeBench=scopeCatalog.crafting.nativeEngine.bench.find(entry=>entry.ingredientCostsKnown && entry.components[alchemyCurrency]===1);assert.ok(scopeBench);assert.equal(scopeBench.priceKey,scopeBench.id);
  const scopeBook={currency:'chaos',source:'Action scope quotes',quotedAt:1700000000,values:{[alchemyCurrency]:1}};
  const scopeRecipe={steps:[{method:'bench',modId:scopeBench.id}],targets:[],requirements:{minAffixes:1}};
  const unusedAction=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:scopeRecipe,options:{trials:2,maxActions:1,priceBook:scopeBook,actionPrices:{alchemy:7}}},'crafted');
  assert.equal(unusedAction.nativeCrafting.stepPriceKeys[0].priceKey,scopeBench.priceKey);assert.equal(unusedAction.nativeCrafting.meanCost,1);assert.equal(unusedAction.nativeCrafting.actionPriceOverridesApplied,0);
  const usedAction=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:{steps:[{method:'alchemy'}],targets:[],requirements:{minAffixes:1}},options:{trials:2,maxActions:1,priceBook:scopeBook,actionPrices:{alchemy:7}}},'crafted');
  assert.equal(usedAction.nativeCrafting.meanCost,7);assert.equal(usedAction.nativeCrafting.actionPriceOverridesApplied,2);
  const freeAction=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:scopeRecipe,options:{trials:2,maxActions:1,priceBook:scopeBook,actionPrices:{[scopeBench.id]:0}}},'crafted');assert.equal(freeAction.nativeCrafting.meanCost,0);
  assert.deepEqual(freeAction.nativeCrafting.resourceUsage,unusedAction.nativeCrafting.resourceUsage);
  assert.deepEqual(usedAction.nativeCrafting.resourceUsage,[{key:alchemyCurrency,name:"Orb of Alchemy",kind:"resource",amount:2,meanPerTrial:1}]);
  const globalPrice=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:scopeRecipe,options:{trials:2,maxActions:1,priceBook:scopeBook,prices:{alchemy:5},actionPrices:{alchemy:7}}},'crafted');assert.equal(globalPrice.nativeCrafting.meanCost,5);
  const serviceCatalog=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:bodyRaw,query:'bench_reroll',limit:10},'inspected');
  assert.equal(serviceCatalog.crafting.nativeEngine.benchServiceCosts.length,2);
  for(const service of serviceCatalog.crafting.nativeEngine.benchServiceCosts)assert.equal(service.components['Metadata/Items/Currency/CurrencyRerollRare'],service.action.count===1?8:3);
  const removedCraft=await queued('simulate_crafting',{baseRevision:context.revision,itemText:bodyRaw,recipe:{initialState:benchBudget.nativeCrafting.sampleState,steps:[{method:'remove_crafted'}],targets:[],requirements:{maxAffixes:0}},options:{trials:2,maxActions:1,priceBook:{currency:'chaos',source:'Removal quote',quotedAt:1700000000,values:{'Metadata/Items/Currency/CurrencyConvertToNormal':2}}}},'crafted');assert.equal(removedCraft.nativeCrafting.meanCost,2);
  assert.equal((await call('get_build_context')).context.revision,context.revision,'Price tests changed the character');
  const fossilId='Metadata/Items/Currency/CurrencyDelveCraftingLife';
  const fossilQuotes={currency:'chaos',source:'Workflow fossil quotes',quotedAt:1700000000,values:{[fossilId]:1,'Metadata/Items/Delve/DelveStackableSocketableCurrencyReroll1':2}};
  const fossilComparison=await queued('optimize_crafting_fossils',{baseRevision:context.revision,itemText:bodyRaw,targets:[],options:{fossils:[fossilId],maxSockets:1,trials:2,requirements:{minAffixes:1},priceBook:fossilQuotes}},'crafted');
  assert.equal(fossilComparison.nativeCrafting.combinations[0].meanCost,3);assert.equal(fossilComparison.nativeCrafting.costCurrency,'chaos');assert.equal(fossilComparison.nativeCrafting.priceSource,fossilQuotes.source);
  const fossilAction=await queued('optimize_crafting_fossils',{baseRevision:context.revision,itemText:bodyRaw,targets:[],options:{fossils:[fossilId],maxSockets:1,trials:2,requirements:{minAffixes:1},priceBook:fossilQuotes,actionPrices:{['fossil:'+fossilId]:9}}},'crafted');
  assert.equal(fossilAction.nativeCrafting.combinations[0].priceKey,'fossil:'+fossilId);assert.equal(fossilAction.nativeCrafting.combinations[0].meanCost,9);assert.equal(fossilAction.nativeCrafting.combinations[0].actionPriceOverridesApplied,2);
  const exactLinks=await queued('calculate_crafting',{baseRevision:context.revision,itemText:bodyRaw,action:linkAction,targets:[],options:{requirements:{links:6}}},'crafted');
  assert.equal(exactLinks.nativeCrafting.successChance,100);assert.equal(exactLinks.nativeCrafting.sampled,false);assert.equal(exactLinks.nativeCrafting.outcomes.length,1);
  const exactRGB=await queued('calculate_crafting',{baseRevision:context.revision,itemText:bodyRaw.replace('Sockets: W W W W W W','Sockets: W-W W'),action:rgbService.action,targets:[],options:{requirements:{socketColours:'RG',linkedColours:true}}},'crafted');
  assert.equal(exactRGB.nativeCrafting.sampled,false);assert.equal(exactRGB.nativeCrafting.outcomes.length,6);assert.ok(Math.abs(exactRGB.nativeCrafting.successChance-100/3)<1e-8);assert.match(exactRGB.nativeCrafting.exactFor,/uniform-position/);
  const steelRaw='Rarity: NORMAL\nSteel Ring\nItem Level: 86';
  const blessedRing=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:steelRaw,action:{method:'blessed'},seed:1},'crafted');
  assert.ok(Array.isArray(blessedRing.nativeCrafting.state.baseImplicitRanges[0]));
  await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:steelRaw,initialState:blessedRing.nativeCrafting.state,limit:1},'inspected');
  const independentAffix=await queued('apply_crafting_action',{baseRevision:context.revision,itemText:raw,action:{method:'quality'},initialState:{rarity:'RARE',affixes:[{id:'LocalBaseArmourAndLife1',range:[0,1]}]},seed:1},'crafted');
  assert.match(independentAffix.nativeCrafting.itemText,/\+23 to maximum Life/);assert.deepEqual(independentAffix.nativeCrafting.state.affixes[0].range,[0,1]);
  const starterAtlas={id:'starter-atlas',title:'Starter Atlas',version:'3.29.1',budget:138,nodes:[],progression:{stage:'starter'}};
  await queued('propose_atlas_plan',{baseRevision:context.revision,plan:starterAtlas},'review');await host('apply');context=(await call('get_build_context')).context;
  const finalAtlas={id:'final-atlas',title:'Final Atlas',version:'3.29.1',budget:138,nodes:[],progression:{stage:'final',previousId:'starter-atlas'},strategy:{maps:'Chosen maps',scarabs:'Supplied consumables',requirements:'Unlocks complete',avoid:'Reflect',setupCost:{amount:25,currency:'chaos',source:'Workflow quote',quotedAt:1700000000}}};
  await queued('propose_atlas_plan',{baseRevision:context.revision,plan:finalAtlas},'review');await host('apply');context=(await call('get_build_context')).context;
  const recipe={steps:[{method:'alchemy',onFailureAction:'stop',recoveryNotes:'Stop at the recorded budget'}],targets:[{anyOf:[modifier]}]};
  const simulated=await queued('simulate_crafting',{baseRevision:context.revision,itemText:raw,recipe,options:{trials:4,maxActions:1,seed:104729}},'crafted');assert.ok(simulated.nativeCrafting);
  const rareInspection=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:raw,initialState:simulated.nativeCrafting.sampleState,query:'life',limit:20},'inspected');
  const reforgeChoice=rareInspection.crafting.nativeEngine.harvestOptions.find(entry=>entry.method==='harvest_reforge');
  assert.equal(reforgeChoice.available,true);assert.ok(reforgeChoice.options.some(entry=>entry.action.tag==='life'));
  const project={priceBook:{currency:'chaos',source:'Unquoted',quotedAt:1700000000,values:{}},id:'helmet',title:'Life helmet',slot:'Helmet',startingItem:raw,targetItem:item(200),goals:['More maximum Life'],steps:[{action:'Apply an Orb of Alchemy',stopWhen:'Target modifiers match',onFailure:'Stop at the recorded budget and reconsider'}],nativeRecipe:recipe};
  project.inventory=[{id:'blank-base',title:'Reusable helmet base',slot:'Helmet',baseItem:raw,at:1700000000,state:inspected.crafting.nativeEngine.initialState}];
  const conflicting={...project,id:'conflicting-quotes',priceBook:{currency:'chaos',source:'Conflicting quotes',quotedAt:1700000000,values:{exalt:1,'Metadata/Items/Currency/CurrencyAddModToRare':2}}};
  const rejected=await queued('propose_crafting_plan',{baseRevision:context.revision,project:conflicting},'failed');assert.match(rejected.error,/Conflicting quotes/);
  assert.equal((await call('get_build_context')).context.revision,context.revision);

  await queued('propose_crafting_plan',{baseRevision:context.revision,project},'review');await host('apply');context=(await call('get_build_context')).context;
  const bodyProject={priceBook:bodyPriceBook,id:'body-enchant',title:'Body armour quality guide',slot:'Body Armour',startingItem:bodyRaw,targetItem:bodySimulation.nativeCrafting.sampleItem,preferredMethod:'harvest_enchant',nativeRecipe:bodyRecipe,goals:['Quality grants maximum Life','Six linked sockets'],steps:[{action:'Apply the Harvest Life quality enchantment',stopWhen:'Life quality enchantment is present'},{action:'Use an Orb of Fusing with Omen of Connections',stopWhen:'All six sockets are linked'}],inventory:[{id:'enchanted-body',title:'Enchanted body armour',slot:'Body Armour',baseItem:bodyRaw,at:1700000000,state:enchanted.nativeCrafting.state}]};
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
  const socketProfile={id:'socket-rules',title:'Socket comparisons',preset:'early_maps',strictness:2,rules:[{id:'socket-rule',title:'Socket rule',enabled:true,text:'Hide\n SocketGroup > 5GGG'}]};
  const socketTest=await queued('test_loot_filter',{baseRevision:context.revision,profile:socketProfile,sample:{BaseType:'Plate Vest',Rarity:'Normal',SocketGroup:'GGGRRW'}},'tested');assert.equal(socketTest.result.action,'Hide');assert.equal(socketTest.result.ruleTitle,'Socket rule');
  const invalidSocketSample=await queued('test_loot_filter',{baseRevision:context.revision,profile:socketProfile,sample:{BaseType:'Plate Vest',Rarity:'Normal',SocketGroup:'GGGRRW?'}},'tested');assert.equal(invalidSocketSample.result.status,'unknown');assert.match(invalidSocketSample.result.reasons[0],/Invalid socket colours/);
  const exported=await queued('export_loot_filter',{baseRevision:context.revision,profile:generated.profile},'exported');assert.ok(exported.filter.includes('PoB rule:'));assert.ok(exported.filter.includes('Frayed Thread'));
  assert.ok(exported.filter.includes('# PoB rule: Campaign /'));assert.ok(exported.filter.includes('Crude Bow'));
  await queued('propose_loot_filters',{title:'Keep pickup plan',baseRevision:context.revision,filters:{schemaVersion:1,activeId:'mapping',profiles:[generated.profile]}},'review');await host('apply');context=(await call('get_build_context')).context;
  const savedFilters=await call('get_loot_filters');assert.equal(savedFilters.filters.profiles.length,1);
  await host('save-reopen');const reopened=await call('get_build_journey');assert.deepEqual(reopened.journey,saved.journey);
  assert.deepEqual((await call('get_loot_filters')).filters,savedFilters.filters);
  const projects=await call('get_crafting_projects');assert.equal(projects.projects[0].run.actions[0].method,'alchemy');assert.equal(projects.projects[0].nativeRecipe.steps[0].method,'alchemy');assert.equal(projects.projects[0].nativeRecipe.steps[0].onFailureAction,'stop');
  assert.deepEqual(projects.projects[0].priceBook.values,{});assert.equal(projects.projects[0].inventory[0].title,'Reusable helmet base');assert.equal(projects.projects[0].inventory[0].state.rarity,'NORMAL');
  assert.equal(projects.projects.length,2);const savedBody=projects.projects.find(entry=>entry.id==='body-enchant');
  assert.deepEqual(savedBody.priceBook,bodyPriceBook);assert.equal(savedBody.nativeRecipe.steps[1].method,'omen_connections');assert.equal(savedBody.nativeRecipe.requirements.links,6);assert.equal(savedBody.nativeRecipe.steps[0].enchantId,'LifeBodyEnchant');assert.equal(savedBody.nativeRecipe.requirements.harvestEnchant,'LifeBodyEnchant');
  assert.equal(savedBody.inventory[0].state.harvestEnchant,'LifeBodyEnchant');assert.equal(savedBody.targetItem,bodySimulation.nativeCrafting.sampleItem);
  const atlasPlans=await call('get_atlas_plans');assert.equal(atlasPlans.plans[1].strategy.setupCost.amount,25);assert.equal(atlasPlans.plans[1].progression.previousId,'starter-atlas');await host('bundle-roundtrip');
  assert.deepEqual((await call('get_crafting_projects')).projects.find(entry=>entry.id==='body-enchant').priceBook,bodyPriceBook);
  context=(await call('get_build_context')).context;
  const removal=await queued('propose_build',{mode:'edit',title:'Remove body guide',baseRevision:context.revision,operations:[{type:'remove_crafting_project',projectId:'body-enchant'}]},'review');
  assert.ok(removal.changes.some(line=>line.includes('Removed crafting project:')));
  assert.equal((await call('get_crafting_projects')).projects.length,2,'Removal changed live guides before review');
  await host('apply');assert.equal((await call('get_crafting_projects')).projects.length,1);
  await host('undo-applied');
  const restoredProjects=(await call('get_crafting_projects')).projects;assert.equal(restoredProjects.length,2);
  assert.deepEqual(restoredProjects.find(entry=>entry.id==='body-enchant').priceBook,bodyPriceBook);
  await host('quit');
  console.log('PLANNING_WORKFLOW_OK: real MCP stdio, native calculations, UI review, crafting simulation, Journey ranking, Atlas strategy, save/reopen, checkpoint undo and portable bundle import');
}
main().catch(error=>{console.error(error.stack);console.error(diagnostics.join('\n'));process.exitCode=1;}).finally(()=>{
  for(const child of children)child.kill();
  assert.equal(path.dirname(path.resolve(directory)),path.resolve(os.tmpdir()));assert.ok(path.basename(directory).startsWith('pob-planning-workflow-'));
  fs.rmSync(directory,{recursive:true,force:true});
});
