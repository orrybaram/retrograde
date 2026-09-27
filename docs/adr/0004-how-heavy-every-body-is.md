---
status: accepted
date: 2026-09-19
---

# How heavy every Body is

Every Body's mass is derived, not authored. `Planet._derived_mass()` works back from a
target surface pull of

    REFERENCE_GRAVITY * DENSITY[planet_type] * density_trim * (radius / REFERENCE_RADIUS) ^ RADIUS_EXPONENT

anchored on TERRA-0 at 5.2 G, with `RADIUS_EXPONENT` of 0.5. Surface pull therefore comes
out as density times the **square root** of radius: a wider Body always outweighs a
narrower one made of the same stuff, but not in proportion to how much wider it is.

## What was wrong

Two things, and the second only showed up once the first was fixed.

**The order was inverted.** `massMultiplier` was hand-tuned per Body with no shared rule,
so surface pull ended up uncorrelated with size. The sun's Record was reported at 1.7 G;
it measured 1.6 G, and 1.7 G was Rook's row — a 1600 px moon outweighing the star it
orbits. Cairn, a 448 px pebble, outpulled Veld, a 2400 px world, sixfold. TERRA-0 was the
only Body whose mass matched a uniform-density sphere, which is why it was the only one
that read right.

**The whole scale was too light.** Measured against the ship (mass 3.0, thrust 350, so
base thrust is 116.7 px/s²), the four large planets pulled at 1–3% of thrust — nothing the
player could feel. Flying it, Veld wanted to be around 8x heavier than the first fix gave
it before it read as a world rather than a backdrop.

## The ceiling that shapes the rule

Landing means arresting a descent, so a Body the ship cannot out-thrust cannot be landed
on at all. That puts a hard ceiling near 100% of base thrust, and a practical one lower —
at 74% there is only a quarter of the engine left to brake with.

This is what rules out simply scaling everything up. Lifting the whole system by the ~8x
that made Veld feel right gives:

| Body | | |
|---|---|---|
| Sun | 80 G | 1145% of thrust — unescapable even on boost |
| TERRA-0 | 15.1 G | 215% — cannot hover, so cannot land |
| Sonder | 12.1 G | 172% — same |
| Crom | 9.3 G | 133% — same |

The system spans 448 px to 9000 px, twenty to one. Over a spread that wide a straight line
cannot hold both ends: heavy enough to be felt on a small Body puts every large one past
landable. Hence the square root, which keeps the order intact while pulling the ends close
enough together that the whole system is flyable. For the same reason `DENSITY` is a
narrow spread now — size already carries most of the difference, and a wide density spread
stacked on top of it pushes the heavy end back over the ceiling.

## Considered options

- **Leave it: "1.6 G is correct, a star is wide."** Rejected. A defensible reading of the
  formula in isolation, but it defends one number inside a table broken everywhere else.
  The sun is not a wide star — at 9000 px it is barely twice TERRA-0, because a real one
  would not fit in a system the player can fly across.
- **Special-case the sun.** Rejected on the same grounds #78 rejected it: the readout runs
  one formula for every Body (docs/GLOSSARY.md, Body), and a fudge at the sun leaves Rook still
  outweighing Veld.
- **Re-tune `massMultiplier` by hand to better numbers.** Rejected: it fixes the table
  without fixing what produced it, so the next authored Body drifts again.
- **Keep pull proportional to radius and scale it up.** Rejected against the ceiling above.
- **Density times the root of radius, derived** (chosen). One rule, no per-Body numbers to
  get wrong, and a Body added later is weighed correctly without anyone thinking about it.

## Consequences

| Body | radius | reads | surface | at its scan ring |
|---|---|---|---|---|
| Sun | 9000 | 20.1 G | 287% | 89% |
| TERRA-0 | 4400 | 5.2 G | 74% | 39% |
| Sonder | 6400 | 5.0 G | 72% | 37% |
| Crom | 3200 | 4.3 G | 61% | 33% |
| Roke | 2800 | 3.9 G | 56% | 30% |
| Veld | 2400 | 3.4 G | 48% | 26% |
| Rook | 1600 | 3.0 G | 43% | 26% |
| Char | 1280 | 2.7 G | 38% | 21% |
| Dross | 704 | 2.0 G | 28% | 17% |
| Barrow | 576 | 1.8 G | 26% | 16% |
| Cairn | 448 | 1.6 G | 23% | 15% |

- **The sun is the hardest place in the system to fly**, which is what the Core sitting
  there asks for (docs/GLOSSARY.md, Sun Station: "the last and hardest place to reach"). You
  cannot hover over a star; the 20 s survey at the scan ring costs 89% of thrust held the
  whole time, and the Sun Station sits in 58%. Boost is 200%, so there is always a way out.
- **TERRA-0 is the heaviest Body that can be landed on**, at 74%. That is deliberate: it
  sets the ceiling the rest of the rule is fitted under. Raising `REFERENCE_GRAVITY`
  further starts taking the big worlds out of reach.
- **The pull stays local, untouched.** `gravity_radius_multiplier` (3.0, or 5.0 at the sun)
  is what keeps gravity off the player except close in, so sitting at a moon is never
  dragged on by its planet. This ADR does not change it. Anyone making gravity reach
  further should change that dial, not mass.
- **Orbits are unaffected.** `OrbitalMotion` sets position and velocity directly from
  `orbital_distance`, `orbital_speed`, `initial_angle` and `eccentricity`; it never reads
  `mass`. Mass only feeds `PlanetGravityField` (pull on the Ship) and the readout.
- `massMultiplier` is gone. `density_trim` replaces it as a per-Body deviation from the
  class density, and is 1.0 everywhere — there is currently no Body that needs one.
- The sun's `gravitational_constant = 8.0` override is gone. It was a second dial on the
  same lever as mass, and half of why the sun read as it did. Because `_derived_mass()`
  divides by it, it now cancels out of surface gravity entirely: changing it rescales the
  mass numbers without changing how any Body reads or pulls. It cannot become a second
  lever again.
- The dev panel's GRAVITY section moves `Planet.dev_gravity_scale` and `density_trim` live,
  which is how this table was arrived at. Nothing it does is saved.
- Anyone who reaches for a Body's mass to make one number look better should read this
  first. The numbers to change are `REFERENCE_GRAVITY`, `RADIUS_EXPONENT` or `DENSITY`,
  and the ceiling above is what bounds them.

## Checked

`tools/test.sh` and `tools/smoke.sh` pass, plus `test/PlanetGravityTest.gd`, which holds
the rule: a wider Body of the same class outpulls a narrower one (at the root of the
ratio), the sun outweighs the rest of the home system several times over, and no moon
outweighs the Body it orbits. It rebuilds the Bodies from `HomeSystem.tscn`'s own radii
and classes, so the authored scene is what gets checked.

Run playtests **headless and one at a time**. Two windowed runs at once steal each other's
window focus, and a `focus_out` while a key is held drops that key mid-scenario — it shows
up as an unrelated assert failing. A scenario path must also be inside the project, or the
driver prefixes it with `res://` and silently sits there without running.
