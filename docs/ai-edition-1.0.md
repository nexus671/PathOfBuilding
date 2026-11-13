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

## Crafting

- [x] Browse modifiers with tiers, weights, groups and exclusion explanations.
- [x] Edit target groups directly, with clear AND/OR and property requirements.
- [x] Inspect recipe branches visually and edit routes without numeric guesswork.
- [x] Keep experimental items in a named local inventory.
- [x] Compare methods and explore success/budget and spending distributions.
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

The published preview passed exact-commit CI with 1,086 Lua tests, 40 Node tests,
the real MCP save/reopen workflow and 585 source-stable UI frames without audit
failures. The updater manifest and every CI artifact source hash were verified
against commit `787b7d3c857092331f33839de82c8c46d75e111c`.

The next review adds in-place category styling, source-file comparison, complete
scene paging, separate ad-hoc tests and unavailable-action guards. Local validation passed 1,099 Lua tests, 41 Node tests, the MCP workflow and
612 source-stable UI states without audit failures. Final screenshot review also
clarified default-Show sample explanations. Exact-commit CI is still required. The comparison engine also passed 2,000
deterministic reconstruction cases. Caching bundled migrations preserved all
seven exported filters and their reports while reducing repeated work.

A read-only saved-build benchmark confirmed reversible tree edits and exposed a
false revision change caused by reordered derived full-DPS rows; the regression
is fixed. Foreground allocation plus recalculation measured 63-179 ms across five
edits while recovery completed separately. Proposal preparation still takes
several seconds on that build. These checks do not mark the release complete.

Next: close source-verified socket/corruption/league gaps, add the colour picker,
and repeat cross-tool performance,
recovery and layout checks. The coverage guide continues to identify incomplete
mechanics explicitly.
