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

The latest verified checkpoint is `8cdcce32d4d65fcd2039b9748ec0cdad8920aebc`
([Run Tests](https://github.com/nexus671/PathOfBuilding-AI-Edition/actions/runs/43364585684),
[Spell Checker](https://github.com/nexus671/PathOfBuilding-AI-Edition/actions/runs/43364585785)).
It passed 1,134 Lua tests, 43 Node tests, the real MCP save/reopen workflow and
675 source-stable UI states without audit failures. All 2,411 updater file hashes
and every CI artifact source hash were verified against that commit.

The current review makes bench, Essence and Harvest choices reflect the working
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
Exact-commit CI remains required.

A read-only saved-build benchmark returned identical synchronous/background
results in 3.9 seconds each, with a 251 ms snapshot and an 18 ms worst worker
slice. A separate instrumented run measured 37 ms worst, versus 142-163 ms before
the added checkpoints. These bounded measurements do not establish sustained
desktop responsiveness. Snapshot creation and occasional initialization pauses
still need attention.

Complete the current availability regression checks, then repeat cross-tool performance and
recovery checks. Close source-verified socket, corruption and league gaps without
inventing missing weights. The [coverage guide](crafting-coverage.md) identifies
incomplete mechanics and model assumptions; this is not a full-parity release.
