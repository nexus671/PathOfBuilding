'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const string = maxLength => ({type:'string',maxLength});
const integer = (minimum,maximum) => ({type:'integer',minimum,maximum});
const object = (properties,required = []) => ({type:'object',properties,required,additionalProperties:false});
const array = (items,maxItems) => ({type:'array',items,maxItems});
const boolean = {type:'boolean'};
const number = (minimum,maximum) => ({type:'number',minimum,maximum});
const quoteSchema = object({amount:number(0,1e12),currency:{type:'string',pattern:'^[A-Za-z][A-Za-z0-9 _-]{0,23}$'},quotedAt:integer(0,4102444800),source:string(240)},['amount','currency','quotedAt','source']);
const craftingMethods=['transmute','alteration','augmentation','regal','alchemy','chaos','exalt','annul','scour','divine','bench','remove_crafted','essence'];
const craftingTargets={type:'array',minItems:1,maxItems:6,items:object({anyOf:{type:'array',minItems:1,maxItems:30,items:string(160)}},['anyOf'])};
const craftingState=object({rarity:{enum:['NORMAL','MAGIC','RARE']},affixes:array(object({id:string(160),range:{oneOf:[number(-100,100),{type:'array',minItems:1,maxItems:20,items:number(-100,100)}]},fractured:boolean,crafted:boolean},['id']),6)},['rarity','affixes']);
const craftingAction=object({method:{enum:craftingMethods},modId:string(160),essenceId:string(200)},['method']);
const craftingRecipe=object({rarity:{enum:['MAGIC','RARE']},steps:{type:'array',minItems:1,maxItems:20,items:object({...craftingAction.properties,maxAttempts:integer(1,200),untilTargets:craftingTargets,onSuccess:integer(1,21),onFailure:integer(1,21)},['method'])},targets:craftingTargets,initialState:craftingState},['steps','targets']);
const craftingProjectSchema = object({id:{type:'string',pattern:'^[A-Za-z0-9_-]{1,64}$'},title:string(120),slot:string(80),startingItem:string(24000),targetItem:string(24000),
  nativeRecipe:craftingRecipe,goals:array(string(300),12),steps:array(object({action:string(1000),stopWhen:string(500),onFailure:string(500),done:boolean},['action']),40),notes:string(8000),estimate:quoteSchema,simulatorExport:string(128000),
  simulation:object({patch:string(40),observedAt:integer(0,4102444800),trials:integer(1,1e9),successes:integer(0,1e9),notes:string(4000)},['patch','observedAt','trials','successes'])},['id','title','slot','startingItem','goals','steps']);
const operations = [
  object({type:{const:'set_character'},level:integer(1,100),className:string(40),ascendancy:string(40)},['type']),
  object({type:{const:'allocate_passives'},add:array(integer(1,1000000),200),remove:array(integer(1,1000000),200),
    masteries:array(object({nodeId:integer(1,1000000),effectId:integer(1,65535)},['nodeId','effectId']),50)},['type']),
  object({type:{const:'equip_item'},slot:string(80),text:string(24000),active:boolean},['type','slot','text']),
  object({type:{const:'set_skills'},mainGroup:integer(1,40),groups:array(object({label:string(120),slot:string(80),enabled:boolean,includeInFullDPS:boolean,
    mainActiveSkill:integer(1,12),gems:array(object({name:string(160),level:integer(1,40),quality:integer(0,100),enabled:boolean},['name']),12)},['gems']),40)},['type','groups']),
  object({type:{const:'set_config'},values:{type:'object',maxProperties:100,additionalProperties:{type:['string','number','boolean']}}},['type','values']),
  object({type:{const:'set_notes'},text:string(64000)},['type','text']),
  object({type:{const:'set_crafting_project'},project:craftingProjectSchema},['type','project']),
];
const metricNames = ['LifeUnreserved','EnergyShield','ManaUnreserved','CombinedDPS','FullDPS','TotalEHP','PhysicalMaximumHitTaken','ChaosMaximumHitTaken','RecoverySimulationSurvivalChance','RecoverySimulationDamageDPS','RecoverySimulationAttackUptime','ManaRegen','Speed','EffectiveMovementSpeedMod','FireResist','ColdResist','LightningResist','ChaosResist','Str','Dex','Int'];
const planSchema = object({goal:{enum:['balanced','boss_damage','mapping','survival','comfort']},budget:number(0,1e12),currency:quoteSchema.properties.currency,
  minimums:object(Object.fromEntries(metricNames.map(key => [key,number(-1e12,1e12)]))),notes:string(2000)},['goal']);
const proposalSchema = object({mode:{enum:['edit','new']},title:string(120),baseRevision:{type:'string',pattern:'^[a-f0-9]{40}$'},
  quote:quoteSchema,operations:{type:'array',minItems:1,maxItems:100,items:{oneOf:operations}}},['mode','title','baseRevision','operations']);

// Validate the same closed JSON schema advertised to clients, without an extra runtime dependency.
function validate(value,schema) {
  if (schema.oneOf) return schema.oneOf.filter(s => validate(value,s)).length === 1;
  if (schema.const !== undefined && value !== schema.const) return false;
  if (schema.enum && !schema.enum.includes(value)) return false;
  const type = value === null ? 'null' : Array.isArray(value) ? 'array' : typeof value;
  if (schema.type) {
    const types = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!types.includes(type) && !(types.includes('integer') && Number.isInteger(value))) return false;
  }
  if (type === 'number' && (!Number.isFinite(value) || value < (schema.minimum ?? -Infinity) || value > (schema.maximum ?? Infinity))) return false;
  if (type === 'string' && (value.length > (schema.maxLength ?? Infinity) || schema.pattern && !new RegExp(schema.pattern).test(value))) return false;
  if (type === 'array' && (value.length < (schema.minItems ?? 0) || value.length > (schema.maxItems ?? Infinity) || value.some(v => !validate(v,schema.items)))) return false;
  if (type === 'object') {
    if (Object.keys(value).length > (schema.maxProperties ?? Infinity) || (schema.required ?? []).some(k => !Object.hasOwn(value,k))) return false;
    for (const [key,entry] of Object.entries(value)) {
      const member = schema.properties && Object.hasOwn(schema.properties,key) ? schema.properties[key] : undefined;
      if (member ? !validate(entry,member) : schema.additionalProperties === false || typeof schema.additionalProperties === 'object' && !validate(entry,schema.additionalProperties)) return false;
    }
  }
  return true;
}
const readOnly = {readOnlyHint:true,destructiveHint:false,idempotentHint:true,openWorldHint:false};
const tools = [
  {name:'get_build_context',description:'Read the connected desktop build: revision, character, current gear, socket groups, passives, configuration, native stats and warnings. Enable Build proposals in PoB first.',inputSchema:object({}),annotations:readOnly},
  {name:'search_build_catalog',description:'Search the desktop build\'s native gems, passive nodes (including mastery effects), configuration choices or classes. Passive paths are recomputed during a proposal; IDs are tree-version specific.',
    inputSchema:object({kind:{enum:['gems','passives','config','classes']},query:string(160),limit:integer(1,50)},['kind','query']),annotations:readOnly},
  {name:'propose_build',description:'Calculate a new build or edits in PoB for desktop review. Use the latest baseRevision from get_build_context. set_skills replaces all active socket groups; allocate_passives adds native connecting paths and removes dependent nodes. No changes are applied or saved by this tool. Read get_proposal_status for calculated results and resolved gear/gems/tree. Only the desktop Apply button commits changes.',
    inputSchema:proposalSchema,annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
  {name:'get_proposal_status',description:'Read proposal status, calculated before/after stats, native warnings and review instructions. It cannot apply a proposal. Match the returned proposal ID to your queued request before consuming its result.',inputSchema:object({}),annotations:readOnly},
  {name:'get_build_analysis',description:'Read native assumption checks, equipment/gem dependencies and encounter death evidence from the connected build. Diagnosis separates observations from suggested paired tests.',inputSchema:object({}),annotations:readOnly},
  {name:'get_build_history',description:'Read up to eight calculated candidates retained in this desktop session, current goals and undo depth. Choosing or restoring one requires the desktop UI.',inputSchema:object({}),annotations:readOnly},
  {name:'get_build_connection',description:'Diagnose the desktop connection even when disabled or stale: heartbeat age, context refresh, last request/error and troubleshooting steps. This does not prove a particular AI client is connected.',inputSchema:object({}),annotations:readOnly},
  {name:'set_build_goals',description:'Set the desktop planning goal, optional budget/currency and minimum native stats. Goals rank calculated candidates using weighted percentage changes. Supplied dated total-price quotes are estimates, not live trade prices.',inputSchema:planSchema,annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
  {name:'compare_build_candidates',description:'Calculate 1-5 alternative proposals against the same base, with stat deltas, dependency checks, goal ranking and optional supplied total-cost quotes. Candidates remain unapplied. Review/select in desktop Candidates. Keep encounter assumptions fixed for meaningful comparisons.',
    inputSchema:object({baseRevision:proposalSchema.properties.baseRevision,candidates:{type:'array',minItems:1,maxItems:5,items:proposalSchema}},['baseRevision','candidates']),annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
  {name:'plan_leveling_build',description:'Calculate 1-8 increasing level milestones from the current build. Stage operations accumulate; set_skills must include the complete links at that stage. Supply level-appropriate gems/gear/passives; native checks expose unmet requirements. Each stage is a reviewable candidate, never automatically applied. For a fresh character first create/apply a starting build.',
    inputSchema:object({baseRevision:proposalSchema.properties.baseRevision,stages:{type:'array',minItems:1,maxItems:8,items:object({title:string(120),level:integer(1,100),operations:array({oneOf:operations.filter(op => op.properties.type.const !== 'set_character')},50),quote:quoteSchema},['title','level','operations'])}},['baseRevision','stages']),annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
  {name:'get_crafting_projects',description:'Read crafting projects saved with the connected build: starting item, target modifiers, steps, stop/failure routes, supplied costs and external simulation evidence. Native simulation recipes can be saved with each project; external Craft of Exile results remain supplied data.',inputSchema:object({}),annotations:readOnly},
  {name:'inspect_crafting_item',description:'Queue native item-editor modifier lookup and a documented Craft of Exile import handoff. Provide exactly one equipped slot or itemText. Poll get_proposal_status for inspected results. Spawn weights are not probabilities; method-specific rules require Craft of Exile validation. This never changes the build.',
    inputSchema:object({baseRevision:proposalSchema.properties.baseRevision,slot:string(80),itemText:string(24000),query:string(160),limit:integer(1,100)},['baseRevision']),annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
  {name:'propose_crafting_plan',description:'Propose a structured crafting project for native desktop review. Goals, steps, stop conditions, failure routes and supplied estimates stay with the build when explicitly saved. Optionally preview target equipment with equipTarget. A target item is a hypothetical outcome, not proof the recipe can craft it. Use nativeRecipe for our built-in simulator. Record external simulation results as supplied evidence.',
    inputSchema:object({baseRevision:proposalSchema.properties.baseRevision,project:craftingProjectSchema,equipTarget:boolean},['baseRevision','project']),annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
  {name:'apply_crafting_action',description:'Emulate one native crafting action on a separate item. It cannot change the desktop build. Provide exactly one slot or itemText, and optionally a returned initialState with the same original itemText to continue a sequence. inspect_crafting_item supplies native modifier, bench and essence IDs. Unsupported mechanics fail explicitly. Results can become target items in a reviewed crafting plan.',
    inputSchema:object({baseRevision:proposalSchema.properties.baseRevision,slot:string(80),itemText:string(24000),action:craftingAction,seed:integer(1,2147483646),initialState:craftingState},['baseRevision','action']),annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
  {name:'simulate_crafting',description:'Run native seeded Monte Carlo trials of a bounded recipe. Target groups are AND; anyOf modifier IDs within a group are OR. Steps can repeat untilTargets, then route onSuccess/onFailure. Stop at final targets or action budget. Return modeled success frequency, Wilson interval, spending, missing prices and transition errors. All supplied prices must use one currency. Limits and distribution assumptions are part of the result; this is not a complete game engine.',
    inputSchema:object({baseRevision:proposalSchema.properties.baseRevision,slot:string(80),itemText:string(24000),recipe:craftingRecipe,options:object({trials:integer(1,2000),maxActions:integer(1,2000),seed:integer(1,2147483646),prices:{type:'object',maxProperties:100,additionalProperties:number(0,1e12)},currency:string(24)})},['baseRevision','recipe']),annotations:{...readOnly,readOnlyHint:false,idempotentHint:false}},
];

function createBridge(reportPath) {
  const filename = name => path.join(path.dirname(reportPath || '.'),`AI-build-${name}.json`);
  const retryDelay = new Int32Array(new SharedArrayBuffer(4));
  function read(name) {
    const file = filename(name);
    // The native desktop may be refreshing this file. Retry brief incomplete reads.
    for (let attempt=0; ; attempt++) {
      try {
        if (fs.statSync(file).size > 16 * 1024 * 1024) throw new Error('Desktop build data exceeds the supported size.');
        return JSON.parse(fs.readFileSync(file,'utf8'));
      } catch (err) {
        if (attempt >= 4 || !(err instanceof SyntaxError || ['ENOENT','EBUSY'].includes(err.code))) throw err;
        Atomics.wait(retryDelay,0,0,5);
      }
    }
  }
  function state() {
    let result;
    try { result = read('state'); } catch (_) { throw new Error('Enable Build proposals in PoB > Simulation > AI tools first.'); }
    if (result.schemaVersion !== 1 || !result.enabled || typeof result.session !== 'string' || !Number.isFinite(result.heartbeat) || Math.abs(Date.now()/1000-result.heartbeat) > (result.proposal?.status === 'calculating' ? 120 : 15)) {
      throw new Error('Desktop connection is disabled or not responding. Open the build in PoB and enable Build proposals.');
    }
    return result;
  }
  return function call(name,args) {
    const tool = tools.find(t => t.name === name);
    if (!tool || !validate(args ?? {},tool.inputSchema)) throw new Error('Invalid build tool arguments. Follow the advertised schema.');
    if (name === 'get_build_connection') {
      let current;
      try { current = read('state'); } catch (_) { return {status:'unavailable',steps:['Open a build in PoB > AI builds.','Enable build proposals.','Copy MCP configuration into your AI client and reconnect.']}; }
      const heartbeatAgeSeconds = Number.isFinite(current.heartbeat) ? Math.max(0,Date.now()/1000-current.heartbeat) : null;
      const calculating = current.proposal?.status === 'calculating';
      return {status:current.schemaVersion !== 1 ? 'incompatible' : !current.enabled ? 'disabled' : heartbeatAgeSeconds === null || heartbeatAgeSeconds > (calculating ? 120 : 15) ? 'stale' : calculating ? 'calculating' : 'ready',heartbeatAgeSeconds,
        session:current.session,revision:current.revision,proposalStatus:current.proposal?.status,diagnostics:current.diagnostics,
        steps:['Keep PoB open and wait for calculations to finish.','Enable build proposals, then reconnect your AI client if tools are missing.','A ready desktop heartbeat does not verify that your AI client is connected.']};
    }
    if (name === 'propose_crafting_plan') {
      const project=args.project;
      if (project.simulation && project.simulation.successes > project.simulation.trials) throw new Error('Simulation successes cannot exceed trials.');
      if (args.equipTarget && !project.targetItem?.trim()) throw new Error('A target item is required for equipment preview.');
      args={mode:'edit',title:project.title,baseRevision:args.baseRevision,operations:[{type:'set_crafting_project',project},...(args.equipTarget ? [{type:'equip_item',slot:project.slot,text:project.targetItem}] : [])]};
      name='propose_build';
    }
    const current = state();
    if (name === 'get_build_history') return {history:current.history ?? [],plan:current.plan,undoDepth:current.diagnostics?.undoDepth ?? 0};
    if (name === 'get_proposal_status') return {session:current.session,revision:current.revision,proposal:current.proposal ?? null};
    const captured = read('context');
    if (captured.schemaVersion !== 1 || captured.session !== current.session || captured.context?.revision !== current.revision) throw new Error('Desktop context is refreshing. Try again after calculations finish.');
    if (name === 'get_crafting_projects') return {revision:current.revision,projects:captured.context.craftingProjects ?? [],warning:captured.context.craftingWarning,limitations:['Plans and cost/simulation results are supplied data, not independently verified recipes.','Use desktop review before applying; build Save persists projects.']};
    if (name === 'get_build_analysis') return {revision:current.revision,capturedAt:captured.capturedAt,audit:captured.context.audit,encounter:captured.context.encounter,plan:current.plan};
    if (name === 'get_build_context') {
      const {xml,...context} = captured.context;
      return {session:current.session,capturedAt:captured.capturedAt,context};
    }
    if (name === 'search_build_catalog') {
      const query = args.query.toLocaleLowerCase();
      const entries = captured.catalog?.[args.kind];
      if (!Array.isArray(entries)) throw new Error('Catalog unavailable. Refresh the desktop connection.');
      const matches = entries.filter(entry => JSON.stringify(entry).toLocaleLowerCase().includes(query));
      return {revision:current.revision,kind:args.kind,total:matches.length,matches:matches.slice(0,args.limit ?? 20)};
    }
    if (current.proposal?.status === 'review' || current.proposal?.status === 'calculating') throw new Error('Review or reject the pending proposal in PoB first.');
    if (name !== 'set_build_goals' && args.baseRevision !== current.revision) throw new Error('Build revision changed. Read get_build_context and submit a fresh proposal.');
    if (['inspect_crafting_item','apply_crafting_action','simulate_crafting'].includes(name) && Number(Boolean(args.slot)) + Number(Boolean(args.itemText)) !== 1) throw new Error('Provide exactly one slot or itemText.');
    if (name === 'simulate_crafting') {
      if ((args.options?.trials ?? 200)*(args.options?.maxActions ?? 100) > 20000) throw new Error('Use at most 20000 total budgeted actions.');
      if (args.options?.prices && !args.options.currency?.trim()) throw new Error('Specify one price currency.');
      for (const step of args.recipe.steps) {
        if ((step.maxAttempts ?? 1) > 1 && !step.untilTargets) throw new Error('Repeated steps need target conditions.');
        if ((step.onSuccess ?? 1) > args.recipe.steps.length+1 || (step.onFailure ?? 1) > args.recipe.steps.length+1) throw new Error('Invalid recipe route.');
      }
    }
    const proposals = name === 'compare_build_candidates' ? args.candidates : name === 'plan_leveling_build' ? args.stages : name === 'propose_build' ? [args] : [];
    let nodeCount=0,operationCount=0,priorLevel=0;
    for (const proposal of proposals) {
      if (!proposal.title.trim() || /[\x00-\x1f\x7f]/.test(proposal.title)) throw new Error('Proposal title must be a nonempty single line.');
      if (name === 'compare_build_candidates' && proposal.baseRevision !== current.revision) throw new Error('Every candidate must use the current base revision.');
      if (name === 'plan_leveling_build') {
        if (proposal.level <= priorLevel) throw new Error('Milestone levels must increase.');
        priorLevel=proposal.level;
        operationCount+=proposal.operations.length;
        if (operationCount > 99) throw new Error('Use at most 99 cumulative milestone operations.');
      }
      if (proposal.quote && (proposal.quote.quotedAt > Date.now()/1000+300 || !proposal.quote.source.trim())) throw new Error('Price quotes need a source and a valid capture time.');
      nodeCount+=proposal.operations.reduce((n,op) => n+(op.add?.length ?? 0)+(op.remove?.length ?? 0)+(op.masteries?.length ?? 0),0);
    }
    if (nodeCount > 400) throw new Error('Use at most 400 passive changes per request.');
    if (name === 'set_build_goals' && args.budget !== undefined && !args.currency) throw new Error('Budget needs a currency.');
    const id = randomUUID();
    const payload = name === 'apply_crafting_action' ? {kind:'craftAction',...args} : name === 'simulate_crafting' ? {kind:'craftSimulate',...args} : name === 'inspect_crafting_item' ? {kind:'craftInspect',...args} : name === 'set_build_goals' ? {kind:'plan',plan:args} : name === 'compare_build_candidates' ? {kind:'compare',...args} : name === 'plan_leveling_build' ? {kind:'leveling',...args} : {proposal:args};
    const request = JSON.stringify({id,session:current.session,...payload});
    if (Buffer.byteLength(request) > 262144) throw new Error('Proposal exceeds 256 KiB.');
    const temporary = filename(`request-${id}`);
    try {
      fs.writeFileSync(temporary,request,{flag:'wx'});
      // Publish a complete file exclusively; the desktop cannot read a half-written request.
      fs.linkSync(temporary,filename('request'));
    } catch (err) {
      if (err.code === 'EEXIST') throw new Error('A proposal is already queued. Wait for PoB to process it.');
      throw err;
    } finally { if (fs.existsSync(temporary)) fs.unlinkSync(temporary); }
    return {id,status:'queued',instructions:'PoB will process this planning request separately. Poll get_proposal_status and match this request ID, then review it in PoB > AI tools > Build proposals. Nothing has been applied or saved.'};
  };
}
module.exports = {tools,createBridge,validate};
