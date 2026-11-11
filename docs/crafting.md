# Native crafting

Open **AI builds -> Crafting projects**, or select an item in **Items -> Crafting plan**. Create a project with a starting base, an explicit item level, targets and planning notes. Choose **Native crafting** to open our built-in emulator and simulator. It runs locally and does not depend on Craft of Exile.

## Emulate an item

Choose a currency, bench modifier or essence, then **Apply currency**. The emulated item stays separate from equipped gear. **Undo currency** reverses an action and **Reset item** restores the starting state. **Preview outcome in build** calculates its damage and defenses in a separate candidate; desktop review still controls application.

The current engine supports ordinary weapons, armour and jewellery:

- Transmutation, Alteration, Augmentation, Regal, Alchemy, Chaos and Exalted orbs.
- Annulment, Scouring and Divine orbs.
- Bench modifiers, crafted-mod removal and essences.
- Affix limits, modifier-group conflicts, item-level and influence spawn weights, fractured modifiers, prefix/suffix locks and attack/caster blocking for supported actions.

Start with a blank base or advanced item text whose modifier IDs PoB can resolve. Unresolved existing modifiers are rejected rather than silently omitted. Bench modifiers can also be continued using the returned structured state through MCP.

## Simulate a plan

Add target modifier tiers. Separate groups are **AND** conditions; **Add alternative** makes an **OR** choice within the last group. Targets currently match modifier IDs, not numeric roll thresholds. Integer roll values are sampled inclusively. Fractional display ranges use illustrative rolls because their underlying precision is unavailable in the exported data.

Set the seed, trial count and per-trial action budget. **Simulate selected action** repeats that action until targets are met or the budget is exhausted. **Keep actions as recipe** saves the emulator's sequence and targets with the project. **Simulate saved recipe** tests it from its original starting state. AI-authored recipes can also repeat steps and route success/failure to other steps.

Results show modeled success frequency, a 95% Wilson sampling interval, currency uses, failed transitions and supplied-price costs. The price field applies to the selected action; other recipe actions remain unpriced unless prices are supplied through MCP. Mean spending includes failed trials. Cost per observed success is aggregate spending divided by observed successes, not a guaranteed in-game cost.

The model assumes 4/5/6 rare affixes with weights 8/3/1 and equal chances of 1/2 magic affixes, then samples the legal modifier pool by spawn weight. These assumptions and PoB's data coverage affect results. Sampling intervals do not cover uncertainty in the game rules. Zero observed successes is not proof that a craft is impossible.

Fossils, Harvest, recombination, influence orbs, corruption, sockets/links, unveiling and special league actions are not implemented in this version. Unsupported methods fail explicitly. Jewels, flasks, tinctures, grafts, corrupted, mirrored and foulborn items are outside the current engine's scope.

## Keep projects with the build

A project holds starting and target items, desired modifiers, human-readable steps, stop/failure notes, supplied estimates and an optional executable native recipe. **Keep project in build** marks the build unsaved. Use normal build **Save** to persist it. Up to eight projects fit in a build. Completing and undoing planning steps does not spend currency.

Projects live in AI Edition build XML. Other editions may ignore the section and drop it on re-save. AI Edition preserves unreadable/newer crafting metadata unchanged rather than silently erasing it.

## Use AI through MCP

Enable the desktop connection and reconnect your MCP client after updating:

- `get_crafting_projects` reads the saved plans.
- `inspect_crafting_item` returns native modifiers, bench and essence IDs. Poll `get_proposal_status` for results.
- `apply_crafting_action` emulates one action on a separate item. Continue a sequence using the same original item text and its returned structured state.
- `simulate_crafting` runs bounded native recipes, with optional supplied prices in one common currency. It supports AND/OR target groups, an optional final rarity, per-step attempt limits and success/failure routes. The total budget is limited to 20,000 attempted actions per request.
- `propose_crafting_plan` proposes a project, optional `nativeRecipe`, and optional hypothetical equipment preview for desktop review. It never changes equipment or saves a build automatically.

Native results include source/engine versions, seeds, coverage and distribution assumptions. A calculated target item's stats do not prove that a particular crafting plan can produce it.

## Optional Craft of Exile handoff

Craft of Exile remains an optional external cross-check. Its [documented item-import links](https://beta.craftofexile.com/developers?game=poe1) accept advanced game-copy text; it provides no API. Other handoffs are labeled **base-only**, since PoB's internal item format cannot reliably preserve every modifier there. Verify imported modifiers, quality, item level, influences and patch before simulating.

External simulator exports can be attached and copied as opaque text. External trial/cost results remain supplied evidence, separately labeled from our native calculations. Neither path spends currency in the game.
