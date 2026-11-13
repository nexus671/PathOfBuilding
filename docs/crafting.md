<!-- cspell:ignore RRBG -->
# Native crafting

Open **AI builds → Crafting**, or choose **Items → Crafting plan**. Create a project with a starting item and explicit item level, then choose **Open workbench**.

The workbench tabs separate **Craft**, **Targets**, **Simulate**, and **Settings**. Crafting runs locally. AI builds, Atlas and crafting projects share a persistent planning workspace; switching pages preserves an Atlas draft. Equipped gear changes only through the desktop preview and review flow.

The **Rules** button shows the crafting rules version. Click it to review supported methods and assumptions. Choosing a newer character or Atlas tree does not change the crafting rules.

Plain item copies can be imported when their complete modifier identities and rolls resolve uniquely. Advanced copy text helps preserve identities. Missing item levels, overlapping modifier tiers and values the engine cannot reconstruct require an explicit choice; the importer does not guess. For a structured starting state through MCP, use the corresponding blank base as the starting text.

## Emulate an item

**Find currencies** opens search beside the working item. Filter by category, favorite actions, and select one to return to the tray. Search takes keyboard focus; arrow keys browse results and Enter selects an available action. Escape clears focus first, then returns to the tray. Hover a currency for its purpose and current prerequisites. Bench, Essence and Harvest choices follow the working item's slots, modifiers and rarity. The selected choice is retained while valid; a changed item cannot leave the dropdown pointing at a removed choice.

The item card groups prefixes and suffixes, shows slot usage, and marks fractured (**F**) and crafted (**C**) modifiers. Click a modifier to inspect its ranges, tags and required level beside the item, select a relevant action, or use it as a target. Group tiers compare required levels within the eligible modifier group; special modifiers keep their data names.

Weapon cards show native local DPS, its damage-type breakdown, attacks per second and critical chance. Armour cards include Ward. These properties also appear in saved-item comparisons; **Preview in build** calculates their character effects.

**Settings** contains advanced method configuration, **Allflame settings**, and **Edit hypothetical item**. The Craft tab keeps the currency tray, selected action, apply/undo and history controls together.

Search **Find currencies** for **replace quality** to apply a Harvest quality enchantment. The choices show the required Lifeforce amount and colour. The new enchantment replaces the previous one; affixes, socket colours and quality remain. **Targets → Item properties** can require a particular Harvest enchantment. These goals and enchanted inventory items also travel through MCP and saved projects.

**Set sockets and link them** is a combined bench preparation: it sets the requested socket count if necessary, then links those sockets. When the count already matches, estimates charge only the linking cost. Corrupted items include the corresponding Vaal Orb surcharge. Resource estimates use the state before each action.

Search **Find currencies** for **white sockets** to use the 3.30 bench craft. It turns supported sockets white without changing their links, for one Orb of Scouring and, on corrupted items, one Vaal Orb. The rest of the crafting data remains pinned to 3.29.3.6; see **Coverage** for its limits.

Find **Omen of Trichromatism (RGB)** in **Find currencies** to use one Omen and one
Chromatic Orb together. It guarantees at least one red, green and blue socket on
an uncorrupted item with at least three ordinary sockets, preserving their links.
Recipes can combine it with Omen of Connections for linked RGB goals. Placement
and additional colours use the stated socket-model assumptions; a three-socket
item gets exactly one of each colour. Three-socket calculations enumerate all
six placements under the uniform-position assumption; larger items use labelled
sampling. Undo restores the previous item; saved working crafts retain the action,
and simulation results report both ingredient quantities.

**Allflame settings** is unavailable for actions without a supported Allflame
transition, including Omen combinations and bench services. Its tooltip explains
the restriction before an unsupported profile can be entered.

**Item history** previews earlier items and the changes between them; restoring one undoes all subsequent actions. **Before / after** in Settings compares the working item with its recipe starting state. Drag the divider to give more space to the controls or item. Working state, favorites and history survive tool switches and resizing during the session.

In **Targets**, use **Find target modifiers** to browse tiers, item levels, weights, groups and tags. The table explains blocked modifiers and shows conditional draw chances. These describe one ordinary affix draw, rather than the selected currency or a complete recipe. The same explanations are available through AI inspection.

Select an icon in the currency tray, then click the item card or **Apply to item**. The card shows the base artwork, rarity, sockets, defences and modifiers; applied currency counts appear on the tray. Other methods remain in the dropdown, with their choices below it. **Settings** opens recipe controls, donor/fossil configuration and the reproducible random seed. **Configure fossil combination / donor item** accepts up to four fossils or a second item for Awakener and recombination. A Tangled Fossil requires the effect already revealed by the socketed resonator.

**Undo currency** reverses an action; **Reset item** restores the starting state. Veiled Exalted Orbs leave an unfinished choice: select **Choose an unveil** and pick an offered modifier before previewing. An imprint belongs to this starting item and can be restored once.

The engine covers core currencies, bench modifiers, essences, fossils, Harvest tag crafts and resistance swaps, fractures, influence slams, Awakener, Dominance, veiled choices, Bestiary, Eldritch crafting, quality, catalysts, selected Ducats, corruption and selected tainted currencies. Jewels, flasks and tinctures have their own affix limits; flasks and tinctures remain magic. Cluster jewels need a known small-passive skill.

Unpredictable recombination can choose either base, and later actions continue on that base. Its probability model is experimental. See [coverage and assumptions](crafting-coverage.md) for missing or incomplete methods.

Use a blank base or item text PoB can identify. Unresolved explicit modifiers are rejected. If an imported implicit cannot be identified, the workbench explains which calculations are unavailable. Try advanced item text with modifier ranges or another starting item. MCP clients can also supply a known structured implicit state.

**Orb of Remembrance** samples published observations. Memory strands restrict tiers for applicable currencies; **Orb of Unravelling** consumes the remaining strands to attempt upgrades. Foulborn Augmentation, Regal and Exalted orbs add a separate tier bias. Their estimates and uncertain cases are listed under **Rules**. Import counts with a `Memory Strands: 82` line or continue the structured state returned by MCP; native PoB item text alone does not retain this property.

**Locus of Corruption** can destroy the hypothetical item. Destruction stops that trial, retains its currency spending and prevents previewing a nonexistent item. **Undo currency** still restores the prior emulated state.

**Predictable recombination (observed odds)** needs the game's displayed success percentage for the exact inputs and selected modifiers. Add one exact target for each selected modifier, with at least one from each input, then configure the donor and percentage. MCP accepts explicit `selectedMods.left` and `selectedMods.right` ID lists. The model preserves the chosen base's item level and treats failure as destruction. It fits a shared constant to your observation; its base shares remain estimates. It cannot independently calculate the game's displayed percentage.

**Allflame settings** uses current client data for currency outcomes and Sulphur costs. Choose your unlocked ship upgrades; **Observed override** accepts settings read in game. After applying currency, select a ghost and inspect its item card before keeping it. Recipes prefer the most matching target groups. Existing imprints are consumed. Kishara offers four retained-modifier choices; Tzamoto attempts to reset Intangibility, with destruction modeled as an assumed 50/50 branch.

**Edit hypothetical item** stages modifier additions, removals, replacements, rolls, fractures and basic properties. Keeping edits sets a new recipe start and clears the recorded currency sequence; Cancel discards them.

For recipes, Allflame prefers the outcome matching the most captured target groups, with ties keeping the first. A manually selected ghost is recorded as a fixed choice index; after collapse it keeps the only outcome. Costs include one currency use and one Sulphur charge, rather than charging for every ghost. These are conditional models using your settings, not an automatic Vesper data table. MCP supplies the same values in `action.allflame` and receives bounded `choices` with each emulated result.

## Set targets

Add a modifier on **Targets**. **Edit target groups** manages required groups (AND) and alternatives within each group (OR). Select a group to edit its counts, rolls and conditions; **Item properties** opens a shorter form for shared final-item conditions and preserves the modifier groups:

- Required or excluded modifiers, matching counts and minimum roll percentages.
- Explicit or implicit modifiers, and how many groups must match.
- Specific fractured or crafted modifiers, open affix slots, affix/fracture counts, quality, sockets, links, corruption, memory strands and Intangibility.

**Weapon and defence goals**, inside **Item properties**, sets minimum physical/elemental/chaos/total weapon DPS, attack rate, critical chance, Armour, Evasion, Energy Shield and Ward. These use PoB's native local item calculations before character bonuses. Blank fields impose no condition; every supplied minimum must pass, and a stat from an incompatible item type cannot match. Decimal thresholds are supported. Recipes stop when the calculated stats meet the goal, which can happen before maximum quality because native damage values round. MCP inspection returns `nativeStats`; supply minimums as `requirements.nativeStats`, for example `{"PhysicalDPS":300,"AttackRate":1.5}`. They persist with recipes, inventory workflows and portable guides.

**Socket colours** accepts one to six exact colours, such as `RRBG`. Order does not matter; repeated letters require that many sockets. Choose **In one linked group** when all requested colours must be linked together. White sockets count as white, rather than substitutes for other colours. These conditions work in action odds, fossil comparisons, saved recipes, repeated-action stop conditions and MCP requests (`socketColours`, `linkedColours`).

Roll percentage means the position within a modifier's native range. For several sampled values, every value must meet the threshold. An unfinished unveil never counts as a completed target.

## Simulate a recipe

Set trials and the action budget. **Simulate action** repeats the action until its conditions match or the budget ends. **Keep actions as recipe** retains the emulator sequence. **Recipe routes** edits attempts and success/failure destinations, including bounded loops. **Simulate saved recipe** uses its captured initial state.

**Flow graph** displays the recipe as currency cards. Drag a success (**S**) or failure (**F**) port onto a step or Finish. Undo/Redo restores route edits; **Edit selected step** opens its detailed conditions. Keep the recipe in its editor to persist changes.

Jobs run in the background. **Cancel crafting job** stops them. Results include success frequency, a 95% Wilson sampling interval, currency uses, failed transitions and missing prices. **Results / distribution** shows action counts, spending percentiles, route visits and final modifier frequencies. Up to ten successful items are retained for a separate build preview. Successful-trial percentiles exclude failures; all-trial spending includes them. Trials stopped by the budget are reported separately.

**Simulate → Resource prices** lists the currencies needed by the selected action and saved recipe. Enter prices per unit, add a source and quote date, or copy quotes from another project. Saved quotes also work through MCP. Zero means free; blank means unknown. Changing the common unit clears action overrides and the starting-item cost rather than converting them.

Verified bench recipes use their actual ingredients. Unmatched services keep a whole-action price. **Action override** replaces the total for the selected action only; other recipe steps retain their resource quotes. The result says when an override was unused. **Base cost** adds the starting-item cost to every trial. Spending divided by observed successes is a model estimate, not a guaranteed game cost. Zero observed successes does not establish impossibility.

Results list modeled ingredients and service uses separately from spending, with
totals and averages across all trials. A total-price override changes spending,
not the number of currencies, fossils or Sulphur used. Rejected transitions use
no resources; executed crafts still count when their outcome fails or destroys
the item. Starting-item costs remain separate. Open **Results / distribution →
Resources used** to browse currencies with artwork, search by name and inspect
each quantity. A **Service** entry means the model has no verified ingredient
breakdown for that action.

MCP simulation results expose the same list in `resourceUsage`, with `key`,
`name`, `kind`, `amount` and `meanPerTrial`. The older `currencySpent` field
retains its costing buckets for compatibility.

Crafted-mod removal uses one Orb of Scouring. The supported one-mod and three-mod bench reforges use eight and three Chaos Orbs respectively, following the pinned recipe data. Their normal item prerequisites still apply.

**Explore charts** shows cumulative success by actions or supplied spending, and distributions of completed-trial actions/spending. Hover to inspect, click to pin, or copy the data as CSV. **Compare recipes → Compare charts** overlays captured routes. Failed and capped trials stay in the denominator; unpriced routes are omitted from spending charts.

**Run more trials** repeats that result's captured recipe, starting item, targets,
seed and quotes. Only the trial count increases. Later edits to the working item,
action or form do not change this refinement. Start a new simulation to use those
edits. The Simulate tab names the selected action; **Simulate saved recipe** uses
the saved steps and original starting item. Calculation buttons pause while a job
is running. **Close** or **Back to projects** cancels a job started in that workbench.

Calculations and results survive window resizing, text-size changes and navigation
between planning tabs. Background fossil comparisons stay available through
**Fossil results** without opening a popup over another tool. Opening another build
clears these temporary results and cancels work from the previous build.

**Calculate action odds** enumerates supported finite outcomes, including next-affix draws, Talisman fractures and Allflame selection. Item properties, partial group counts, other supported actions and roll thresholds use bounded sampling with a confidence interval. Results state which method was used.

## Compare fossil subsets

To compare fossils, select **Fossil resonator**, open **Settings → Configure fossil combination**, and choose up to four different fossils. Reopening the form retains your selection; a Tangled outcome must be supplied explicitly after it is revealed.

Then open **Simulate → Compare fossil subsets**. The comparison shows fossil artwork, success intervals, cost per trial and cost per observed success. Sort by cost or chance, select a row to inspect it, or copy the comparison as CSV. **Use selected fossils** configures the workbench without crafting the item or spending currency. **Fossil results** reopens the captured comparison; rerun it after changing inputs. This compares the supplied candidates, not every possible crafting method.

## Keep a project

Use **Keep working craft** to checkpoint the working item, undo history, targets, seed and settings, then save the build. Reopening that project resumes the checkpoint. Experiments do not spend your recorded resources; use [Journey](journey.md) to track actual holdings, spending and gear reservations.

**Keep item** stores a named snapshot in the build's **Item inventory**. Browse item cards, rename/remove snapshots, undo a removal, compare with the working item, or resume a snapshot as a separate working craft. Full simulated states survive, including fractures, imprints and pending unveils. Inventory travels with saved builds and planning bundles and has no item-count cap; the existing metadata size guard still applies. Use normal **Save** to persist changes.

Keeping a recipe marks the build unsaved. Use normal build **Save** to persist it. There is no project-count limit: keep plans for every gear slot and alternatives for each piece. Crafting metadata retains a 2 MiB total size limit and per-field validation. Projects and recipes live in AI Edition XML; other editions may discard them on re-save. AI Edition preserves unreadable or newer metadata unchanged.

On a project's **Item** tab, **Remove project** removes the guide and its saved
inventory. **Undo removal** restores the last removed guide, its order and working
draft during the current session. Linked gear goals remain listed; choose another
guide for those goals. Save the build to persist a removal or restoration.

Working-draft status is tracked per guide. Keeping one guide does not hide another
guide's unfinished work, and opening another build starts with fresh save status.
AI clients can propose `remove_crafting_project` through `propose_build`; native
review identifies the removed guide, inventory count and remaining gear links.

**Preview in build** calculates a separate candidate. Review controls application, and the existing undo flow restores the build. Simulation and planning never spend game currency.

## Compare recipes

The desktop **Simulate → Compare recipes** view compares up to three supported routes with the same captured item, final targets, seed, trial count and action budget. Saved resource quotes apply to every route. Action overrides apply to single-action routes; a saved recipe needs prices for every executed ingredient to report a cost. Results include success intervals, mean actions, spending when known, and failed transitions. **Cancel comparison** stops the job. Invalid action prices keep the comparison form open. Property-only goals work without a modifier-target group. These are bounded model experiments, not guaranteed game costs.

**Rules** opens a browser searchable by mechanic, with assumptions alongside implemented actions. Advanced actions still validate item-specific prerequisites when applied.

## Use AI through MCP

Enable the desktop connection and reconnect the client after updating.

For `simulate_crafting`, a structured starting state belongs in `recipe.initialState`.
`options.priceBook` supplies saved quotes; `options.prices` overrides shared
resource prices. Use `options.actionPrices` for action totals, for example
`{"alchemy":7}`. Inspection and fossil results expose `priceKey`; simulations
list `stepPriceKeys`. Use those keys rather than constructing them yourself.
The result reports how many action overrides were actually used. These
fields also work in fossil optimization, whose initial state is in
`options.initialState`.


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

`inspect_crafting_item` keeps the full queried bench and Essence catalogues and adds `available` and `unavailableReason` for the supplied state. `harvestOptions` gives current reforge, augment and resistance-swap choices. Pass the returned state when inspecting the next step. An unavailable choice may still be useful later in a recipe after an earlier step changes the item.

Poll `get_proposal_status` for results. Requests allow at most 2,000 trials, 2,000 actions per trial and 20,000 budgeted actions overall. Results include seeds, versions and limitations. Simulation options accept `baseCost` and `retainSuccesses` (0-100); retained successes are the first successful trials. MCP never automatically equips an outcome or saves the build.

## External cross-check

Craft of Exile remains an optional independent check. Its [documented import links](https://beta.craftofexile.com/developers?game=poe1) accept advanced game-copy text; it provides no public crafting API. Other handoffs are labeled **base-only**. Verify the imported item and patch. External exports remain opaque data; supplied external results stay separately labeled from native calculations.

The project library separates **Item**, **Plan**, and **Sharing & tools**. The workbench stays in the planning workspace; **Back to projects** preserves the current item and undo history for this session. Currency icons dim when incompatible with the item, and the action hint explains why.

Changing targets, simulation settings or craft options marks a **Working draft**.
Use **Keep working craft**, then build **Save**, to retain those changes after a
restart. Opening a saved craft, browsing its tabs or cancelling an options dialog
does not mark it as edited. **Keep resource prices** saves its quotes directly;
other unfinished work still needs **Keep working craft**.

Base artwork is bundled from the same pinned game-data export as crafting. Missing artwork uses PoB's equipment silhouette. The workbench works offline; `python tools/update_crafting_art.py` refreshes the asset manifest when the crafting data is updated.
