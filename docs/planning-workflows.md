# Connected planning tools

Open AI builds, Atlas, Crafting or Journey to enter the planning workspace. **Tools** in the top bar opens performance diagnostics and portable bundles.

## Performance and background upgrades

**Tools > Performance diagnostics** shows observed last, mean and worst processing times, ordered by the worst slice. Refresh after an interaction, or copy the timings when reporting a slowdown. Reset clears session measurements only.

**Journey > Gear > Measure upgrades** calculates candidates between frames. You can navigate to another tool while it works; the button shows completion counts and its tooltip shows the current phase. Cancel discards unfinished work and retains completed measurements. Editing the source build invalidates the ranking.

The worker restores the active build and calculation cache after every yield. Native edit identities avoid hashing the full build every frame; an exact XML revision check still runs before publishing results and before applying a proposal. Background work is cooperative: initial snapshots and some native loading/calculation operations can still pause input. Diagnostics report those pauses rather than promising a frame-rate target.

Developers can run `luajit ../tools/benchmark_planning.lua` from `src`, optionally supplying a build XML path. It reads the fixture without saving it and compares synchronous and background results, elapsed processing time and worst slice.

## Crafting recovery and spending

In **Crafting > Simulate recipe > Recipe routes**, select a step and open **Failure recovery**. Choose to continue along the failure route, stop for inspection, restart from the starting item, or set the item aside for salvage. Written recovery instructions stay with that step.

An unwanted roll counts as a failed step when its target or property conditions are unmet. With the successful-action condition, a supported currency use can succeed even though the final item is unfinished.

Restarting acquires another hypothetical starting item, adds its supplied starting-item cost and returns to step 1. The total action budget still limits loops. Enter a realistic base cost: zero means no acquisition cost is counted. Salvage ends the trial without inventing resale proceeds.

**Results / distribution** displays mean spending plus median, 90th and 99th percentile spending. Every executed action needs a supplied price in the same currency. These percentiles include unsuccessful and budget-capped trials; they are not the cost of guaranteed success. Successful-trial statistics remain separately labeled in the detail list. Run more trials to reduce sampling uncertainty.

## Survival stress tests

In **Survival charts**, choose a preset and select **New scenario**. Review its assumptions, then create a separate configuration set. Mapping pack stress, repeated boss hits, hits plus continuous damage, and resource pressure supplement the existing presets.

Damage scales from the active configuration's raw hit inputs. These are editable stress tests, not named-monster models or readiness guarantees. Check damage, penetration, enemy level, conditional buffs, flask policies and skill costs before running. The scenario description states the interval, scaling and continuous damage assumptions.

## Atlas stages and requirements

Use **Atlas > Stages & strategy** to label a plan Starter, Intermediate or Final and link its previous saved plan. The progression view orders refunds and allocations while preserving connectivity and the supplied point budget, including granted points. If a direct route fails, it tries a rebuild and labels the extra refunds. It reports when it cannot find a sequential route with the available budget. Routes are valid transitions, not minimum-refund solutions; refund currency prices are not assumed.

The strategy tab records maps and rolling requirements, map supplies and consumables, character/unlock requirements, mechanics or modifiers to avoid, and a dated setup estimate with currency and source. Record Threads for 3.30 strategies or Scarabs for older versions. Select **Use in Atlas draft**, then **Keep plan** and save the build. Estimates do not automatically spend or reserve Journey resources.

Linked stages must use the same Atlas version and cannot form a cycle. Saved Atlas plans have a total metadata size guard rather than an eight-plan count limit.

## Portable bundles

**Tools > Export / import complete bundle** copies native character XML and saved planning data together: items, skills, passive trees, configuration sets, notes, crafting guides and working checkpoints, Atlas stages/strategies, and Journey acquisition and leveling plans.

Keep working drafts before exporting. Paste and inspect a bundle to see its contents, then **Review as new build**. Native proposal review calculates it before you choose Apply. It opens as an unsaved new build and does not overwrite the source file.

Bundles have a version and corruption checksum, with a 16 MiB size guard. Imports retain recorded price dates, recipe assumptions and references; they do not refresh external data. Native builds also retain their normal save/export behavior.
