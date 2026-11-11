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
test('rejects unknown operations, arbitrary paths, prototype keys and nonfinite values', t => {
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
