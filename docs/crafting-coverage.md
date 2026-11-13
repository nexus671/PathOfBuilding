<!-- cspell:ignore Siveran Katakohi Ukatoa -->
# Crafting coverage and rules

The independent engine uses PoB modifiers and an immutable [RePoE export](https://github.com/repoe-fork/repoe-fork.github.io/tree/ae6d85a5c36857e08819852ab8732239294aba59), version **3.29.3.6**. The white-socket bench craft, standard Orb of Annulment and full prefix/suffix lock costs use the announced 3.30 rules. Other 3.30 crafting changes and modifier data are not yet incorporated; it does not yet provide complete Craft of Exile parity.

| Area | Included | Limits |
| --- | --- | --- |
| Core | Ordinary currencies, bench IDs, multiple crafted modifiers, crafted-mod removal, essences, one/three-mod bench rerolls | Resolvable non-unique items. Essences/resonators reject meta modifiers. |
| Import | Known native identities and uniquely resolvable plain copies, including multi-line flasks, tinctures and cluster tags | Explicit item level required. Ambiguous identities and values that cannot be reconstructed are rejected; no hidden tier or roll is guessed. |
| Fossils | Combinations, tag weights, special added/forced mods, lucky rolls, fractures, corrupted implicits | Tangled needs a revealed outcome; Sanctified uses empirical level bias. |
| Harvest | Tagged reforge, augment/remove, elemental resistance swaps, 14 quality enchantments with client-derived eligibility and costs | Supported current tags; arbitrary legacy crafts excluded. |
| Influence | Six slams, Awakener, Dominance | Known native higher tiers and compatible bases. |
| Veiled | Remove/add veil, offered choices, preferred choices in recipes | Pending choices are unfinished items. |
| Bestiary | Level 20/30 Aspects, affix conversion, imprint/restore, random metamod, influenced augmentation, one/two-mod Talisman fractures | Talisman fractures sample distinct modifiers uniformly. Unique services remain unsupported. |
| Eldritch | Ember/Ichor, Conflict through tier 6, dominant-side currencies | Ambiguous imported tiers require structured input. |
| Properties | Blessed, Sacred, quality, catalysts, tainted quality/catalysts | Some multi-stat precision remains approximate. |
| Sockets | Bench count/links, 3.30 white-socket bench, Omens of Connections and Trichromatism, Binding, Chromatics, non-white bench, tainted socket currencies | Ordinary random Jeweller/Fusing and Abyssal socket crafting are incomplete. Link targets do not count Abyss sockets, and unsupported socket crafts are disabled. |
| Corruption | Equipment Vaal and Locus branches, paired implicits, terminal destruction, tainted Exalted/Chaos | Brick socket/link rerolls, jewels/flasks and unique transformations are incomplete. Locus excludes special transformation bases, fractures, synthesis and meta modifiers. |
| Memory | Remembrance observations, tier filtering, consumption, Unravelling, Foulborn Augmentation/Regal/Exalted | Empirical models. Some consumption ceilings and behavior without strands are inferred. Counts are retained in structured state. |
| Recombination | Either base, item level, count tables, conflicts, exclusivity, fracture host, base eligibility, continued crafting; predictable selections calibrated to an observed success percentage | Experimental models. Exclusive-only side ordering is rejected. Hidden weights, some exclusive families and automatic predictable odds remain unresolved. |
| Ducats | Cyaxan, Genteel, Brinehook, Merrick, Rotmother, Kishara, Tzamoto | Katakohi and Ukatoa remain incomplete. Tzamoto uses an assumed 50/50 reset/destruction branch. Rotmother's native pool is generated from the pinned game export; some new modifier effects still have native calculation warnings. |
| Allflame | Historical 3.29 client-derived profiles, ship upgrades, class/level-scaled Sulphur costs, independent ghost previews, Intangibility collapse, preferred-target selection, conditional finite-outcome calculation | Not core in 3.30. Gain intervals are sampled uniformly; collapse and selection remain model assumptions. An observed override is available. Existing imprints are consumed. |
| Planning | Rich targets including native weapon/defence minimums, linked socket-colour counts and specific fractures/crafted flags, manual starting-item edits, bounded routes/loops, background jobs, cancellation, starting-item costs, percentiles, final-affix/property distributions, retained successes, finite-outcome enumeration with cancellable sampled fallback, fossil comparison | No globally cheapest policy guarantee. |

## Saved resource prices

Each gear project can store a price book with a common unit, source, quote time
and resource values. The native **Resource prices** editor uses bundled currency
art and can copy quotes from another gear project. It does not fetch live prices
or convert currencies. Clear quotes before changing their unit. Changing the
unit also clears action overrides and the starting-item cost.

Simulations, recipe comparisons and fossil optimization share these quotes,
including through MCP's `priceBook` option. Explicit `prices` entries override
the corresponding shared resource. `actionPrices` instead prices only its
matching action key; it does not change another step's ingredient quotes. Zero is free and missing is unknown. Bench services and other actions
without verified ingredient quantities remain whole-action quotes. Quote dates
are preserved when editing or copying unless explicitly changed.

Bench ingredient quantities come from the pinned export. Native effects match
by complete displayed ranges, tier, affix type and item class, including Rune
Daggers and Warstaves. Conflicting costs and unmatched effects remain unknown;
row numbers alone never identify a service. An explicit whole-action override
still takes precedence. MCP inspection includes ingredients, source modifier
IDs and whether a verified ingredient cost is available.

Crafted-mod removal and the supported one/three-modifier bench reforges use
client-exported service costs by command, parameter and item class. Inspection
exposes these quantities under `benchServiceCosts`. A total action-price
override retains precedence. Results and CSV exports identify supplied resource
overrides and applied action overrides separately.

Fossil comparison shows captured quotes, chance intervals and costs with real
currency artwork. Fully priced subsets with observed successes rank first by
cost per success; remaining subsets rank by sampled chance. Other sort modes
and CSV export are available. Selecting a subset only configures the workbench.

## Assumptions

- Rare affix counts use 4/5/6 with weights 8/3/1; magic counts use one/two equally. Eldritch Chaos uses two/three on the affected side equally.
- Independent vectors advance across modifier lines; scalar and legacy singleton rolls apply uniformly. Raw single-stat precision is used when it maps unambiguously to one displayed range. Other ranges use inclusive displayed integers or illustrative fractional rolls. Hidden stat correlations may be missing.
- [Craft of Exile's metamod reference](https://www.craftofexile.com/metamods) informs action-specific protection. Undocumented game changes can lag detection.
- Conflict uses the [empirical tier-difference model](https://www.reddit.com/r/pathofexile/comments/13y05ag/orb_of_conflict_rates_50_11n_to_upgrade_per_n/).
- Recombination uses [community count measurements](https://github.com/Maliffic/Resimbulator/blob/master/docs/guide.txt), normalizing rounded rows. Eligible entries are chosen uniformly; hidden weights remain uncertain.
- [3.26 follow-up measurements](https://www.reddit.com/r/pathofexile/comments/1ldc3lz/326_recomb_psas_a_few_useful_tipsconfirmations/) supersede the old exclusive-mod filler behavior. Exclusive entries contribute at most one count per side; unresolved exclusive-only ordering is rejected.
- Predictable mode requires the in-game percentage for the exact inputs and selections. It fits a shared class constant using the community transfer formula, tier-cumulative pool weights and per-base caps. This supports conditional recipe simulation; it is not an independent prediction of the displayed percentage. Base shares remain model-dependent. The [original formula research](https://www.reddit.com/r/PathOfExile2/comments/1jzu2py/poe_2_patch_020_guide_to_recombinators_part_1/) began in PoE 2; PoE 2 class constants are not substituted into PoE 1.
- Memory mechanics use the [3.29 measurements and published data](https://www.reddit.com/r/pathofexile/comments/1wr9445/329_everything_you_need_to_know_about_memory/) and [subsequent statistical analysis](https://github.com/Rasslabsya4el/crafting-system/blob/main/docs/research/2026-11-01-strand-sheet-fit.md). Retained tiers are weighted by total/retained tier count. Remembrance samples the 2,255 recorded outcomes rather than assuming a uniform distribution. The shifted Exalted consumption table and Foulborn behavior without strands remain estimates.
- Allflame follows [GGG's explanation of Intangibility](https://outputlag.com/feature/diving-deep-into-path-of-exile-curse-of-the-allflame-with-grinding-gear-games/): the whole craft can fail to create additional outcomes, and successful multiple-outcome crafts build Intangibility. Automatic profiles come from the [3.29.3c client-table export](https://github.com/LocalExile/LocalExile/tree/9a435a565d5b2e180714724e38e0161d0c39842a/sql). The catalog contains 293 upgrade rows for 160 currencies and 45 eligible classes. Cost scaling combines the currency base cost, class multiplier and item-level adjustment, rounding upward; this interpretation still needs independent in-game verification. Gain intervals are sampled uniformly per ghost; hidden distributions remain unverified. Sulphur is charged once per craft, including collapsed crafts. Explicit fixed-index recipes fall back to the only outcome after collapse.
- Socket colours use [Siveran CC0 formulas](https://github.com/Siveran/siveran.github.io/blob/master/src/Main.ts). Tainted branches assume equal positive/negative chances. Added sockets follow the white-socket rule in [3.29 notes](https://www.pathofexile.com/forum/view-thread/3985332).
- Omen of Connections fully links existing ordinary sockets, retaining their colours and count. The action consumes one Omen and one Orb of Fusing, following the pinned client item description. Socket bench and Omen of Connections calculations return their single deterministic outcome, including item-property goals. Ordinary random Fusing/Jeweller odds remain outside current coverage.
- Omen of Trichromatism consumes one Omen and one Chromatic Orb to guarantee at least one red, green and blue socket, following the [3.29 patch notes](https://www.pathofexile.com/forum/view-thread/3985332) and pinned client description. It preserves socket count and links. Forced positions are sampled uniformly; additional socket colours use the existing model. Those placement and extra-colour probabilities are assumptions, rather than published server weights. Three-socket calculations enumerate six placements under the uniform-position assumption; larger items use labelled sampling. Other socket Omens remain outside current coverage.
- Wilson intervals measure sampling uncertainty, not uncertainty in rules or data.

- Retained successes are the first requested successful trials, capped at 100, rather than an unbiased sample of all successes. Final property histograms exclude destroyed items; affix frequencies count final states across all trials.

## Patch maintenance

`python tools/update_allflame_data.py` rebuilds the pinned client-derived Allflame catalog in memory and records source hashes. `python tools/update_crafting_data.py` rebuilds supplemental data from the pinned commit and records source hashes. Updating the patch requires checking modifier identities, mechanics and regression fixtures together.

`python tools/update_harvest_enchants.py` joins the pinned client Harvest service table to RePoE modifier text and base classes. It records every source hash and includes deterministic quality-enchantment services, rather than assuming random enchantment weights. Imported matching enchantments are recognised; replacement, recipe goals, inventory state and selected recombination hosts retain their identities. For supplied resource prices, use `wild_lifeforce`, `vivid_lifeforce` and `primal_lifeforce`.

[Announced 3.30 changes](https://www.pathofexile.com/forum/view-thread/4013680), including partial affix locks and Annulment interactions, remain separate until released data and behavior are verified. Historical Necropolis and Crucible crafting are outside this work's scope.
