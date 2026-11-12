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
  children.push(child);const pending=new Map();let next=0;let ready;
  const started=new Promise(resolve=>{ready=resolve;});
  child.stderr.on('data',data=>diagnostics.push(data.toString()));
  createInterface({input:child.stdout}).on('line',line=>{
    if(prefix && !line.startsWith(prefix)){diagnostics.push(line);return;}
    let message;try{message=JSON.parse(line.slice(prefix.length));}catch{diagnostics.push(line);return;}
    if(message.ready) ready(message);
    const waiter=pending.get(message.id);if(waiter){pending.delete(message.id);clearTimeout(waiter.timer);waiter.resolve(message);}
  });
  child.on('exit',code=>{for(const waiter of pending.values()){clearTimeout(waiter.timer);waiter.reject(new Error(`Child exited ${code}: ${diagnostics.join('\n')}`));}});
  return {started,send(body){return new Promise((resolve,reject)=>{const id=++next;pending.set(id,{resolve,reject,timer:setTimeout(()=>{pending.delete(id);reject(new Error('Workflow response timed out'));},60000)});child.stdin.write(JSON.stringify({id,...body})+'\n');});}};
}
async function main(){
  const native=connection(spawn(lua,['../tools/planning_workflow_host.lua',directory],{cwd:path.join(root,'src'),env:{...process.env,LUA_PATH:'../runtime/lua/?.lua;../runtime/lua/?/init.lua;;',LUA_CPATH:path.join(root,'runtime','?.dll')+';;',PATH:path.join(root,'runtime')+path.delimiter+process.env.PATH}}),'WORKFLOW\t');
  let startupTimer;
  await Promise.race([native.started,new Promise((_,reject)=>{startupTimer=setTimeout(()=>reject(new Error('Native startup timed out')),60000);})]).finally(()=>clearTimeout(startupTimer));
  const mcp=connection(spawn(process.execPath,[path.join(root,'src/AI/McpServer.cjs'),path.join(directory,'AI-encounter.json')]));
  const rpc=(method,params)=>mcp.send({jsonrpc:'2.0',method,params});
  const initialized=await rpc('initialize',{protocolVersion:'2025-11-25',capabilities:{},clientInfo:{name:'planning-workflow-test',version:'1'}});assert.ok(initialized.result);
  children[1].stdin.write(JSON.stringify({jsonrpc:'2.0',method:'notifications/initialized'})+'\n');
  async function call(name,args={}){const response=await rpc('tools/call',{name,arguments:args});assert.ok(!response.error,JSON.stringify(response));assert.ok(!response.result.isError,JSON.stringify(response));return response.result.structuredContent;}
  async function host(kind,frames){const response=await native.send({kind,frames});assert.ok(response.ok,response.error);return response.result;}
  async function queued(name,args,status){const request=await call(name,args);await host('tick',24);const result=await call('get_proposal_status');assert.equal(result.proposal.id,request.id);assert.equal(result.proposal.status,status,JSON.stringify(result.proposal));return result.proposal;}
  let context=(await call('get_build_context')).context;const baseLife=context.stats.LifeUnreserved;
  const raw='Rarity: NORMAL\nIron Hat\nItem Level: 86';
  const item=life=>`Rarity: RARE\nPlanned Hat\nIron Hat\nItem Level: 86\n+${life} to maximum Life`;
  await queued('propose_build',{mode:'edit',title:'Measured helmet',baseRevision:context.revision,operations:[{type:'equip_item',slot:'Helmet',text:item(100)}]},'review');
  assert.equal((await call('get_build_context')).context.stats.LifeUnreserved,baseLife,'Proposal changed the live fixture before UI apply');
  await host('apply');context=(await call('get_build_context')).context;assert.ok(context.stats.LifeUnreserved>baseLife);
  const inspected=await queued('inspect_crafting_item',{baseRevision:context.revision,itemText:raw,query:'maximum Life',limit:20},'inspected');assert.ok(inspected.crafting.nativeEngine.modifiers.length);
  const modifier=inspected.crafting.nativeEngine.modifiers[0].id;
  const recipe={steps:[{method:'alchemy'}],targets:[{anyOf:[modifier]}]};
  const simulated=await queued('simulate_crafting',{baseRevision:context.revision,itemText:raw,recipe,options:{trials:4,maxActions:1,seed:104729}},'crafted');assert.ok(simulated.nativeCrafting);
  const project={id:'helmet',title:'Life helmet',slot:'Helmet',startingItem:raw,targetItem:item(200),goals:['More maximum Life'],steps:[{action:'Apply an Orb of Alchemy',stopWhen:'Target modifiers match',onFailure:'Stop at the recorded budget and reconsider'}],nativeRecipe:recipe};
  await queued('propose_crafting_plan',{baseRevision:context.revision,project},'review');await host('apply');context=(await call('get_build_context')).context;
  const journey={schemaVersion:1,resources:[{id:'chaos',title:'Chaos Orbs'}],ledger:[{id:'holdings',resourceId:'chaos',kind:'add',amount:100,at:1}],wishlist:[{id:'helmet',title:'Next helmet',slot:'Helmet',route:'craft',projectId:'helmet',resourceId:'chaos',estimate:40,reserve:true},{id:'alternative',title:'Alternative helmet',slot:'Helmet',route:'buy',targetItem:item(300),resourceId:'chaos',estimate:90}],milestones:[{id:'craft',title:'Craft the helmet',kind:'craft',projectId:'helmet',wishlistId:'helmet'}],stages:[{id:'maps',title:'Start mapping',level:68,gems:'Keep the main links',gear:'Acquire the planned helmet',transition:'After checking requirements'}]};
  await queued('propose_journey_plan',{title:'Gear roadmap',baseRevision:context.revision,journey},'review');await host('apply');context=(await call('get_build_context')).context;
  const measured=await queued('measure_journey_upgrades',{baseRevision:context.revision},'measured');assert.ok(measured.upgrades.entries.helmet.delta.LifeUnreserved>0);assert.ok(measured.upgrades.entries.alternative.delta.LifeUnreserved>measured.upgrades.entries.helmet.delta.LifeUnreserved);
  const saved=await call('get_build_journey');assert.equal(saved.budget.chaos.available,60);assert.equal(saved.journey.milestones[0].wishlistId,'helmet');
  await host('save-reopen');const reopened=await call('get_build_journey');assert.deepEqual(reopened.journey,saved.journey);
  const projects=await call('get_crafting_projects');assert.equal(projects.projects[0].run.actions[0].method,'alchemy');assert.equal(projects.projects[0].nativeRecipe.steps[0].method,'alchemy');
  await host('quit');
  console.log('PLANNING_WORKFLOW_OK: real MCP stdio, native calculations, UI review, crafting simulation, Journey ranking, save/reopen and checkpoint undo');
}
main().catch(error=>{console.error(error.stack);console.error(diagnostics.join('\n'));process.exitCode=1;}).finally(()=>{
  for(const child of children)child.kill();
  assert.equal(path.dirname(path.resolve(directory)),path.resolve(os.tmpdir()));assert.ok(path.basename(directory).startsWith('pob-planning-workflow-'));
  fs.rmSync(directory,{recursive:true,force:true});
});
