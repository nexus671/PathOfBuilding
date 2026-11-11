# Recovery simulation coverage

Enable **Simulate recovery between hits** in Configuration. Enemy hit damage,
category and attack/cast time define the scenario. Trials start at full configured
recoverable pools with the configured initial protection and Ghost Shrouds.

Each trial processes individual enemy attempts. Evasion uses a shared entropy
counter, reset after an attack-free gap. Dodge, block, suppression and damage
avoidance use a local seeded random generator. Average damage category selects
each of the four attack/spell categories equally. The EHP unlucky setting is
excluded; the ordinary configured probabilities apply.

The default is 32 reproducible trials, configurable from 1 to 128. Calcs shows
the fraction surviving the window and the 10th/50th/90th percentiles of time alive.
Times are capped at the selected window: reaching it is not proof of infinite
survival. Small trial counts are approximate samples, especially for rare bursts.

| Mechanic | Current treatment |
| --- | --- |
| Regeneration and life degen | Native configured rates between events; pool caps apply. |
| Recoup | Each damaging hit adds a separate cohort with its native duration and recovery modifiers. |
| Ordinary ES recharge | Starts after the configured delay, can restore partially or fully during real gaps, and is interrupted by damage to ES or the resource ES protects. Costs do not interrupt it. Continuous degen on the protected resource disables recharge. |
| Eldritch Battery | Native routing; damage to mana/ES interrupts recharge. Damage only to life does not. |
| Ghost Dance | Up to three charges, one generated every two seconds from the start of the trial. An eligible unblocked hit consumes a charge after damage; recovery is 3% of evasion, capped by ES recovery space. No recovery after a lethal hit. Generation phase before combat is not known. |
| Divine Shield and physical-prevention regeneration | Per-hit physical damage prevented produces a regeneration cohort for the native recent duration, including prevention from block/suppression. Damage shifted to another type is not physical prevention. Native regeneration/recovery modifiers and recovery caps apply. |
| Petrified Blood / Progenesis | Native immediate pool reduction plus separate four-second delayed-loss cohorts; death can occur between hits. |
| Gain on block/suppression | Applies to the actual corresponding outcome after nonlethal damage. |
| Defiance of Destiny | Missing-life recovery before connected hits. |
| Emperor's Vigilance | ES bypass changes on the actual blocked hit. |
| Dissolution of the Flesh | Basic hit-only reservation capacity; clears after two seconds without damage to life. Life healing does not clear reservation. Delayed life loss, degen, life costs and existing life reservations are explicitly unsupported combinations. |
| Main-skill leech/on-hit and costs | Optional sustained rates. Assumes resource sustainability; leech startup, instance expiry and removal at full are not simulated. |
| Aegis, guard, allied pools, Vaal Arctic Armour | Configured initial protection; no repeated recast/refill schedule. |
| Ward, Wicked Ward, recharge applied to life, enemy impales, ES degen routing | Explicitly unsupported. |

Configured mitigation, critical damage and conditional buffs remain fixed across
trials. This is not a complete combat engine: no movement, enemy packs, variable
hit sizes, flask use, kills, temporary-buff expiry or automated skill rotation.
Existing burst EHP and poison/steady-state DPS calculations are unchanged.

## Next improvements

1. Track leech instances: creation from outgoing hits, duration, caps, removal at
   full, leech persisting at full and instant leech. Track actual outgoing gain-on-hit events and
   stop attacking when resources cannot pay costs.
2. Extend Dissolution with a separate actual-life pool, delayed life loss and
   reservation cancellation. Petrified Blood/Eternal Youth interactions must not
   be approximated as healing reservation.
3. Add recharge state for Wicked Ward, Eternal Youth and forced recharge starts.
4. Route continuous damage dynamically as ES/mana empty and refill; include
   ongoing degeneration in recharge interruption and Dissolution reservation.
5. Schedule Ward restoration, Aegis refills, guard recasts and temporary buffs.
6. Model flask duration, charges and activation policy; avoid assuming permanent
   recovery from a flask that cannot be sustained.
7. Add multiple attackers, damage/critical distributions and dynamic conditions
   such as recently hit, full ES, Wind Dancer and changing Elusive effect.
8. Expose convergence/sample uncertainty before using trial results for automatic
   item ranking. Retain the fast burst metric for routine comparisons.

## Mechanics references

- [GGG: evasion entropy and independent block/dodge](https://www.pathofexile.com/forum/view-thread/11707/filter-account-type/staff/page/10#p748465)
- [Ghost Dance game stats](https://poedb.tw/us/Ghost_Dance)
- [Divine Shield game stats](https://poedb.tw/us/Divine_Shield)
- [Dissolution game stats](https://poedb.tw/us/Dissolution_of_the_Flesh)
- [GGG: prevented physical damage](https://old.reddit.com/r/pathofexile/comments/qd4crg/finally_i_can_now_take_105_of_damage_from_blocked/hhktpsc/)
