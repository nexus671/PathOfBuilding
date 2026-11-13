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

- [ ] Consistent typography, buttons, spacing, navigation and empty states.
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

The published preview passed exact-commit CI with 1,120 Lua tests, 42 Node tests,
the real MCP save/reopen workflow and 666 source-stable UI frames without audit
failures. The updater manifest and every CI artifact source hash were verified
against commit `24f68d7d851e160942b7ab287d6000124c87b40a`.
That preview includes the native colour wheel, brightness/opacity controls,
exact RGBA input and Ruthless validation. Native input tests also exposed and
fixed campaign fields rejecting numeric entry. It also includes 14
client-derived Harvest quality enchantments, goals, native import/export and
resource costs. It also fixes repeated socket-count preparation costs when
linking an item that already has the requested count, and removes duplicate
recovery trials during AI candidate loading. Atlas map-supply wording and the
visible Rules button are included. The real MCP workflow now discovers and
applies a Harvest enchantment, prices its recipe, reviews two gear guides and
preserves them through save/reopen and portable bundle import.

That preview also shows native weapon properties and Ward in item comparisons,
keeps invalid forms editable and explains input errors without Lua source paths.
It also disables the non-white socket bench when no count option exists
and adds consistent ellipses to long build/save-status labels. Native input checks
confirm Enter cannot select the unavailable action and a valid two-socket craft
still applies.

The next review adds native weapon/defence minimums to item goals, recipe stop
conditions, the target editor and MCP inspection. A real MCP workflow verifies
changed native Armour values after a Harvest enchantment and preserves that goal
through save/reopen and bundle import. Local validation passed 1,126 Lua tests, 43 Node tests, the real MCP workflow
and 672 source-stable UI states without audit failures. Exact-commit CI remains
required.
The comparison engine passed 2,000
deterministic reconstruction cases. Caching bundled migrations preserved all
seven exported filters and their reports while reducing repeated work.

A read-only saved-build benchmark confirmed reversible tree edits and exposed a
false revision change caused by reordered derived full-DPS rows; the regression
is fixed. Foreground allocation plus recalculation measured 63-179 ms across five
edits while recovery completed separately. Proposal preparation still takes
several seconds on that build. An isolated comparison of the new candidate-load
path measured 7.1 seconds before and 5.7 seconds after, with all 708 numeric
outputs identical. An earlier comparison measured 6.7 versus 4.7 seconds. These
bounded checks do not establish sustained UI performance or mark the release complete.
The final native benchmark returned identical synchronous/background results:
3.8 seconds synchronously, 4.6 seconds in the worker, and 236 ms to snapshot.
Its slowest worker slice was 137 ms, so long initialization slices still need
attention even though the total calculation now does less work.

Next: close source-verified socket/corruption/league gaps and repeat cross-tool performance,
recovery and layout checks. The coverage guide continues to identify incomplete
mechanics explicitly.
