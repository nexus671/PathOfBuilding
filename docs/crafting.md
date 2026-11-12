# Native crafting

Open **AI builds → Crafting**, or choose **Items -> Crafting plan**. Create a project with a starting item and explicit item level, then choose **Open workbench**.

The workbench tabs separate **Craft**, **Targets**, **Simulate**, and **Settings**. Crafting runs locally. AI builds, Atlas and crafting projects share a persistent planning workspace; switching pages preserves an Atlas draft. Equipped gear changes only through the desktop preview and review flow.

Plain item copies can be imported when their complete modifier identities and rolls resolve uniquely. Advanced copy text helps preserve identities. Missing item levels, overlapping modifier tiers and values the engine cannot reconstruct require an explicit choice; the importer does not guess. For a structured starting state through MCP, use the corresponding blank base as the starting text.

## Emulate an item

**Find currencies** opens search beside the working item. Filter by category, favorite actions, and select one to return to the tray. Search takes keyboard focus; arrow keys browse results and Enter selects an available action. Escape clears focus first, then returns to the tray. Hover a currency for its purpose and current prerequisites.

The item card groups prefixes and suffixes, shows slot usage, and marks fractured (**F**) and crafted (**C**) modifiers. Click a modifier to inspect its ranges, tags and required level beside the item, select a relevant action, or use it as a target. Group tiers compare required levels within the eligible modifier group; special modifiers keep their data names.

**Settings** contains advanced method configuration, **Allflame settings**, and **Edit hypothetical item**. The Craft tab keeps the currency tray, selected action, apply/undo and history controls together.

**Item history** previews earlier items and the changes between them; restoring one undoes all subsequent actions. **Before / after** in Settings compares the working item with its recipe starting state. Drag the divider to give more space to the controls or item. Working state, favorites and history survive tool switches and resizing during the session.

In **Targets**, use **Find target modifiers** to search modifier text and tags, filter prefixes/suffixes or implicit types, inspect ranges and add a target without entering an ID.

Select an icon in the currency tray, then click the item card or **Apply to item**. The card shows the base artwork, rarity, sockets, defences and modifiers; applied currency counts appear on the tray. Other methods remain in the dropdown, with their choices below it. **Settings** opens recipe controls, donor/fossil configuration and the reproducible random seed. **Configure fossil combination / donor item** accepts up to four fossils or a second item for Awakener and recombination. A Tangled Fossil requires the effect already revealed by the socketed resonator.

**Undo currency** reverses an action; **Reset item** restores the starting state. Veiled Orbs leave an unfinished choice: select **Choose an unveil** and pick an offered modifier before previewing. An imprint belongs to this starting item and can be restored once.

The engine covers core currencies, bench modifiers, essences, fossils, Harvest tag crafts and resistance swaps, fractures, influence slams, Awakener, Dominance, veiled choices, Bestiary, Eldritch crafting, quality, catalysts, selected Ducats, corruption and selected tainted currencies. Jewels, flasks and tinctures have their own affix limits; flasks and tinctures remain magic. Cluster jewels need a known small-passive skill.

Unpredictable recombination can choose either base, and later actions continue on that base. Its probability model is experimental. See [coverage and assumptions](crafting-coverage.md) for missing or incomplete methods.

Use a blank base or item text whose modifier IDs PoB resolves. Unresolved explicit modifiers are rejected. Imported Eldritch implicits with ambiguous tiers need a structured state before Eldritch crafting continues.

**Orb of Remembrance** samples published observations. Memory strands restrict tiers for applicable currencies; **Orb of Unravelling** consumes the remaining strands to attempt upgrades. Foulborn Augmentation, Regal and Exalted orbs add a separate tier bias. Their estimates and uncertain cases are listed under **Coverage**. Import counts with a `Memory Strands: 82` line or continue the structured state returned by MCP; native PoB item text alone does not retain this property.

**Locus of Corruption** can destroy the hypothetical item. Destruction stops that trial, retains its currency spending and prevents previewing a nonexistent item. **Undo currency** still restores the prior emulated state.

**Predictable recombination (observed odds)** needs the game's displayed success percentage for the exact inputs and selected modifiers. Add one exact target for each selected modifier, with at least one from each input, then configure the donor and percentage. MCP accepts explicit `selectedMods.left` and `selectedMods.right` ID lists. The model preserves the chosen base's item level and treats failure as destruction. It fits a shared constant to your observation; its base shares remain estimates. It cannot independently calculate the game's displayed percentage.

**Allflame settings** uses current client data for currency outcomes and Sulphur costs. Choose your unlocked ship upgrades; **Observed override** accepts settings read in game. After applying currency, select a ghost and inspect its item card before keeping it. Recipes prefer the most matching target groups. Existing imprints are consumed. Kishara offers four retained-modifier choices; Tzamoto attempts to reset Intangibility, with destruction modeled as an assumed 50/50 branch.

**Edit hypothetical item** stages modifier additions, removals, replacements, rolls, fractures and basic properties. Keeping edits sets a new recipe start and clears the recorded currency sequence; Cancel discards them.

For recipes, Allflame prefers the outcome matching the most captured target groups, with ties keeping the first. A manually selected ghost is recorded as a fixed choice index; after collapse it keeps the only outcome. Costs include one currency use and one Sulphur charge, rather than charging for every ghost. These are conditional models using your settings, not an automatic Vesper data table. MCP supplies the same values in `action.allflame` and receives bounded `choices` with each emulated result.

## Set targets

Add a modifier on **Targets**. Separate groups require all groups by default; **Add alternative** makes an OR choice within the last group. **Target counts, rolls and item properties** edits the last group and final conditions:

- Required or excluded modifiers, matching counts and minimum roll percentages.
- Explicit or implicit modifiers, and how many groups must match.
- Specific fractured or crafted modifiers, open affix slots, affix/fracture counts, quality, sockets, links, corruption, memory strands and Intangibility.

Roll percentage means the position within a modifier's native range. For several sampled values, every value must meet the threshold. An unfinished unveil never counts as a completed target.

## Simulate a recipe

Set trials and the action budget. **Simulate action** repeats the action until its conditions match or the budget ends. **Keep actions as recipe** retains the emulator sequence. **Recipe routes** edits attempts and success/failure destinations, including bounded loops. **Simulate saved recipe** uses its captured initial state.

Jobs run in the background. **Cancel crafting job** stops them. Results include success frequency, a 95% Wilson sampling interval, currency uses, failed transitions and missing prices. **Results / distribution** shows action counts, spending percentiles, route visits and final modifier frequencies. Up to ten successful items are retained for a separate build preview. Successful-trial percentiles exclude failures; all-trial spending includes them. Trials stopped by the budget are reported separately.

The price field applies to the selected action. The starting-item cost field adds the base cost to every trial in the same currency. MCP can supply prices for each action or fossil/resonator component in one currency. Spending divided by observed successes is not a guaranteed in-game cost. Zero successes does not establish impossibility.

**Calculate action odds** enumerates supported finite outcomes, including next-affix draws, Talisman fractures and Allflame selection. Other supported actions and roll thresholds use bounded sampling with a confidence interval. Results state which method was used. **Compare subsets of the configured fossils** samples all combinations from the configured candidates and current state; it is not a global optimizer.

## Keep a project

Keeping a recipe marks the build unsaved. Use normal build **Save** to persist it. There is no project-count limit: keep plans for every gear slot and alternatives for each piece. Crafting metadata retains a 2 MiB total size limit and per-field validation. Projects and recipes live in AI Edition XML; other editions may discard them on re-save. AI Edition preserves unreadable or newer metadata unchanged.

**Preview in build** calculates a separate candidate. Review controls application, and the existing undo flow restores the build. Simulation and planning never spend game currency.

## Compare recipes

The desktop **Simulate → Compare recipes** view compares up to three supported routes with the same captured item, final targets, seed, trial count and action budget. Optional unit prices apply to single-action routes. A saved recipe without every executed action priced reports an unknown cost. Results include success intervals, mean actions, spending when known, and failed transitions. **Cancel comparison** stops the job. These are bounded model experiments, not guaranteed game costs.

**Coverage** is searchable by mechanic and lists assumptions alongside implemented actions. Advanced actions still validate item-specific prerequisites when applied.

## Use AI through MCP

Enable the desktop connection and reconnect the client after updating.

| Tool | Purpose |
| --- | --- |
| `get_crafting_projects` | Read saved projects. |
| `inspect_crafting_item` | Read native IDs, initial state and coverage; supply an action to inspect its Allflame profile. |
| `apply_crafting_action` | Emulate an action; continue with the original text and returned state. |
| `simulate_crafting` | Run a background recipe with targets, routes and prices. |
| `calculate_crafting` | Enumerate finite outcomes or sample other actions in a cancellable job. |
| `optimize_crafting_fossils` | Compare combinations from up to eight candidates. |
| `cancel_crafting_simulation` | Cancel using the job request ID. |
| `propose_crafting_plan` | Propose a saved project and equipment preview for review. |

Poll `get_proposal_status` for results. Requests allow at most 2,000 trials, 2,000 actions per trial and 20,000 budgeted actions overall. Results include seeds, versions and limitations. Simulation options accept `baseCost` and `retainSuccesses` (0-100); retained successes are the first successful trials. MCP never automatically equips an outcome or saves the build.

## External cross-check

Craft of Exile remains an optional independent check. Its [documented import links](https://beta.craftofexile.com/developers?game=poe1) accept advanced game-copy text; it provides no public crafting API. Other handoffs are labeled **base-only**. Verify the imported item and patch. External exports remain opaque data; supplied external results stay separately labeled from native calculations.

The project library separates **Item**, **Plan**, and **Sharing & tools**. The workbench stays in the planning workspace; **Back to projects** preserves the current item and undo history for this session. Currency icons dim when incompatible with the item, and the action hint explains why.

Base artwork is bundled from the same pinned game-data export as crafting. Missing artwork uses PoB's equipment silhouette. The workbench works offline; `python tools/update_crafting_art.py` refreshes the asset manifest when the crafting data is updated.
