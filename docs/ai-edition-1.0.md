# AI Edition 1.0 release review

This is the working acceptance checklist, not a completed release announcement.
The installed application and personal builds are outside this release workspace.

## Filters

- [x] Edit item tiers directly, including movement, ordering, new tiers and removal of overrides.
- [x] Reuse and share local rule modules between profiles.
- [x] Review changes, undo/redo edits and recover interrupted drafts.
- [x] Organise item families and explain provable rule priority conflicts.
- [x] Configure campaign weapon/defence families and browse compiled source sections.
- [x] Reach every shared catalogue result through paging.
- [x] Test clipboard items, configure scene levels and revisit sample history.
- [x] Save named exact example sets and reusable appearance palettes in the build.
- [x] Style selected categories in place and review complete file changes.
- [x] Page through saved examples and test separate items without overwriting the sets.
- [x] Expand shared colour/sound styling and preview every supported icon shape.
- [x] Choose colours visually with exact RGBA entry and Ruthless opacity validation.

## Crafting

- [x] Browse modifiers with tiers, weights, groups and exclusion explanations.
- [x] Edit target groups directly, with clear AND/OR and property requirements.
- [x] Inspect recipe branches visually and edit routes without numeric guesswork.
- [x] Keep experimental items in a named local inventory.
- [x] Show native weapon DPS, attack rate, critical chance and Ward in item comparisons.
- [x] Use native weapon and defence minimums as saved crafting goals and recipe stop conditions.
- [x] Compare methods and explore success/budget and spending distributions.
- [x] Save per-resource quotes, reuse them across gear guides and share them with native/MCP simulations.
- [x] Apply quality enchantments with native item state, recipe goals and resource costs.
- [ ] Review incomplete socket, corruption and league mechanics against sources.
- [x] Keep empirical assumptions visible; never present unknown weights as facts.

## Atlas

- [x] Save desired and avoided nodes and select mechanic notables together.
- [x] Preview/recalculate all desired targets, with explicit apply and pause controls.
- [x] Summarise mechanic investment, small nodes, blocking and keystone tradeoffs.
- [x] Compare saved plans visually and preserve exact tree versions.

## Shared experience

- [x] Consistent planning typography, buttons, spacing, navigation and empty states.
- [ ] Explain unavailable actions and conflicting choices before execution.
- [x] Keep invalid forms editable and explain validation errors without source paths.
- [x] Show stale dependencies after gear, craft or Atlas targets change.
- [x] Keep linked character, crafting, filter and farming plans easy to navigate.
- [x] Complete repeated native navigation at 960, 1024 and 1280 widths.
- [x] Verify save/reopen, undo, portable bundles and local MCP workflows.
- [ ] Review final screenshots, run required CI and verify the updater manifest.

Hosted economy feeds, community discovery/heatmaps, cloud sharing and automatic
account uploads are separate service work. Their absence does not justify a
placeholder that pretends to provide those results offline.

## Remaining release work

The latest verified checkpoint is `57bcc0a5ba3e2243de11fcb90e7b6ebc600ae84f`
([Run Tests](https://github.com/nexus671/PathOfBuilding-AI-Edition/actions/runs/43404519236),
[Spell Checker](https://github.com/nexus671/PathOfBuilding-AI-Edition/actions/runs/43404519345)).
It passed 1,174 Lua tests, 45 Node tests, the real MCP save/reopen workflow and
780 source-stable UI states without audit failures. All 2,423 updater file hashes
and every CI artifact source hash were verified against that commit.

Preview 17 makes bench, Essence and Harvest choices reflect the working
item. Bench and Essence execution share their precondition helpers with the
menus; Harvest choices use the native eligible pool. Resistance swaps exclude
fractures, locked suffixes, conflicting groups and missing tiers. Valid selections
survive list changes and switching currencies. MCP retains future planning IDs
while reporting current availability and reasons.

The initial seven-base diagnostic found 54 invalid offered first choices;
the corrected probe applied all 105 offered first choices without errors. A
bounded availability benchmark measured at most 0.6 ms mean per check. Focused
engine, catalogue and native selection tests pass. Full local validation passed
1,140 Lua tests and 687 source-stable UI states without audit failures. The real
MCP workflow verifies availability metadata on both normal and rare inputs.
Exact-commit CI passed for preview 17, and its source hashes were verified.

Preview 18 extends shared prerequisites to Bestiary conversions and meta
crafts, Ducats, memory currencies, Dominance, Binding and Veiled Orbs. The expanded
seven-base probe previously offered 162 actions that failed engine prerequisites.
It now applies 340 available actions without errors, excluding crafts that require
a separately configured donor. Positive tests preserve eligible crafts, including
locked-source Bestiary conversions. A ten-seed sweep then found a native item
serialization error for independently rolled corruption implicits. Rolled implicit
lines now preserve each value without passing a range table to the scalar-only
serializer; Eldritch and Blessed Orb lines use the same conversion. The corrected
sweep applied all 3,400 actions without errors. Local validation passed 1,144 Lua
tests, the real MCP workflow and 696 source-stable UI states without audit
failures. Exact-commit CI passed, and its artifact source hashes were verified.

Preview 19 adds Omen of Connections with currency artwork, availability
checks, undo and two-resource costs. Socket-service metadata lets MCP discover
the action and costs; the native guide can combine a Harvest enchantment and
guaranteed linking. Socket bench and Omen calculations return a single exact
model outcome instead of a sampling interval. The MCP schema also accepts
multi-value Blessed Orb rolls, with matching native validation. Local validation passed 1,151 Lua tests, 43 Node tests, the full MCP save/reopen
workflow and 711 source-stable UI states without audit failures. Exact-commit
CI passed, and its artifact source hashes were verified.

A follow-up modifier audit found that all 44 tested multi-line affixes reused
the first roll on later lines. Native item crafting, plain import inference,
bench modifiers and workbench comparisons now share the same range renderer.
The corrected audit has no mismatches; scalar and legacy singleton rolls retain
uniform behavior. The regression matrix also verifies native item round trips.

Before this review, a read-only saved-build benchmark returned equivalent synchronous and
background results in 3.93 and 4.87 seconds, with a 250 ms snapshot and a 38 ms
worst worker slice. Earlier runs measured about 3.9 seconds each, with 18-37 ms
worst slices after adding checkpoints, versus 142-163 ms before them. These
bounded, variable measurements do not establish sustained desktop
responsiveness or exclude a performance regression. Snapshot creation and
occasional initialization pauses still need attention.

Preview 20 replaces full active-item reparsing during AI snapshots with
read-only capture. Unusual range normalization uses an isolated native parse;
regular native file saves keep their existing path. Revision hashing uses the
captured tree while retaining legacy XML normalization and hashes. It also
avoids composing a full snapshot when only the revision is needed.

The 264-item saved-build check preserves every XML byte, the legacy hash and
active item objects. A separate catalogue comparison passed all 1,333 unique
items without XML mismatches. Focused tests cover range rounding, variants,
whitespace/entities, source edits and notes restoration on failure. The command
`luajit ../tools/check_snapshot_equivalence.lua path/to/build.xml`, run from
`src`, repeats the saved-build proof without writing the supplied file.
A paired run captured the same 476,247 XML bytes and legacy revision in 119 ms,
versus 282 ms for the legacy path; a revision-only check took 91 ms. The idle
planning benchmark measured a 101 ms snapshot, 3.79 seconds synchronous,
3.53 seconds background and an 18 ms worst worker slice, with equivalent
calculations. These bounded timings do not prove sustained desktop responsiveness.

Local validation passed 1,155 Lua tests, the full MCP workflow and 711
source-stable UI states without audit failures. Exact-commit CI passed, and its
artifact source hashes were verified.

Preview 21 adds a native resource-price editor with searchable currency
artwork, recipe-resource and quoted-resource views, source/date metadata and
copying between gear projects. Quotes persist in builds and portable bundles.
Native simulation, recipe comparison, fossil optimization and MCP use the same
resource aliases and explicit action-override rules. Zero means free; a missing
quote remains unknown. Unit changes require clearing quotes rather than
relabeling their values. Bench and other aggregate prices are labelled as whole
actions; the editor does not invent ingredient quantities or fetch live prices.

Local review passed 1,162 Lua tests, 44 Node tests, ModCache regeneration and
the real MCP workflow. Regression checks cover zero/missing prices, aliases for
all six influence currencies, overrides, project reuse and empty dictionaries.
The final local and CI passes covered 732 source-stable UI states without audit
failures. Exact-commit CI passed, and all artifact source hashes were verified.

Preview 22 checks the recovery worker's time budget before every
simulation step. Previously it checked only once per eight steps, allowing a
batch of expensive events to exceed the frame budget. Five paired native
build edits preserve all recovery outputs, individual trial data and timeline
data. The worst worker slice fell from 53 ms to 32 ms in that bounded run;
total work remained similar. Individual events and collection pauses can
still exceed the budget, and sustained desktop responsiveness remains unproven.

The read-only command `luajit ../tools/benchmark_tree_responsiveness.lua
path/to/build.xml 5`, run from `src` with the headless Lua environment, reports
allocation, normal calculation and recovery-worker times. It restores each
passive edit and checks the original revision without saving the supplied file.

Preview 23 adds source-matched bench ingredients and exposes them in
native quotes, recipe costs and MCP inspection. Independent and runtime joins
agree on 3,541 of 3,737 ordinary craft/class cases, plus 368 of 390 Rune Dagger
and Warstaff cases. Other costs stay unknown. Conflicting quote aliases are
rejected before a project is admitted, and empty quote books retain the working
unit. A bounded 100-project validation probe took 17 ms.

Fossil comparison now has artwork, selectable subsets, a chance/interval plot,
cost and chance sorting, explicit unknown costs, quote provenance and CSV export.
The mixed priced/unpriced ordering is consistent, and selection does not spend
currency. Configuration retains existing choices, rejects duplicates and does
not assume an unrevealed Tangled outcome. Local review passed 1,168 Lua tests,
44 Node tests and the real MCP workflow. Exact-commit CI passed 1,169 Lua tests
and 759 source-stable UI states, including incomplete saved fossil configuration
recovery. Updater and artifact source hashes were verified.

Preview 24 isolates action totals from shared resource quotes. The
reproduced case changed an Alchemy-priced bench craft from 1 to 7 chaos even
though the recipe never executed Alchemy. The scoped override leaves it at 1;
an actual Alchemy action uses 7. Global resource-price overrides remain global,
zero action totals remain free, and results report applied override counts.

Native recipe comparisons now accept property-only goals, retain invalid price
input with a readable error, and use the same scoped totals. Simulation cost is
shown near the top of its summary. Crafted-mod removal and one/three-modifier
bench reforges use pinned service quantities. The added regressions cover
caller immutability, missing units, non-finite values, CSV provenance and exact
fossil-subset overrides. Inspection, performed actions and simulation steps
expose their price keys for MCP clients. Four-fossil Allflame override keys also
survive checkpoint save/reopen. Local review passed 1,174 Lua tests, 45 Node
tests, the real MCP workflow and 780 source-stable UI states without audit
failures. Exact-commit follow-up CI passed after the test-host fix below.

The first preview 24 CI run passed the Lua, Node, UI and ModCache checks but
timed out during the MCP filter test. A Linux reproduction exposed draw commands
accumulating in the headless test host across polling frames. The host now uses
the recorder's frame boundary and the workflow rejects unbounded command counts.
The instrumented full workflow passed with at most 13,054 retained commands,
versus 5.77 million before the diagnostic run was stopped. This fixes the test
host; it does not establish sustained desktop performance. Follow-up CI passed.

The current review fixes result refinement switching from a saved recipe to the
currently selected action. Refined runs retain the captured item, recipe, targets,
seed, quotes and budget while increasing only trials. The simulation header names
the selected action, and result summaries identify saved recipes. Calculation
buttons prevent duplicate jobs; closing a workbench cancels its own calculation.
Captured result setups survive layout changes, while older results without a
captured setup require a fresh simulation before refinement.

Repeat cross-tool performance and recovery checks. Close source-verified socket, corruption and league gaps without
inventing missing weights. The [coverage guide](crafting-coverage.md) identifies
incomplete mechanics and model assumptions; this is not a full-parity release.
