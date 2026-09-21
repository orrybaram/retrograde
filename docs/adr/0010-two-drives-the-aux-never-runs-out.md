---
status: accepted
date: 2026-09-20
---

# Two drives; the Aux never runs out

The ship has two engines, not one throttle with a fuel gauge attached.

- **Aux** — a solar-electric ion drive that scavenges reaction mass from ambient debris dust. It has no gauge, no meter and no resource. It is always available and it always works.
- **Burn** — a chemical drive running on **mined volatiles**. Enormous thrust, drains fast, and is the only thing fuel is ever spent on.

Fuel stops being the thing that keeps the ship alive and becomes the thing that makes it *responsive*.

## The physics this is built on

Real electric propulsion is 25–250 mN of thrust at 2,000–5,000 s specific impulse; chemical is millions of newtons at 300–450 s. NASA's Dawn ran at roughly 90 mN — "the push of holding a sheet of paper." NEXT fired for over 48,000 hours across five and a half years on about 870 kg of xenon.

That last figure is why "never runs out" needs no hand-waving: an ion drive's consumption sits so far below its runtime that on any human timescale it is free. The ~10x Isp gap is also the honest reason the Burn drains a gauge and the Aux does not.

Aux power comes from panels. Retrograde's own ices supply the Burn — `docs/DESIGN.md` §2.2 already gives Veld "frozen fuel reserves," so the starting zone is where fuel comes from.

## Considered options

- **One drive, fuel keeps you alive** (the current design). Rejected: running dry is a hard stop that takes control away from the player, and it makes the fuel gauge the most anxious object on screen in a game with no combat.
- **A propellant-free drive (solar sail).** Rejected: a sail pushes away from the sun, so it would make *inward* travel hardest, fighting the shape of a game about travelling in. Attractive thematically, wrong mechanically.
- **Two drives; the Aux is free and slow, the Burn costs fuel** (chosen).

## Consequences

- **The Aux is low-thrust, not low-speed.** In a frictionless sim, reducing thrust does not cap velocity — it means slow to reach a speed and slow to shed one. The ship feels **massive**: you plan burns, you decelerate early, and coasting is still fast. `docs/DESIGN.md` §4.1 already asks for "heavy and sluggish… stopping takes planning"; this is that, with a reason.
- **The Burn is authority over momentum, not a speed boost.** Dodge the debris, stop before the station, climb out of a gravity well. So an empty tank does not strand the player — **it makes them clumsy.** They can still go anywhere; they just cannot react. Flying a heavy unresponsive ship through a debris field with no fuel is more frightening than an empty gauge ever was, and it never removes control.
- **Aux thrust is flat.** It does not vary with distance from the sun. Real arrays are sized for the worst case, so a craft built to work across the whole system sizes for the outer rim and regulates the surplus closer in. A distance gradient was considered and **rejected**: it adds a tuning value that multiplies against Aux thrust and cargo mass, and it makes the outer system — where the game opens — the most sluggish place in it.
- **The Aux still runs on sunlight, and the sun is the Core.** Every metre the player moves without fuel, they move on power drawn from the thing they are waking. That is fiction, not a mechanic, and it needs no gradient to land.
- **Fuel is time.** Mining it buys speed. Combined with ADR 0007: the ring pays for the trip, the void pays for the ship, **seams pay for speed**.
- **This closes ADR 0007's open `OreDeposit` question.** Seams are where fuel comes from — ice worlds and moons, volatiles under the crust, worked with the same Sweep as everything else. A moon landing is a fuel run.
- **The Aux must never have a meter.** The moment it has a readout, players manage it, and the entire point is that it is the thing you never think about.
- **Fuel scarcity has to be real**, or nobody ever flies on Aux and the system is decoration.
- Existing tuning to revisit: `thrust_power` 350, `boost_power_multiplier` 2.0, `boost_fuel_multiplier` 3.0, `fuel_consumption_rate` 5.0, `max_fuel` 150. The Burn's multiplier over Aux should be far larger than 2x, and Aux thrust should be well below today's `thrust_power`.
- `docs/DESIGN.md` §4.1 "Boost mode: faster but burns fuel 3x" and §4.7 "Fuel Depletion" are superseded.
