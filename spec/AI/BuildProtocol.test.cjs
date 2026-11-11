'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createBridge } = require('../../src/AI/BuildProtocol.cjs');
function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(),'pob-build-'));
  t.after(() => fs.rmSync(dir,{recursive:true,force:true}));
  const state = {schemaVersion:1,session:'session-one',enabled:true,heartbeat:Date.now()/1000,revision:'a'.repeat(40)};
  const captured = {schemaVersion:1,session:state.session,capturedAt:new Date().toISOString(),context:{revision:state.revision,name:'Desktop',level:80,xml:'not returned'},
    catalog:{gems:[{name:'Fireball'}],passives:[{id:123,name:'Life',pathLength:3}],config:[],classes:[]}};
  const write = (name,value) => fs.writeFileSync(path.join(dir,`AI-build-${name}.json`),JSON.stringify(value));
  write('state',state); write('context',captured);
  return {dir,state,captured,write,call:createBridge(path.join(dir,'AI-encounter.json')),proposal:{mode:'new',title:'Fireball candidate',baseRevision:state.revision,
    operations:[{type:'set_character',level:80,className:'Witch',ascendancy:'Elementalist'},{type:'set_skills',groups:[{gems:[{name:'Fireball'}]}]}]}};
}
test('reads opted-in desktop context and searches bounded native catalogs', t => {
  const f = fixture(t);
  assert.equal(f.call('get_build_context',{}).context.xml,undefined);
  const result = f.call('search_build_catalog',{kind:'passives',query:'life',limit:1});
  assert.equal(result.total,1); assert.equal(result.matches[0].id,123);
  assert.throws(() => f.call('search_build_catalog',{kind:'gems',query:'Fireball',limit:0}),/arguments/);
});
test('queues a typed proposal bound to session and revision without applying it', t => {
  const f = fixture(t); const result = f.call('propose_build',f.proposal);
  const request = JSON.parse(fs.readFileSync(path.join(f.dir,'AI-build-request.json')));
  assert.equal(result.status,'queued'); assert.equal(request.id,result.id);
  assert.equal(request.session,f.state.session); assert.deepEqual(request.proposal,f.proposal);
  assert.throws(() => f.call('propose_build',f.proposal),/already queued/);
  assert.equal(f.call('get_build_context',{}).context.level,80);
});
test('rejects disconnected sessions, old context and stale revisions', t => {
  const f = fixture(t);
  f.state.enabled=false; f.write('state',f.state);
  assert.throws(() => f.call('propose_build',f.proposal),/disabled/);
  f.state.enabled=true; f.state.heartbeat=Date.now()/1000-60; f.write('state',f.state);
  assert.throws(() => f.call('get_build_context',{}),/responding/);
  f.state.heartbeat=Date.now()/1000; f.write('state',f.state);
  assert.throws(() => f.call('propose_build',{...f.proposal,baseRevision:'b'.repeat(40)}),/revision changed/);
  f.captured.session='old-session'; f.write('context',f.captured);
  assert.throws(() => f.call('propose_build',f.proposal),/refreshing/);
});
test('rejects unknown operations, arbitrary paths, prototype keys and invalid numbers', t => {
  const f = fixture(t);
  for (const operations of [[{type:'run_lua',code:'anything'}],[{type:'set_character',level:Infinity}],[{type:'equip_item',slot:'Helmet',text:'Item',path:'elsewhere'}]]) {
    assert.throws(() => f.call('propose_build',{...f.proposal,operations}),/arguments/);
  }
  const request = JSON.parse(JSON.stringify(f.proposal).replace('"mode":"new"','"mode":"new","__proto__":{}'));
  assert.throws(() => f.call('propose_build',request),/arguments/);
  assert.equal(fs.existsSync(path.join(f.dir,'AI-build-request.json')),false);
});
test('returns calculated status and blocks replacement while desktop review is pending', t => {
  const f = fixture(t);
  f.state.proposal={id:'candidate-one',status:'review',after:{CombinedDPS:123},warnings:['Check assumptions']}; f.write('state',f.state);
  assert.equal(f.call('get_proposal_status',{}).proposal.after.CombinedDPS,123);
  assert.throws(() => f.call('propose_build',f.proposal),/pending proposal/);
  assert.throws(() => f.call('apply_build',{}),/arguments/);
});


test('diagnoses disabled and stale desktops without requiring an active connection', t => {
  const f=fixture(t);
  f.state.enabled=false; f.write('state',f.state);
  assert.equal(f.call('get_build_connection',{}).status,'disabled');
  f.state.enabled=true; f.state.heartbeat=Date.now()/1000-60; f.write('state',f.state);
  assert.equal(f.call('get_build_connection',{}).status,'stale');
  fs.unlinkSync(path.join(f.dir,'AI-build-state.json'));
  assert.equal(f.call('get_build_connection',{}).status,'unavailable');
});

test('queues goals with finite budgets and known minimum metrics', t => {
  const f=fixture(t);
  assert.throws(() => f.call('set_build_goals',{goal:'survival',budget:10}),/currency/);
  assert.throws(() => f.call('set_build_goals',{goal:'survival',minimums:{invented:10}}),/arguments/);
  f.call('set_build_goals',{goal:'comfort',budget:10,currency:'chaos',minimums:{LifeUnreserved:2000}});
  const queued=JSON.parse(fs.readFileSync(path.join(f.dir,'AI-build-request.json')));
  assert.equal(queued.kind,'plan'); assert.equal(queued.plan.goal,'comfort');
});

test('compares bounded alternatives using matching revisions and dated price sources', t => {
  const f=fixture(t);
  const candidate={...f.proposal,quote:{amount:5,currency:'chaos',source:'Manual listing',quotedAt:Math.floor(Date.now()/1000)}};
  assert.throws(() => f.call('compare_build_candidates',{baseRevision:f.state.revision,candidates:[{...candidate,baseRevision:'b'.repeat(40)}]}),/revision/);
  assert.throws(() => f.call('compare_build_candidates',{baseRevision:f.state.revision,candidates:Array(6).fill(candidate)}),/arguments/);
  assert.throws(() => f.call('propose_build',{...candidate,quote:{...candidate.quote,quotedAt:4102444800}}),/capture time/);
  f.call('compare_build_candidates',{baseRevision:f.state.revision,candidates:[candidate]});
  const queued=JSON.parse(fs.readFileSync(path.join(f.dir,'AI-build-request.json')));
  assert.equal(queued.kind,'compare'); assert.equal(queued.candidates[0].quote.amount,5);
});

test('queues increasing cumulative milestones and rejects character overrides', t => {
  const f=fixture(t);
  const stages=[{title:'Early',level:12,operations:[]},{title:'Later',level:70,operations:[{type:'set_notes',text:'Later links'}]}];
  assert.throws(() => f.call('plan_leveling_build',{baseRevision:f.state.revision,stages:[stages[1],stages[0]]}),/increase/);
  assert.throws(() => f.call('plan_leveling_build',{baseRevision:f.state.revision,stages:[{...stages[0],operations:[{type:'set_character',level:99}]}]}),/arguments/);
  f.call('plan_leveling_build',{baseRevision:f.state.revision,stages});
  assert.equal(JSON.parse(fs.readFileSync(path.join(f.dir,'AI-build-request.json'))).kind,'leveling');
});

test('returns audit evidence and bounded session history', t => {
  const f=fixture(t);
  f.captured.context.audit={dependencies:[{key:'Str',text:'Requirement shortfall'}]};
  f.captured.context.encounter={observations:['Energy Shield was empty.']}; f.write('context',f.captured);
  f.state.history=[{id:'candidate-one',title:'Upgrade'}];f.state.diagnostics={undoDepth:2};f.write('state',f.state);
  assert.equal(f.call('get_build_analysis',{}).audit.dependencies[0].key,'Str');
  assert.equal(f.call('get_build_history',{}).undoDepth,2);
  assert.equal(f.call('get_build_history',{}).history.length,1);
});


test('retries a brief incomplete desktop refresh without reporting a disconnected session', t => {
  const f=fixture(t);const originalRead=fs.readFileSync;let partial=true;
  fs.readFileSync=function(file,...args){if (partial && file === path.join(f.dir,'AI-build-state.json')) {partial=false;return '{';}return originalRead.call(this,file,...args);};
  try {assert.equal(f.call('get_build_context',{}).context.name,'Desktop');assert.equal(partial,false);} finally {fs.readFileSync=originalRead;}
});
