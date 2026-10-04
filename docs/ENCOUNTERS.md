# RETROGRADE - Encounters

How the space between planets gets populated, and what the player finds there.

Owner: `entities/encounters/` (`EncounterField` in `scenes/Main.tscn`, table
`entities/encounters/tables/deep_space.tres`). Tests: `test/EncounterFieldTest.gd`.
Playtest: `playtests/encounters.play`.

---

## 1. The Idea

The Void starts 340,000 units from the sun (`VoidZone.EDGE_RADIUS`); Veld orbits at
253,125. Every planet ring is spawned by an `OrbitalRingSpawner`, bound to its body and
refilled over time. That works for a ring because a ring is bounded and near the player. It
does not work for the space between planets: it cannot be filled up front and cannot be
hand-placed.

> **Deep space is a deterministic function of the seed, streamed in cells.**

What lives in a cell is a pure function of `(seed, cell coordinates)`, computed on demand and
never stored. Only the cells around the ship exist as live nodes. Three properties follow:

- **Stable.** Fly away and come back, it is still there. No save needed for the contents.
- **Cheap everywhere.** The field costs the same at Veld as next to the sun.
- **Emergent.** Cells are slices of rings that turn at their own rates, out of step with the
  planets, so the stretch of space a given route crosses changes over a long session.

The emptiness is the point. Most cells hold nothing, so finding something is an event rather
than scenery.

## 2. Cells

A cell is `Vector2i(band, sector)`: a ring counted outward from the sun, and a slice of that
ring counted round from the ring's own rotating zero (`EncounterField.cell_of()`,
`cell_centre()`).

| Constant (`EncounterField.gd`) | Value | Meaning |
|---|---|---|
| `BAND_WIDTH` | 8,000 | Ring thickness, and roughly each sector's arc, so cells are about square |
| `WINDOW_RADIUS` | 1 | A 3×3 window of cells is resident (~24,000 across) |
| `CELL_CHECK_INTERVAL` | 0.25 s | How often the ship's cell is re-checked |
| `SUN_EXCLUSION` | 20,000 | Rings whose middle is closer than this hold nothing |
| `VOID_EXCLUSION` | 340,000 | Nothing at or past the Void's edge |
| `PLANET_CLEARANCE` | 4,000 | Added to a planet's gravity radius as a keep-out |
| `CELL_MARGIN` | 1,500 | Encounter origins are held this far off cell edges |

**Why 8,000.** It sits under the minimap's reach (`Minimap.world_range` = 10,000) and equal to
the distance at which orbital nodes put themselves to sleep (`OrbitalNode.SLEEP_DISTANCE_SQ`
= 8,000²). With a 3×3 window the nearest unloaded cell edge is always at least a cell away,
so nothing is seen to pop in on screen or on the minimap.

**Sectors per ring** are `round(TAU · band_mid / BAND_WIDTH)`: 16 at the innermost populated
ring, 261 at the outermost. Because rings have different counts, a neighbour is "the sector
of that ring the ship is currently under, ±1", found by angle, not by index.

**Where nothing goes.**
- Inside `SUN_EXCLUSION`: the sun's own gravity well owns that space.
- Past the Void's edge: salvage there would spoil the Void (nothing reflects, nothing
  answers) and bait the player across a line they cannot safely cross. See `docs/WORLD.md`.
- Inside any planet's gravity field plus `PLANET_CLEARANCE` (`_is_clear()`), where that
  planet's own spawners already put resources. Planets move, so this is a "not right now"
  test applied when the cell is generated, not part of the seed: the slot is skipped, not
  consumed, and can turn up on a later load of the cell once the planet has moved on.

## 3. The Rings Turn

Each ring turns rigidly about the sun (`band_rate()`). Angular rate falls off as `r^-1.5`,
the way an orbit's does, pinned to 12 px/s of tangential drift at Sonder's orbit (112,500),
and capped at 30 px/s.

| Where | Tangential drift |
|---|---|
| Innermost populated ring (~20,000) | ~28 px/s |
| Sonder (112,500) | 12 px/s |
| Outermost populated ring (~332,000) | ~7 px/s |

Visible if you sit and watch, never fast enough to be a hazard.

**Why that curve.** The planets in `HomeSystem.tscn` turn on a much flatter one (angular rate
roughly `r^-0.5`). The field runs ahead of the planets on the inside and lags them on the
outside, crossing near the middle of the system. Nothing is locked to anything else.

**Nodes actually orbit.** Each spawned node gets an `OrbitalMotion` about the sun at its
*ring's* rate, not its own radius's (`_set_adrift()`), so a cluster keeps its shape and nothing
drifts out of the cell that owns it. A node therefore reports a real `get_orbital_velocity()`:
flying into one bounces off what it is actually doing, and matching velocity to salvage it
works.

**The clock.** Ring rotation reads `elapsed()`: banked seconds plus wall time since streaming
began, minus pause time (`EventBus.game_unpaused`). This is the same clock `OrbitalMotion`
uses for planets. Accumulating `_process(delta)` would look identical at normal speed but
scale with `Engine.time_scale`, which `OrbitalMotion` ignores, and the rings would race the
nodes riding them. The clock holds still from a load until the ship is placed.

The emergence is slow. A ring takes hours of play to turn appreciably, since it runs on the
planets' timescale. Drift is visible moment to moment; "this crossing is different from last
time" is a long-session effect, not a per-trip one.

## 4. Tables and Defs

### 4.1 `EncounterTable`

A weighted list of `EncounterDef`s plus the sparseness dial. Rolling a cell
(`EncounterField._generate()`):

1. `roll_count()`: with probability `chance_per_cell`, `min_per_cell`–`max_per_cell`
   encounters; otherwise none. Always draws exactly one number, so an empty cell never
   shifts what a full one would hold.
2. For each encounter, `pick()` filters to defs whose radius band contains the ring's middle
   and picks by weight. Also always draws one number, even with nothing eligible.
3. A random origin inside the cell, then the def's `plan()`.

Shipped (`tables/deep_space.tres`): `chance_per_cell` **0.075**, one encounter per populated
cell. About three cells in forty hold anything.

### 4.2 `EncounterDef`

One encounter type, as data (`EncounterDef.gd`):

| Field | Meaning |
|---|---|
| `id` | Stable name; also what budget claims record |
| `contact_label` | What the encounter reads as (§6.3) |
| `weight` | Relative odds against other defs eligible at the same distance |
| `budget` | At most this many in one game (`0` = no limit) (§7.2) |
| `min_radius` / `max_radius` | Distance-from-sun band (`max_radius` 0 = to the edge) |

Generation is split in two so the world stays reproducible:

- `plan(rng, origin)` rolls **every** random choice, drawn from the cell's seeded generator
  (`RNG.get_seeded_rng(cell_seed)`, never `RNG.rng`), and returns one entry per node in a
  stable order.
- `build(field, entry)` turns one entry into a live node and rolls nothing.
- `release(node)` hands it back: pooled nodes to `ResourceNodePool`, anything else freed.

The field can only skip a harvested slot without shifting everything after it if the order is
fixed before anything spawns. Adding an encounter type is a new subclass plus a `.tres`; the
field never changes.

Radius banding is the pacing dial: a def banded inward simply does not exist in the outer
system. ADR `docs/adr/0007-no-currency-upgrades-are-found-objects.md` leans on this (and on
`budget`) for placing unique parts.

**RNG.** Field generation must not draw from `RNG.rng`; pulling from the shared stream would
shift every other roll depending on where the player flew (`test_generation_does_not_disturb_the_shared_rng`).

## 5. What Is Out There

Four defs ship, in `entities/encounters/defs/`:

| Def | Class | Label | Weight | Budget | Band |
|---|---|---|---|---|---|
| `debris_cluster` | `DebrisClusterDef` | `DEBRIS` | 1.0 | – | everywhere |
| `lone_container` | `ContainerDef` | `CONTAINER` | 0.35 | – | everywhere |
| `small_derelict` | `WreckDef` | `DERELICT` | 0.12 | – | everywhere |
| `clone_wreck` | `WreckDef` | `DERELICT` | 0.04 | 3 | ≥ 40,000 |

Weights are picked by eye and have not been balanced against fuel cost.

### 5.1 Debris cluster

A loose knot of scrap and dead debris. 4–10 pooled nodes (`Scrap1`–`5`, `Debris1`–`5`; 40%
debris) scattered evenly over a 900-unit disc, scale 0.5–1.0, slow spin. Scrap is
single-amount and harvests like ring scrap (three cuts, `ScrapNode.NORMAL_HITS`, 10% rolled
trophy); debris (`DebrisNode`) cannot be harvested, is off the minimap, and only bounces and
hurts. Fly through, take what is worth taking. Zero new art:
a cluster costs nothing the planet rings don't already cost.

### 5.2 Lone container

A sealed container adrift on its own: one pooled `ContainerNode` (`entities/resources/`),
always trophy grade. Five cuts instead of three (`ScrapNode.TROPHY_HITS`), +3 gems on the
break, and on a GOOD or PERFECT cut the trophy gem table (`GemData.TROPHY_ROLL_WEIGHTS`: gem,
crystal or artifact, never a shard; a botched cut still gives shards). It keeps its
sparkles but does not pulse, because a pulsing box reads as soft. Nothing else is near it, so
taking it costs a detour.

### 5.3 Small derelict

A broken hauler (`entities/encounters/hulls/SmallFreighter.tscn`): longer and boxier than
the player's arrowhead, spine broken open amidships. Built as a `DerelictShip` and salvaged
the way an abandoned ship is (`docs/FLIGHT.md`): five cuts (`DerelictShip.HITS`), each
releasing an even share of the hold, thinned by the timing grade (`GRADE_KEEP`: PERFECT keeps
all, GOOD 80%, LATE/OVERLOAD 50%); the last cut adds the hull's own scrap break. Hold: 2–6
gems from `shard, shard, gem, crystal`. Its harvest radius is widened to 24 from
`DerelictShip`'s 12, which is sized for the player's own smaller ship.

### 5.4 Clone wreck

The same `WreckDef` with no `hull`: it copies the player's own `ship_polygon`, a wreck that
matches their ship exactly. It is built **bare**, without the Components fitted to the
player's hull (`docs/adr/0014-fitted-components-are-on-the-hull.md`): the ship as the cloning
bay first printed it. Hold: 1–3 shards or gems, slower spin. `budget` 3, so it turns up two
or three times a playthrough, and never inside 40,000.

It reads as an ordinary `DERELICT` on purpose. You detour for routine salvage and find your
own ship.

### 5.5 Field wrecks and `DerelictShip`

Two things make `DerelictShip` work out here. Field wrecks set `transient`, so
`DerelictShip.snapshot_all()` skips them: the field rebuilds them from the seed, and saving
them too would leave a second copy on every load. And `get_orbital_velocity()` returns drift
*plus* the ring it rides, so anything matching velocity to salvage it doesn't slide out of
harvest range partway through.

## 6. From the Cockpit

### 6.1 On the minimap

- **Cluster scrap** passes for debris until a Sweep ring reaches it: tinted down, no
  sparkles, off the minimap, takes no cut (`ScrapNode._hides_until_pinged()`). See
  `docs/SWEEP.md`.
- **Containers and wrecks** never hide: a box is plainly a box, a hull plainly a hull.
- **A wreck** shows as an unlabelled echo a little bigger than scrap
  (`ui/minimap/DerelictMinimapTarget.gd`), pinned to the rim when out of range. Finding a
  hull instead of a rock is the surprise of arriving.

Field wrecks never hold Freight, so they get no Chart mark (`SystemMap.freight_marks()`).

### 6.2 Collisions

Field nodes are `OrbitalNode`s and collide like ring nodes: above 50 px/s relative they
bounce the ship (or loose Freight) off at 30% speed, and above 150 px/s
(`OrbitalNode.DAMAGE_SPEED_THRESHOLD`) they deal 0.5 hull per px/s over. Relative speed uses
the node's ring velocity. Dense clusters are dangerous at speed.

### 6.3 Contacts

`EncounterContact` is one encounter as anything looking at it would see it: the nodes it
placed and its `label`. A cluster of eight nodes is **one** contact. The field builds a
contact per encounter as it generates a cell, drops nodes as they are salvaged, and forgets
the contact once it is empty. `EncounterField.contacts_in_range(origin, radius)` returns live
contacts nearest first.

Nothing in the HUD reads contacts. A bearing/distance contact panel was built and removed: it
was more instrument than the game wanted, and naming what was out there before you got there
took something away from going to look. The grouping stays because it is how the field
models what it placed.

## 7. Persistence

### 7.1 Slot keys and consumption

Every planned node gets a stable key `"<band>:<sector>:<index>"`, where `index` is its place
in the cell's generation order. Indices advance for every planned node whether or not it is
built, so a key means the same thing in every session. It is written to
`OrbitalNode.spawner_key` (cleared in `on_despawn`).

When a field node is depleted (`resource_depleted`, any `ScrapNode` including
`DerelictShip`), its key goes into the consumed set and is skipped on every later generation.

**Deep space does not refill.** Unlike planet rings, the field ignores
`resources_refresh_requested`. A stripped stretch of the void stays stripped; that is the
reward for having gone there.

### 7.2 Budgets

A budgeted encounter is **claimed** by the first slots that build it, which means the first
cells the player's 3×3 window loads. Once `claimed_count(id)` reaches `budget`, unclaimed
slots simply don't have it. A claimed slot keeps its encounter forever, so returning to one
you found does not spend another.

### 7.3 Save and load

The field's whole persistent state is three values, in the save's `[encounters]` section
(`scripts/Save.gd`, `EncounterField.snapshot()` / `restore()`):

| Key | Holds |
|---|---|
| `consumed` | Harvested slot keys |
| `claimed` | Budget claims as `"<slot>=<def id>"` |
| `elapsed` | Game seconds the rings have turned |

Everything else regenerates from the seed. `scripts/Session.gd` restores the field before
`planets_restored`; the field then releases its cells and waits for `ship_respawned` to stream
around the ship, so no cell loads and no budget is claimed around where the ship used to be.
A relaunch keeps the world and the field keeps streaming. A new game (`reset()`) forgets the
consumed set, the claims and the clock.

## 8. Hazards

**No combat.** Danger is environmental. The universe is indifferent, not hostile; nothing in
the game shoots, chases or patrols.

Built hazards are collisions (§6.2, and body impacts in `docs/FLIGHT.md`) and the Void past
the last orbit (`docs/WORLD.md`).

## 9. Testing

- `test/EncounterFieldTest.gd`: cell geometry, ring rates and drift bounds, determinism
  (same cell, same contents; turned ring, same contents in a new place), shared-RNG
  isolation, consumption, save/restore, exclusions (sun, Void, planet gravity), table
  weighting and sparseness, contacts, budgets and claims, each shipped def.
- `playtests/encounters.play`: flies into deep space, watches the rings carry a node, leaves
  and returns, harvests scrap and a container and checks they stay taken, checks the sun's
  space is empty, the clone budget holds, and a save/reload keeps consumption, claims, clock
  and doesn't duplicate wrecks.
- Deep space is sparse enough that tests hunt for things: the playtest `seek <Kind>` command
  (`scripts/Playtest.gd`) warps around the void on a fixed sequence, at least 60,000 from any
  planet, until a field node of that kind is streaming. Anything asserting on a fixed location
  breaks the next time the rarity dial moves.

## Known gaps

- **Partial cuts don't persist.** Only depletion is recorded. A wreck or container cut 3 of 5
  times and left behind regenerates whole, hold restocked, when its cell reloads
  (`EncounterField._detach()` / `_generate()`).
- **Pooled nodes still touch the shared RNG.** `ScrapNode.on_spawn()` rolls a 10% trophy and
  `_load_shape()` picks a shape from `RNG.rng`, and `DerelictShip.drops_for_hit()` uses it too.
  Streaming perturbs the global sequence, and cluster scrap shapes and trophy status are not
  reproducible across sessions even though positions are.
- **`contacts_in_range()` and `contact_label` have no consumer** outside tests; the contact
  layer is dormant (§6.3).
- **The consumed set grows without bound** (`_consumed`, saved whole). Small in practice; a
  fully stripped cell never collapses to a single entry.
- **Unbalanced.** Weights and `chance_per_cell` have not been played against fuel cost, and
  wreck/container yield is still gems, not the Components ADR 0007 says the void pays out.
