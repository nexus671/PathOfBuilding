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

- [ ] Consistent typography, buttons, spacing, navigation and empty states.
- [ ] Explain unavailable actions and conflicting choices before execution.
- [x] Show stale dependencies after gear, craft or Atlas targets change.
- [x] Keep linked character, crafting, filter and farming plans easy to navigate.
- [x] Complete repeated native navigation at 960, 1024 and 1280 widths.
- [x] Verify save/reopen, undo, portable bundles and local MCP workflows.
- [ ] Review final screenshots, run required CI and verify the updater manifest.

Hosted economy feeds, community discovery/heatmaps, cloud sharing and automatic
account uploads are separate service work. Their absence does not justify a
placeholder that pretends to provide those results offline.

## Remaining release work

The published preview passed exact-commit CI with 1,107 Lua tests, 41 Node tests,
the real MCP save/reopen workflow and 630 source-stable UI frames without audit
failures. The updater manifest and every CI artifact source hash were verified
against commit `651e892487b61e77e2c86aab069ea3d5fc94c3f7`.

That preview includes the native colour wheel, brightness/opacity controls,
exact RGBA input and Ruthless validation. Native input tests also exposed and
fixed campaign fields rejecting numeric entry. The next review adds 14
client-derived Harvest quality enchantments, goals, native import/export and
resource costs. It also fixes repeated socket-count preparation costs when
linking an item that already has the requested count. Local validation passed
1,115 Lua tests, 42 Node tests, the real MCP workflow and 642 source-stable UI
states without audit failures. Exact-commit CI is still required for that batch.
The comparison engine passed 2,000
deterministic reconstruction cases. Caching bundled migrations preserved all
seven exported filters and their reports while reducing repeated work.

A read-only saved-build benchmark confirmed reversible tree edits and exposed a
false revision change caused by reordered derived full-DPS rows; the regression
is fixed. Foreground allocation plus recalculation measured 63-179 ms across five
edits while recovery completed separately. Proposal preparation still takes
several seconds on that build. These checks do not mark the release complete.

Next: close source-verified socket/corruption/league gaps and repeat cross-tool performance,
recovery and layout checks. The coverage guide continues to identify incomplete
mechanics explicitly.
