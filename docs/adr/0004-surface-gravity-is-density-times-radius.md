---
status: accepted
date: 2026-09-19
---

# Surface gravity is density times radius

Every Body's mass is derived, not authored. `Planet._derived_mass()` works back from a
target surface pull of `REFERENCE_GRAVITY * DENSITY[planet_type] * density_trim * radius /
REFERENCE_RADIUS`, anchored on TERRA-0 at 1.9 G. Surface pull therefore comes out as
density times radius: a wider Body always outweighs a narrower one made of the same
stuff, and the big worlds are the ones that pull hard.

The sun's Record was reported as reading 1.7 G. It measured **1.6 G** — 1.7 G was Rook's
row, a 1600 px moon that outweighed the star it orbits. That inversion, not the sun,
was the bug.

## What was wrong

`massMultiplier` was hand-tuned per Body with no shared rule, so surface pull ended up
uncorrelated with size — in practice, inverted. Measured against the ship (mass 3.0,
thrust 350, so base thrust is 116.7 px/s²):

| Body | radius | read | pull at surface |
|---|---|---|---|
| Rook (moon) | 1600 | 1.7 G | 25% of thrust |
| Cairn (moon) | 448 | 1.2 G | 17% |
| Sun | 9000 | 1.6 G | 23% |
| Sonder | 6400 | 0.7 G | 11% |
| Crom | 3200 | 0.2 G | 3% |
| Veld | 2400 | 0.2 G | 3% |
| Roke | 2800 | 0.2 G | 3% |

The four large planets pulled at 1–3% of thrust — nothing the player could feel. A 448 px
pebble outpulled a 2400 px world sixfold, and the star at the end of the game pulled less
than its neighbour's moon. TERRA-0 was the only Body whose mass matched a uniform-density
sphere, which is why it was the only one that read right.

## Considered options

- **Leave it: "1.6 G is correct, a star is wide."** Rejected. It is a defensible reading of
  the formula in isolation, but it defends one number inside a table that is broken
  everywhere else. The sun is not a wide star — at 9000 px it is barely twice TERRA-0,
  because a real star would not fit in a system the player can fly across.
- **Special-case the sun.** Rejected on the same grounds #78 rejected it: the readout runs
  one formula for every Body (CONTEXT.md, Body), and a fudge at the sun leaves Rook still
  outweighing Veld.
- **Re-tune `massMultiplier` by hand to better numbers.** Rejected: it fixes the table
  without fixing what produced it, so the next authored Body drifts again.
- **Derive mass from class density and radius** (chosen). One rule, no per-Body numbers to
  get wrong, and a Body added later is weighed correctly without anyone thinking about it.

## Consequences

- Surface pull now reads: Sun 10.1, TERRA-0 1.9, Sonder 1.5, Crom 1.2, Roke 0.8, Veld 0.6,
  Rook 0.5, Char 0.4, Dross 0.2, Barrow 0.2, Cairn 0.1 G. Strictly ordered by size and
  density, with the star an order of magnitude clear of everything.
- **The sun is now the hardest place in the system to fly**, which is what the Core sitting
  there asks for (CONTEXT.md, Sun Station: "the last and hardest place to reach"). It pulls
  at 144% of base thrust at the surface — you cannot hover over a star — 45% at the scan
  ring, and 29% out at the Sun Station. Surveying the sun means holding against nearly half
  your thrust for the full 20 s scan.
- **Moons got lighter, deliberately.** Rook drops 1.7 G → 0.5 G and Cairn 1.2 G → 0.1 G.
  Landing on a small moon is now a slow drift rather than the heaviest touchdown in the
  game. Weight lives on the big worlds now, which is the point; Rook being the showcase
  landing site is not a reason to keep a moon outweighing its planet.
- **The pull stays local, untouched.** `gravity_radius_multiplier` (3.0, or 5.0 at the sun)
  is what keeps gravity off the player except close in, so sitting at a moon is never
  dragged on by its planet. This ADR does not change it. Anyone making gravity reach
  further should change that dial, not mass.
- **Orbits are unaffected.** `OrbitalMotion` sets position and velocity directly from
  `orbital_distance`, `orbital_speed`, `initial_angle` and `eccentricity`; it never reads
  `mass`. Mass only feeds `PlanetGravityField` (pull on the Ship) and the readout. Every
  Gate and station in the scene except the sun's sits outside its parent's gravity field,
  so docking is unchanged everywhere but the sun.
- `massMultiplier` is gone. `density_trim` replaces it as a per-Body deviation from the
  class density, and is 1.0 everywhere — there is currently no Body that needs one.
- The sun's `gravitational_constant = 8.0` override is gone. It was a second dial on the
  same lever as mass, and it was half of why the sun read as it did. The constant is now
  4.0 for every Body, and because `_derived_mass()` divides by it, it cancels out of
  surface gravity entirely: changing it now rescales the mass numbers without changing how
  any Body reads or pulls. It cannot become a second lever again.
- Anyone who reaches for a Body's mass to make one number look better should read this
  first. The number to change is `DENSITY`, or that Body's `density_trim`, with a reason.

## Checked

`tools/test.sh` (452 cases) and `tools/smoke.sh` pass, plus `test/PlanetGravityTest.gd`,
which holds the rule: a wider Body of the same class outpulls a narrower one, the sun
outweighs the rest of the home system several times over, and no moon outweighs the Body
it orbits. It rebuilds the Bodies from `HomeSystem.tscn`'s own radii and classes, so the
authored scene is what gets checked.

`launch.play`, `transit.play`, `chart.play` and `landing.play` pass, as do `seam`, `ores`,
`regrow`, `scanner`, `records` and `harvest`. Nothing drifted out of its orbit, which is
what `OrbitalMotion` ignoring mass predicts.

Run playtests **headless and one at a time**. Two windowed runs at once steal each other's
window focus, and a `focus_out` while a key is held drops that key mid-scenario - it shows
up as an unrelated assert failing. A scenario path must also be inside the project, or the
driver prefixes it with `res://` and silently sits there without running.
