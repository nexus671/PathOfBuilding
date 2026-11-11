# Native crafting

Open **AI builds -> Crafting projects**, or choose **Items -> Crafting plan**. Create a project with a starting item and explicit item level, then choose **Native crafting**.

The pages separate **Emulate item**, **Target conditions**, and **Simulate recipe**. Crafting runs locally. Equipped gear changes only through the desktop preview and review flow.

## Emulate an item

Choose an action and its options, then **Apply currency**. **Configure fossil combination / donor item** accepts up to four fossils or a second item for Awakener and recombination. A Tangled Fossil requires the effect already revealed by the socketed resonator.

**Undo currency** reverses an action; **Reset item** restores the starting state. Veiled Orbs leave an unfinished choice: select **Choose an unveil** and pick an offered modifier before previewing. An imprint belongs to this starting item and can be restored once.

The engine covers core currencies, bench modifiers, essences, fossils, Harvest tag crafts and resistance swaps, fractures, influence slams, Awakener, Dominance, veiled choices, Bestiary, Eldritch crafting, quality, catalysts, selected Ducats, corruption and selected tainted currencies. Jewels, flasks and tinctures have their own affix limits; flasks and tinctures remain magic. Cluster jewels need a known small-passive skill.

Unpredictable recombination can choose either base, and later actions continue on that base. Its probability model is experimental. See [coverage and assumptions](crafting-coverage.md) for missing or incomplete methods.

Use a blank base or item text whose modifier IDs PoB resolves. Unresolved explicit modifiers are rejected. Imported Eldritch implicits with ambiguous tiers need a structured state before Eldritch crafting continues.

## Set targets

Add a modifier on **Target conditions**. Separate groups require all groups by default; **Add alternative** makes an OR choice within the last group. **Target counts, rolls and item properties** edits the last group and final conditions:

- Required or excluded modifiers, matching counts and minimum roll percentages.
- Explicit or implicit modifiers, and how many groups must match.
- Open affix slots, affix counts, quality, sockets, links and corruption.

Roll percentage means the position within a modifier's native range. For several sampled values, every value must meet the threshold. An unfinished unveil never counts as a completed target.

## Simulate a recipe

Set trials and the action budget. **Simulate selected action** repeats the action until its conditions match or the budget ends. **Keep actions as recipe** retains the emulator sequence. **Recipe routes** edits attempts and success/failure destinations, including bounded loops. **Simulate saved recipe** uses its captured initial state.

Jobs run in the background. **Cancel crafting job** stops them. Results include success frequency, a 95% Wilson sampling interval, currency uses, failed transitions and missing prices. **Results / distribution** shows action counts, spending percentiles and route visits. Successful-trial percentiles exclude failures; all-trial spending includes them. Trials stopped by the budget are reported separately.

The price field applies to the selected action. MCP can supply prices for each action or fossil/resonator component in one currency. Spending divided by observed successes is not a guaranteed in-game cost. Zero successes does not establish impossibility.

**Exact next-mod odds** enumerates one legal weighted draw for Augmentation, Regal, Exalted or influenced Exalted orbs, conditional on the supplied state and pool. **Compare subsets of the configured fossils** samples all combinations from the configured candidates and current state; it is not a global optimizer.

## Keep a project

Keeping a recipe marks the build unsaved. Use normal build **Save** to persist it. Up to eight projects fit in a build. Projects and recipes live in AI Edition XML; other editions may discard them on re-save. AI Edition preserves unreadable or newer metadata unchanged.

**Preview outcome in build** calculates a separate candidate. Review controls application, and the existing undo flow restores the build. Simulation and planning never spend game currency.

## Use AI through MCP

Enable the desktop connection and reconnect the client after updating.

| Tool | Purpose |
| --- | --- |
| `get_crafting_projects` | Read saved projects. |
| `inspect_crafting_item` | Read native IDs, initial state, options and coverage. |
| `apply_crafting_action` | Emulate an action; continue with the original text and returned state. |
| `simulate_crafting` | Run a background recipe with targets, routes and prices. |
| `calculate_crafting` | Enumerate one next-affix draw. |
| `optimize_crafting_fossils` | Compare combinations from up to eight candidates. |
| `cancel_crafting_simulation` | Cancel using the job request ID. |
| `propose_crafting_plan` | Propose a saved project and equipment preview for review. |

Poll `get_proposal_status` for results. Requests allow at most 2,000 trials, 2,000 actions per trial and 20,000 budgeted actions overall. Results include seeds, versions and limitations. MCP never automatically equips an outcome or saves the build.

## External cross-check

Craft of Exile remains an optional independent check. Its [documented import links](https://beta.craftofexile.com/developers?game=poe1) accept advanced game-copy text; it provides no public crafting API. Other handoffs are labeled **base-only**. Verify the imported item and patch. External exports remain opaque data; supplied external results stay separately labeled from native calculations.
