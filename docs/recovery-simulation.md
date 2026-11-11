# Recovery simulation coverage

Enable **Simulate recovery between hits** in Configuration. Enemy damage,
category and attack/cast time define the scenario. Trials start at full configured
recoverable pools with the configured initial protection and Ghost Shrouds.

Evasion uses entropy; dodge, block, suppression and damage avoidance use a local
seeded random generator. Average selects each attack/spell category equally.
The EHP unlucky setting is excluded. Default 32 reproducible trials, configurable
from 1 to 128. Calcs shows survival frequency and capped 10th/50th/90th percentiles
of time alive. Reaching the window is not proof of infinite survival. Small samples
are approximate, especially for rare bursts. Detailed trials are omitted from
item-preview calculations to keep ordinary comparisons fast.

Enable **Simulate main-skill attacks** to pay native configured costs on outgoing
attempts. Unaffordable attempts are skipped; Calcs shows their affordable fraction.
Successful hits apply native average instant leech/gain on hit and create leech
instances. Each instance expires separately. Combined rates obey native caps;
ordinary instances clear at full unreserved life/mana/ES unless retention is
allowed. A Petrified Blood recovery cap below full unreserved life therefore
allows instances to remain. Eldritch Battery pays mana costs from ES first.
**Hit/Poison DPS** integrates native average hit damage and expected
poisons from landed, paid attacks. Skipped attempts add neither. Every poison
snapshots the native profile at application, retains its own expiry, and obeys
native stack limits and the shared DoT cap. Existing poisons continue through
attack gaps and after death until expiry or the scenario window ends. Damage is
divided by the full window, not only the time alive. Other ailments, impales,
secondary skills, minions and culling-equivalent DPS are excluded. Poison chance
and additional applications use native expected amounts per landed hit rather
than individual poison rolls. Other conditional damage, Wither and configured
poison-on-enemy modifiers remain fixed. This does not replace native Full DPS.

**Track temporary defense uptime** is on by default. Selected utility and
enduring recovery flasks start full and reuse at expiry. Known passive generation,
local charges when hit and critical-charge sources are included. Incoming hit gain
has a 100ms interval per flask; critical gain has a shared 100ms interval and one
recipient. A random eligible equipped flask is chosen and its local plus global
chance is rolled. Full/unchecked equipped flasks participate in charge distribution;
only available flasks are used. Random charge non-consumption is rolled separately.
No kill charges are invented, and cooldown recovery does not shorten these intervals.
Native defenses/recovery are recalculated when the active flask set changes,
using isolated projection caches without editing the build. Elusive avoidance
decays from its configured initial effect; Nightblade can reapply it on outgoing
critical hits after it expires. Other sources of Elusive generation and changes
to damage/critical modifiers while Elusive are not simulated.

Recovery flasks that end at full trigger below **Recovery flask trigger (%)** of
the recoverable pool (default 50%), with **Recovery flask reaction (ms)** (default
100ms). Threshold observation is at most 50ms apart. A lethal hit cannot be rescued.
Instant recovery and conditional instant recovery on low life are evaluated on use;
gradual recovery ends at full unless enduring. Life flasks may heal above Petrified
Blood's non-flask cap, to full unreserved life. Ordinary recovery does not erase
that extra life or continue healing above its own cap. Hybrid flask effects end
at full only when both source pools are full. Recovery copied to ES ends with its
source flask. Blood of the Karui recovers missing Life on natural effect expiry;
early termination at full cancels that recovery. Life-flask ES copying receives
the same missing-Life recovery, capped by available ES. Global and local charge
cost modifiers are combined before integer rounding, including the boundary
reported in [#7578](https://github.com/PathOfBuildingCommunity/PathOfBuilding/issues/7578).
Charges start full. **Include equipped recovery flasks** also
makes unchecked life/mana flasks available, without editing their item checkboxes.
Selected enduring flasks retain the start-at-zero/reuse-at-expiry policy.

The five **Continuous [type] damage/s** inputs add raw continuous damage before
native damage taken as and mitigation, alongside incoming hits. Existing build
degeneration is included. The enemy **Damage over Time** category also supports
DoT-only trials, using its existing damage inputs. These are continuously active
scenario sources; expected enemy bleed/ignite/poison from hits are not silently
treated as permanent ailments. Damage follows current ES/bypass, Eldritch Battery
and typed/shared Mind over Matter, including pool depletion and regeneration at an
empty pool. It interrupts ordinary recharge and continuously reserves Dissolution
life; it does not trigger recoup, Ghost Dance, Crab losses or other on-hit effects.
Intrinsic resource loss such as Mana Burn remains resource loss, not damage.

## Inspecting and comparing encounters

- **Timeline** in Calcs opens a native interactive chart and chronological
  event table for **Timeline trial** (default 1). It shows Life/ES/Mana, total and
  per-slot flask charges, Crab Barriers, Ghost Shrouds and active expected poison
  DPS. Chart legends give each series' reference maximum; values are normalized
  separately. The table includes reservation, incoming outcomes, failed costs,
  flask uses and recharge events. Up to 1,000 events plus the terminal outcome are
  retained; regularly sampled chart points are retained even if events are omitted.
  This is one trial, not an average or automatically selected representative path.
- **Deaths** groups terminal events and lists the first affected trial.
  Continuous deaths distinguish damage, delayed Life loss, configured resource loss
  and Dissolution reservation. Inspect the timeline for the preceding resource
  and flask state. A terminal label identifies contributing losses, not a complete
  causal proof that removing one source would prevent death.
- **Config Checks** distinguishes review items, dynamic mechanics and fixed
  assumptions. It flags stale Mana Burn with no active tincture, unavailable
  equipped recovery flasks, contradictory full/low inputs and assumed full-ES
  conditional damage. It never changes saved inputs automatically.
- **Scenarios...** beside the Config-set manager creates a named, saved config set
  from the current set: single heavy hit (twice current raw damage, one attempt),
  rapid spells (250ms), mixed pressure (700ms), or sustained DoT. Existing build
  buffs and raw damage proportions are copied; additional mixed-DoT fields are
  cleared. These are test scenarios, not models or ratings for named bosses.
  Existing Config-set management handles renaming, duplication and saving custom
  scenarios. **Only one incoming hit** can also be set manually.
- **Compare with config set** runs B in an isolated projection, keeping A selected.
  Both use A's window, trial count and **Trial seed**. Gear/tree/skills stay the same;
  B retains its other saved settings. Incoming rolls are indexed by attempt and
  outcome, separate from outgoing/flask/Crab streams. Counter seeds are mixed before
  initializing the RNG to avoid correlations from neighboring seeds. A paired
  table shows B-minus-A survival, capped time alive and hit-plus-poison DPS with
  approximate 95% intervals based on within-pair differences. Results do not rank
  upgrades automatically.
- Survival includes a **95% Wilson interval**. Zero deaths out of 128 trials still
  leaves uncertainty; 100% observed survival has a lower bound around 97.1%.
  Paired mean intervals can be unreliable for small samples and rare events;
  inspect both arms' Wilson intervals and repeat with other seed families. This
  quantifies sampling uncertainty, not errors in configured assumptions or mechanics.

| Mechanic | Treatment |
| --- | --- |
| Regeneration, configured resource loss | Native rates between events with recovery caps. |
| Recoup | Per-hit cohorts with native duration and modifiers. |
| ES recharge | Full/partial recovery in real gaps; damage to ES or its protected resource interrupts it. Costs do not interrupt it. |
| Wicked Ward | Protects recharge for four seconds from its start, not four seconds from every hit. |
| Eternal Youth | Recharge applies to actual life. It does not clear Dissolution reservation. |
| Ghost Dance | Three finite charges, two-second generation, eligible unblocked-hit consumption and capped ES recovery after nonlethal damage. |
| Divine Shield / physical-prevention regeneration | Per-hit cohorts, native modifiers, recovery restrictions and copying such as Pious Path. Shifted damage is not physical prevention. |
| Petrified Blood / Progenesis | Separate delayed-loss cohorts; death can occur between hits. Non-flask life recovery obeys Petrified Blood's cap. |
| Dissolution | Separate actual-life and reservation state. Two seconds without damage to life releases reservation; healing only restores actual life. PB/Progenesis delayed loss, recoup, life costs and Eternal Youth operate on actual life. Damage-induced clamping of actual life can interrupt recharge. |
| Block/suppression gains, Defiance | Apply to actual corresponding outcomes, with no recovery after lethal damage. |
| Emperor's Vigilance | Routing changes on the actual blocked hit. |
| Ward | Ordinary timed restoration after a break. Partial chance not to break is explicitly unsupported. |
| Aegis | Native skill recharge delays, separate pool timers; depleted pools can refill. |
| Guard | Native duration, early depletion and cooldown. Optional **Recast guard when ready** pays native costs. This is a manual-use policy, not trigger-threshold simulation. Vaal guards are not automatically reused. |
| Crab Barriers | Start at the configured count, gain one every 0.5s with a fixed phase from combat start, lose stacks on physical hit damage. Craiceann's Tracks/Chitin/Pincers loss limits, four-second protection and gain-to-maximum chance are parsed and simulated. Native reduction and threshold block bonuses are recalculated for each state. |
| Recovery flasks | Finite charges, activation/reaction policy, dynamic low-life instant recovery, gradual/end recovery, source/full-pool termination, enduring recovery and PB's flask exception. Mean total flask uses and Crab Barriers lost are shown in Calcs. |
| Allied protection | Configured initial pools; no resummoning schedule. |

## Explicit limits

- Dissolution with existing life reservations needs aura-cancellation ordering and
  buff changes, and is unsupported. Upstream reports [#10193](https://github.com/PathOfBuildingCommunity/PathOfBuilding/issues/10193)
  and [#10258](https://github.com/PathOfBuildingCommunity/PathOfBuilding/issues/10258)
  are not claimed fixed.
- The additional ten-second Life recovery modifier is explicitly unsupported;
  it is distinct from Blood of the Karui's supported effect-end recovery. Kill,
  corpse-consumption and Avenger's incoming-critical charge sources, flask queues
  and special Ward/flask interactions are not simulated. Passive generation uses
  native configured rates, including fixed conditional modifiers.
- Other conditional damage-taken modifiers remain configured, including Lethe
  Shade and conditional Ward DoT reduction. Enemy ailment application/expiry is
  not simulated; use explicit continuous inputs to test sustained damage.
- Immortal Ambition's conditional leech redirection and enemy impale stacks are
  explicitly unsupported.
- Other configured conditional buffs remain fixed, including recently-hit effects,
  full-ES damage bonuses and variable enemy critical damage. No movement, multiple
  attackers, kills or complete skill rotation is simulated.
- Elusive generation phase, flask state, leech and skill-cost timing are scenario
  assumptions; survival frequency is an estimate, not a guarantee or boss rating.

## Next improvements

1. Life-aura cancellation for Dissolution and enemy ailment application/expiry.
2. Additional ten-second flask recovery, other charge sources, queues and special
   Ward/flask interactions.
3. Conditional leech transformations and dynamic damage/critical modifiers.
4. Multiple attackers, variable hit sizes, changing recently-hit/full-ES conditions,
   and resummoning/recasting other protective skills.
5. Broader seed-family convergence and rare-event checks before any automatic
   survival-based ranking. Current confidence intervals cover sampling only.

## Mechanics references

- [GGG: evasion entropy](https://www.pathofexile.com/forum/view-thread/11707/filter-account-type/staff/page/10#p748465)
- [Ghost Dance](https://poedb.tw/us/Ghost_Dance)
- [Divine Shield](https://poedb.tw/us/Divine_Shield)
- [Dissolution](https://poedb.tw/us/Dissolution_of_the_Flesh)
- [Eternal Youth](https://poedb.tw/us/Eternal_Youth)
- [Wicked Ward](https://poedb.tw/us/Wicked_Ward)
- [Molten Shell](https://poedb.tw/us/Molten_Shell)
- [Primal Aegis](https://poedb.tw/us/Primal_Aegis)
- [Aspect of the Crab](https://poedb.tw/us/Aspect_of_the_Crab)
- [Craiceann's Tracks](https://poedb.tw/us/Craiceanns_Tracks)
- [Craiceann's Chitin](https://poedb.tw/us/Craiceanns_Chitin)
- [Craiceann's Pincers](https://poedb.tw/us/Craiceanns_Pincers)
- [Flask data and mechanics](https://poedb.tw/us/Flasks)
- [Blood of the Karui](https://poedb.tw/us/Blood_of_the_Karui)
- [GGG: prevented physical damage](https://old.reddit.com/r/pathofexile/comments/qd4crg/finally_i_can_now_take_105_of_damage_from_blocked/hhktpsc/)
