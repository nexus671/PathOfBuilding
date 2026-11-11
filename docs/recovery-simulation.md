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
Configured average hit damage and critical chance remain fixed: these trials do
not recalculate DPS, conditional damage, Wither or poison stacks from attack uptime.

**Track temporary defense uptime** is on by default. Selected utility and
enduring recovery flasks start full and reuse at expiry. Only known passive charge
generation is included; no kill, hit or critical-strike charges are invented.
Native defenses/recovery are recalculated when the active flask set changes,
using isolated projection caches without editing the build. Elusive avoidance
decays from its configured initial effect; Nightblade can reapply it on outgoing
critical hits after it expires. Other sources of Elusive generation and changes
to damage/critical modifiers while Elusive are not simulated.

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
| Allied protection | Configured initial pools; no resummoning schedule. |

## Explicit limits

- Dissolution with existing life reservations needs aura-cancellation ordering and
  buff changes, and is unsupported. Upstream reports [#10193](https://github.com/PathOfBuildingCommunity/PathOfBuilding/issues/10193)
  and [#10258](https://github.com/PathOfBuildingCommunity/PathOfBuilding/issues/10258)
  are not claimed fixed.
- Dynamic damage-over-time routing through ES/Dissolution is unsupported. Known
  continuous degen on the protected resource disables ordinary recharge.
- Instant recovery flasks and recovery flasks that end at full need activation,
  termination and recovery-cap policies and are explicitly unsupported when selected.
- Immortal Ambition's conditional leech redirection and enemy impale stacks are
  explicitly unsupported.
- Other configured conditional buffs remain fixed, including recently-hit effects,
  full-ES damage bonuses and variable enemy critical damage. No movement, multiple
  attackers, kills or complete skill rotation is simulated.
- Elusive generation phase, flask state, leech and skill-cost timing are scenario
  assumptions; survival frequency is an estimate, not a guarantee or boss rating.

## Next improvements

1. Life-aura cancellation and dynamic degen routing for Dissolution.
2. Instant/ending recovery flasks, charge-on-hit/critical generation and explicit
   activation policies; special Ward/flask interactions.
3. Conditional leech transformations and dynamic damage/critical modifiers.
4. Multiple attackers, variable hit sizes, changing recently-hit/full-ES conditions,
   and resummoning/recasting other protective skills.
5. Sampling uncertainty/convergence checks before automatic survival-based ranking.

## Mechanics references

- [GGG: evasion entropy](https://www.pathofexile.com/forum/view-thread/11707/filter-account-type/staff/page/10#p748465)
- [Ghost Dance](https://poedb.tw/us/Ghost_Dance)
- [Divine Shield](https://poedb.tw/us/Divine_Shield)
- [Dissolution](https://poedb.tw/us/Dissolution_of_the_Flesh)
- [Eternal Youth](https://poedb.tw/us/Eternal_Youth)
- [Wicked Ward](https://poedb.tw/us/Wicked_Ward)
- [Molten Shell](https://poedb.tw/us/Molten_Shell)
- [Primal Aegis](https://poedb.tw/us/Primal_Aegis)
- [GGG: prevented physical damage](https://old.reddit.com/r/pathofexile/comments/qd4crg/finally_i_can_now_take_105_of_damage_from_blocked/hhktpsc/)
