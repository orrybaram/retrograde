# RETROGRADE - Flight

Two drives, one of which never runs out, and what that does to the rest of the game.

The *system*. ADR 0010 is the decision; ADR 0011 covers leaving the ship behind.
Supersedes the propulsion half of `docs/DESIGN.md` §4.1 and all of §4.7's Fuel Depletion.

---

## 1. The Problem

Fuel was the thing keeping the ship alive, which made the fuel gauge the most anxious
object on screen in a game with no combat. Running dry was a hard stop: control taken away,
a forced walk home, or a death.

It also made fuel do two jobs badly at once - it was both the pressure and the pacing, so
it could not be tuned for either.

Split it. **One drive is free and slow. The other costs fuel and is immediate.** Fuel stops
keeping the ship alive and starts making it responsive.

## 2. The Two Drives

### Aux

A solar-electric ion drive that scavenges reaction mass from ambient debris dust.

- **No gauge, no meter, no resource.** It is always available and it always works.
- Minuscule thrust. Slow to build speed, slow to shed it.
- Power comes from panels, sized for the outer system, so thrust is the same everywhere.

### Burn

A chemical drive on mined volatiles - frozen hydrogen and methane ices.

- Enormous thrust relative to the Aux.
- Drains fast. This is the only thing fuel is ever spent on.
- Bound to the existing `boost` action.

### Why this is honest

| | Chemical | Ion / electric |
|---|---|---|
| Thrust | millions of N, short bursts | **25-250 mN** (Dawn ran ~90 mN) |
| Specific impulse | 300-450 s | **2,000-5,000 s** |
| Endurance | seconds to minutes | NEXT: **48,000 hours over 5.5 years, ~870 kg of xenon** |
| Power | self-contained | 1-7 kW, from solar panels near the sun |

That endurance figure is the whole argument. An ion drive's consumption sits so far below
its runtime that on any human timescale it is free - no hand-waving required. The ~10x
specific-impulse gap is also the real reason the Burn drains a gauge and the Aux does not.

Scavenging reaction mass is a small extension of real air-breathing electric propulsion
research, which scoops residual atmosphere in very low orbit. A scrapper's ship that eats
the junk it flies through is the right version of that for this world.

Veld is an ice world and `docs/DESIGN.md` §2.2 already lists "frozen fuel reserves" among
its resources. **The starting zone is where fuel comes from.** That was already written.

## 3. The Reframe

> **The Aux is not slow. It is low-thrust.**

In a frictionless sim, cutting thrust does not cap velocity. It means the ship takes a long
time to *reach* a speed and a long time to *shed* one. Top speed is unchanged, and coasting
is still fast.

So Aux flight makes the ship feel **massive**. The player plans burns, starts decelerating
early, and thinks a trip through before making it. `docs/DESIGN.md` §4.1 already asks for a
ship that is "heavy and sluggish… stopping takes planning" and that "groans and rattles" -
this is that, with a reason behind it.

And it completely changes what the Burn is for. Not *go faster*:

> **The Burn is authority over your own momentum.**

Dodge the debris. Stop before the station. Climb out of a gravity well. Which means an empty
tank does not strand the player - **it makes them clumsy.** They can still go anywhere. They
just cannot react.

Flying a heavy, unresponsive ship through a debris field with no fuel is more frightening
than an empty gauge ever was, and it never takes control away.

## 4. Aux Thrust Is Flat

Aux thrust does not vary with distance from the sun, and this was a deliberate call rather
than an oversight.

A solar array's output really does fall off as inverse square, and it is tempting to spend
that on a feel gradient - sluggish outer rim, quick inner system. It was considered and cut:

- Across a ~500,000-unit system the real curve is about 100x, so it would have to be faked
  down to 2-3x anyway, at which point it is an invented number wearing a physics costume.
- It multiplies against Aux thrust *and* cargo mass, so it is a third value in a tuning
  problem that already has two.
- It would make the outer system - where the game opens, and where the player spends their
  first hours - the most sluggish place in the game. The opening is the wrong place to put
  the worst handling.

The physical justification for a flat drive is ordinary: real arrays are sized for the
worst case. A craft built to work across the whole system sizes its panels for the outer rim
and regulates the surplus closer in.

What survives, because it never needed the gradient:

> **The Aux runs on sunlight, and the sun is the Core.**

Every metre the player moves without fuel, they move on power drawn from the thing they are
waking up. That is fiction, and it lands on its own.

## 5. Fuel Is Time

Fuel buys speed, and nothing else. Mining it is how the player spends less of their own
time. That completes the resource split (ADR 0007, ADR 0010):

> **The ring pays for the trip. The void pays for the ship. The seams pay for speed.**

This also closes ADR 0007's open question about `OreDeposit`. Seams had lost their job when
the Planetary Scanner became a learned Sweep; now they are where volatiles come from. Ice
worlds and moons, under the crust, worked with the same Sweep as everything else. A moon
landing is a fuel run.

## 6. Abandoning

Full decision in ADR 0011. In short: a deliberate hold-to-confirm, available anywhere, any
time, whatever the fuel state. The hull stays where it was left as a permanent salvageable
derelict; the haul and any unfitted Components stay with it; fitted upgrades persist; the
new ship wakes with an empty tank.

The player is never forced to fly home. They can always choose to stop being out here - and
they will choose it casually, to save a dull trip, over and over, and the game will never
comment.

## 7. Risks

**Tedium is the real one.** A slow Aux across a 500,000-unit system. Mitigated by coasting
being fast, by the Burn existing, and by Gates - which this change makes far more valuable, exactly when they have stopped
costing money and started costing literacy (ADR 0005). It still needs playtesting before it
is committed to.

**The Burn must not become the default.** If fuel is plentiful nobody flies on Aux and the
whole system is decoration. Scarcity has to bite hard enough that spending fuel feels like
spending something.

**No second gauge.** The Aux must never have a meter of any kind. The moment it has a
readout, players will manage it, and the entire point is that it is the thing they never
have to think about.

**Cargo mass matters much more now.** `cargo_mass_multiplier` against a low-thrust drive
means a full hold is genuinely sluggish. That is good - it makes the hold upgrade meaningful
in a new way - but it is a multiplication of two tuning values and will need care.

## 8. Existing Tuning To Revisit

From `entities/Ship/Ship.gd`:

| Export | Today | Note |
|---|---|---|
| `thrust_power` | 350.0 | Becomes the **Aux**, and should drop well below this |
| `boost_power_multiplier` | 2.0 | Becomes the **Burn**, and 2x is far too small a gap |
| `boost_fuel_multiplier` | 3.0 | Only the Burn consumes at all now |
| `fuel_consumption_rate` | 5.0 | Applies to the Burn alone |
| `max_fuel` | 150.0 | Now a measure of how much of a trip can be fast |
| `cargo_mass_multiplier` | 0.01 | Interacts with the lower Aux thrust; re-tune together |

---

## TODOs

> **TODO**: Pick the Aux/Burn thrust ratio by feel, not by the real 1000:1. Start somewhere
> around 6-10x and playtest. The real ratio is unplayable and the fiction does not require it.
> **TODO**: Playtest a full Veld-to-Crom crossing on Aux alone with a full hold. That is the
> worst case and it is what decides whether this ships.
> **TODO**: Bind abandon to a hold on something that is not `action` (which is the Sweep) and
> not `boost` (which is now the Burn).
> **TODO**: Decide how a Burn reads and sounds against an Aux burn. They are different
> engines and should not share a particle effect - `_update_particles()` currently switches
> `thruster_particles` / `boost_particles`, which is most of the way there.
> **TODO**: Rewrite `docs/DESIGN.md` §4.1's physics-model bullets, which still describe one
> throttle with a 3x boost.
