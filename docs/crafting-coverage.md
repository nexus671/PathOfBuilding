<!-- cspell:ignore Siveran -->
# Crafting coverage and rules

The independent engine targets current PoE 1 using PoB modifiers and an immutable [RePoE export](https://github.com/repoe-fork/repoe-fork.github.io/tree/ae6d85a5c36857e08819852ab8732239294aba59), version **3.29.3.6**. It does not yet provide complete Craft of Exile parity.

| Area | Included | Limits |
| --- | --- | --- |
| Core | Ordinary currencies, bench IDs, multiple crafted modifiers, crafted-mod removal, essences, one/three-mod bench rerolls | Resolvable non-unique items. Essences/resonators reject meta modifiers. |
| Fossils | Combinations, tag weights, special added/forced mods, lucky rolls, fractures, corrupted implicits | Tangled needs a revealed outcome; Sanctified uses empirical level bias. |
| Harvest | Tagged reforge, augment/remove, elemental resistance swaps | Supported current tags; arbitrary legacy crafts excluded. |
| Influence | Six slams, Awakener, Dominance | Known native higher tiers and compatible bases. |
| Veiled | Remove/add veil, offered choices, preferred choices in recipes | Pending choices are unfinished items. |
| Bestiary | Level 20/30 Aspects, affix conversion, imprint/restore, random metamod, influenced augmentation | Unique services remain unsupported. |
| Eldritch | Ember/Ichor, Conflict through tier 6, dominant-side currencies | Ambiguous imported tiers require structured input. |
| Properties | Blessed, Sacred, quality, catalysts, tainted quality/catalysts | Some multi-stat precision remains approximate. |
| Sockets | Bench count/links, Binding, Chromatics, non-white bench, tainted socket currencies | Ordinary random Jeweller/Fusing and Abyssal socket interactions are incomplete. |
| Corruption | Equipment Vaal and Locus branches, paired implicits, terminal destruction, tainted Exalted/Chaos | Brick socket/link rerolls, jewels/flasks and unique transformations are incomplete. Locus excludes special transformation bases, fractures, synthesis and meta modifiers. |
| Memory | Remembrance observations, tier filtering, consumption, Unravelling, Foulborn Augmentation/Regal/Exalted | Empirical models. Some consumption ceilings and behavior without strands are inferred. Counts are retained in structured state. |
| Recombination | Either base, item level, count tables, conflicts, exclusivity, fracture host, base eligibility, continued crafting | Experimental unpredictable model. Exclusive-only side ordering is rejected; hidden weights, some exclusive families and predictable mode are unresolved. |
| Ducats | Cyaxan, Genteel, Brinehook, Merrick | Individual actions only. Allflame selection, ghost forms, Intangibility and remaining Ducats are incomplete. |
| Planning | Rich targets, bounded routes/loops, background jobs, cancellation, prices, percentiles, distributions, next-affix enumeration, fossil comparison | No globally cheapest policy guarantee. |

## Assumptions

- Rare affix counts use 4/5/6 with weights 8/3/1; magic counts use one/two equally. Eldritch Chaos uses two/three on the affected side equally.
- Raw single-stat precision is used when it maps unambiguously to one displayed range. Other ranges use inclusive displayed integers or illustrative fractional rolls. Hidden stat correlations may be missing.
- [Craft of Exile's metamod reference](https://www.craftofexile.com/metamods) informs action-specific protection. Undocumented game changes can lag detection.
- Conflict uses the [empirical tier-difference model](https://www.reddit.com/r/pathofexile/comments/13y05ag/orb_of_conflict_rates_50_11n_to_upgrade_per_n/).
- Recombination uses [community count measurements](https://github.com/Maliffic/Resimbulator/blob/master/docs/guide.txt), normalizing rounded rows. Eligible entries are chosen uniformly; hidden weights remain uncertain.
- [3.26 follow-up measurements](https://www.reddit.com/r/pathofexile/comments/1ldc3lz/326_recomb_psas_a_few_useful_tipsconfirmations/) supersede the old exclusive-mod filler behavior. Exclusive entries contribute at most one count per side; unresolved exclusive-only ordering is rejected.
- Memory mechanics use the [3.29 measurements and published data](https://www.reddit.com/r/pathofexile/comments/1wr9445/329_everything_you_need_to_know_about_memory/) and [subsequent statistical analysis](https://github.com/Rasslabsya4el/crafting-system/blob/main/docs/research/2026-11-01-strand-sheet-fit.md). Retained tiers are weighted by total/retained tier count. Remembrance samples the 2,255 recorded outcomes rather than assuming a uniform distribution. The shifted Exalted consumption table and Foulborn behavior without strands remain estimates.
- Socket colours use [Siveran CC0 formulas](https://github.com/Siveran/siveran.github.io/blob/master/src/Main.ts). Tainted branches assume equal positive/negative chances. Added sockets follow the white-socket rule in [3.29 notes](https://www.pathofexile.com/forum/view-thread/3985332).
- Wilson intervals measure sampling uncertainty, not uncertainty in rules or data.

## Patch maintenance

`python tools/update_crafting_data.py` rebuilds supplemental data from the pinned commit and records source hashes. Updating the patch requires checking modifier identities, mechanics and regression fixtures together.

[Announced 3.30 changes](https://www.pathofexile.com/forum/view-thread/4013680), including partial affix locks and Annulment interactions, remain separate until released data and behavior are verified. Historical Necropolis and Crucible crafting are outside this work's scope.
