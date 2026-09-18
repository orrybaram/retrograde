# RETROGRADE - Emergent Encounters

How the space between planets gets populated.

Companion to `docs/DESIGN.md` §4.1 (Transit Encounters) and `docs/IDEAS.md` (Anomalies).
This document is the *system*; those two are the *content*.

---

## 1. The Problem

The system is roughly 500,000 world units across — Veld orbits at 253,125, and the Sun's
own radius is 9,000. Every resource node in the game today spawns in a ring bound to a
planet or a station (`OrbitalRingSpawner`, `ResourceSpawner`), all at game start, and
lives until harvested.

That works for rings because a ring is bounded and near the player. It does not work for
interplanetary space. You cannot spawn a million nodes up front, and you cannot hand-place
a world that large.

So the space between planets is empty. The design doc asks it to have texture.

## 2. The Core Idea

> **Deep space is a deterministic function of the seed, streamed in cells.**

Space is divided into cells. What lives in a cell is a pure function of
`(seed, cell coordinates)` — computed on demand, never stored. Only the cells near the
ship exist as live nodes; the rest is math that hasn't been run yet.

Cells are **polar**: a cell is a slice of a ring around the sun, and each ring turns at
its own rate. A cell keeps its contents as its ring carries them around, so the world
orbits without any of it having to be remembered.

Three properties fall out of this:

- **Stable.** Fly away and come back, it's still there. No save file needed.
- **Infinite.** Cells are generated on demand, so the field costs the same at Veld as at
  the Sun.
- **Emergent.** The contents are fixed, but *which* cells a given route crosses depends on
  where the planets are that trip, and on where the rings have turned to. The field runs
  on a different rate curve from the planets, so nothing in the system is locked to
  anything else in it.

That last point is what the design doc means by "the same trip can feel different."

## 3. Architecture

### 3.1 `EncounterField`

A `Node2D` in `Main`. Tracks the ship, keeps a 3×3 window of cells resident, and
activates/releases cells as the ship crosses boundaries. Knows nothing about what an
encounter *is* — it only knows cells, seeds, rates, and lifetimes.

A cell is `Vector2i(band, sector)`: a ring counted outward from the sun, and a slice of
that ring counted round from the ring's own rotating zero.

**Band width: 8,000 units.** Chosen to sit just under two existing numbers:

- `Minimap.world_range` = 10,000 — the scanner's reach
- `OrbitalNode.SLEEP_DISTANCE_SQ` = 8,000² — where nodes self-sleep

Sector count per ring is picked so each sector spans about 8,000 units of arc too, which
keeps cells roughly square at every distance. A 3×3 window spans ~24,000 units, so the
nearest edge of an unloaded cell is at least a cell away. Nothing ever pops in on screen
or on the scanner.

Neighbours are found by *angle*, not by index: rings have different sector counts, so
"one ring out" means "the sector of that ring the ship is currently under", ±1.

### 3.2 `EncounterDef` (Resource)

One encounter type, as data. The base class holds the placement rules:

| Field | Meaning |
|---|---|
| `id` | stable string |
| `weight` | relative odds against the other defs eligible at the same distance |
| `min_radius` / `max_radius` | distance-from-sun band where it can appear (`max_radius: 0` = out to the edge) |
| `budget` | at most this many may ever exist in one game (`0` = no limit) |

Generation is split in two, and that split is what makes slot keys mean anything:

- `plan(rng, origin) -> Array[Dictionary]` — one entry per node, in a stable order. **All**
  randomness happens here, drawn from the cell's seeded generator.
- `build(field, entry) -> Node` — turns one entry into a live node, and rolls nothing.

The field can only skip an already-harvested slot without shifting everything after it if
the order is fixed before anything spawns. `release(node)` hands a node back — pooled
nodes to the pool, anything else freed.

Adding a new encounter type is a new subclass plus a `.tres`. The field never changes.

**Budget** is for the things that should be a shock rather than a fixture. A budgeted
encounter is *claimed* by the first slots the player actually flies near; once the budget
is gone it simply isn't anywhere else. A claimed slot keeps its encounter forever, so
going back to one you found doesn't spend another. The claims are saved as
`"<slot>=<def id>"` alongside the consumed set.

### 3.3 `EncounterTable` (Resource)

A weighted list of `EncounterDef`s. Rolling a cell means: compute the cell's distance from
the Sun, filter the table to defs whose band contains it, pick by weight.

Because the band is radius-based, the five-planet tone gradient from the design doc —
mundane logistics near SR-7, industrial, research, military, then silence at TERRA-0 —
falls out for free. A radio-echo def tagged `min_radius: 150000` is automatically a
military-era echo.

### 3.4 Contacts

`EncounterContact` is one encounter as the scanner sees it: the nodes it put there, and
what it reads as. A debris cluster is eight nodes but **one** contact.

That grouping is the whole reason the scanner works. The decision it exists to support is
"detour or stay on course", and eight rows for one knot of scrap would drown that. The
field builds a contact per encounter as it generates a cell, drops nodes from it as they
are salvaged, and forgets it once it is empty. `contacts_in_range()` is what the HUD asks.

Labels come from `EncounterDef.contact_label`, and encounters may deliberately share one:
a **clone wreck reads as an ordinary `DERELICT`**, because from out there that is all the
scanner can tell. You detour for routine salvage and find your own ship.

### 3.5 Slot keys and consumption

Every spawned node gets a stable key: `"<band>:<sector>:<index>"`, where `index` is the
node's position in the cell's deterministic generation order. It's written to the node's
`spawner_key` field (which already exists on `OrbitalNode`, unused until now, and is
already cleared in `on_despawn`).

When a node is harvested, its key goes into a consumed set in the save. Generation skips
consumed keys. Alongside it the save keeps one float: how many game seconds the rings
have been turning. **That pair is the only persistent state in the entire system** —
everything else regenerates from the seed.

Deep space stays stripped. Unlike planet rings, it does *not* refill on
`resources_refresh_requested`. If you cleaned out a stretch of the void, it stays clean.
That's the reward for having gone there.

## 4. Phases

### Phase 1 — Bones + one encounter type ✅

`EncounterField`, `EncounterDef`, `EncounterTable`, consumed set in `Save`. One encounter:
a debris cluster built from pooled `ScrapNode`s and `DebrisNode`s — zero new art, zero new
interactions. Cells were cartesian here; Phase 2 swapped them for polar behind
`cell_of()` / `cell_centre()`.

The slice is complete when you can fly Rook → Crom, pass something, harvest it, fly home,
come back, and find the space where it was now empty. `playtests/encounters.play` does
exactly that.

### Phase 2 — Orbital field ✅

Cells became polar and the rings turn.

**Rate.** Angular rate falls off as `r^-1.5`, the way an orbit's does, pinned to 12 px/s
of tangential drift at Sonder's orbit (112,500). That gives 8–25 px/s across the system:
visible if you sit still and watch, never fast enough to be a hazard.

**Why that curve.** The planets in `HomeSystem.tscn` turn on a much flatter one — their
angular rate goes roughly as `r^-0.5`, at 2.5–5.6 px/s. So the field runs ahead of the
planets on the inside and lags behind them on the outside, crossing over near the middle
of the system. Nothing is locked to anything else, which is the whole point.

**Nodes actually orbit.** Each spawned node gets an `OrbitalMotion` around the sun at its
*ring's* rate rather than its own radius's, so a ring turns rigidly: a cluster keeps its
shape and nothing drifts out of the cell that owns it. It also means a node reports a real
`get_orbital_velocity()`, so flying into one bounces off what it is actually doing.

**The clock.** `EncounterField` accumulates game seconds in `_process`, which doesn't run
while the tree is paused — the same stretch `OrbitalMotion` skips, so the rings and the
nodes riding them stay in step. That float is saved and restored with the consumed set.

### Phase 3 — Content breadth ✅ (three of five)

Three more encounters, all built on systems that already existed:

**Lone container** (`ContainerDef`). A sealed container adrift on its own, always trophy
grade: five clean cuts instead of three, and a much better class of gem out of each. It is
a pooled `ContainerNode` — a `ScrapNode` that overrides the new `_shape_scenes()` hook so
it looks like a container rather than generic wreckage — registered in `ResourceNodePool`
like any other variant.

**Small derelict** (`WreckDef` + `hulls/SmallFreighter.tscn`). A broken hauler, longer and
boxier than the player's arrowhead, salvaged the way an abandoned ship is: each cut
recovers a share of the hold, and the hull breaks for scrap on the last one. Its
`harvest_radius` is widened from `DerelictShip`'s default, which is sized for the player's
own much smaller ship.

**Clone wreck** (`WreckDef` with no `hull`). The same def with its hull left empty builds
from the player's own `ship_polygon` instead — a wreck that matches their ship exactly.
`budget: 3`, so it stays the two or three times a playthrough the design doc asks for.

`DerelictShip` needed two changes to work out here. A `transient` flag, because field
wrecks are rebuilt from the seed and `snapshot_all()` must skip them — without it every
load would leave a second copy behind. And `get_orbital_velocity()` now returns its drift
*plus* the ring it is riding; it used to report drift alone, which was right for an
abandoned ship standing still and wrong for a wreck moving at 9 px/s. Anything matching
its velocity to salvage it would have slid out of harvest range partway through.

**Not done, and why:**

- **Dead satellite.** Its interaction is the hacking terminal — collection Method 3 in
  `docs/DESIGN.md` §4.2 — which does not exist yet. Without it a satellite is a differently
  shaped piece of scrap, which is not the encounter.
- **Region-keyed radio echoes.** `RobotRadio` and `RadioConversation` can carry the text,
  but they present it as the guide robot transmitting, face card and all. The design doc
  wants fragments of a dead civilization bouncing around empty space, read off the ship's
  terminal. Routing them through the robot's panel would make a dead world's last
  transmissions look like the cheerful guide talking, and would be hard to undo later.
  They need an ambient presentation first — a small piece of UI work, not content work.

### Phase 4 — Scanner signals ✅

`ui/ScannerPanel.gd`, a bordered terminal panel in the HUD's top-right corner — the other
three corners are taken by the dashboard, the minimap and the radio.

```
S C A N
DEBRIS      -049    4.7 km
DEBRIS      -034    4.9 km
CONTAINER   -139    6.4 km
DERELICT    -151    7.0 km
CONTAINER   +021    8.3 km
```

Five rows at most, nearest first. **Bearings are relative to the ship's nose**, the way
the player actually has to fly: negative to port, positive to starboard, `+000°` dead
ahead. Signed and zero-padded so the column never jitters. Distance reuses
`TrackingSolution.format_distance`.

Range is 10,000, matching `Minimap.world_range`, so the list and the minimap always agree
about what is out there. A scanner upgrade would raise it — that is the axis the design
doc means by "a good scanner shows more signals at greater range".

The panel hides itself when there is nothing in range, when docked, and outside play.
`ANOMALY` and `UNKNOWN` belong to Phase 5.

One layout note worth keeping: the panel is placed by hand rather than by anchors.
Anchored top-right with `GROW_DIRECTION_BEGIN`, the rows ran off the screen edge as they
grew; `_place()` resets both containers and pins the right edge itself.

### Phase 5 — Anomalies and Titan events

Same table, but gated on progression state instead of weight. `docs/IDEAS.md` has the
content; the escalation tiers map onto radius bands plus a containment-damage counter.

## 5. Risks

**RNG pollution.** Field generation must draw from `RNG.get_seeded_rng(cell_seed)`, never
`RNG.rng`. Pulling from the shared stream would shift every other roll in the game
depending on where the player happened to fly — the same class of bug as VFX drawing from
the shared RNG.

Note a pre-existing wrinkle: `ScrapNode._load_shape()` and the trophy roll in `on_spawn()`
*do* use `RNG.rng`. Streaming therefore perturbs the global sequence as a side effect.
Every existing spawner already does this, so it is not new, but it does mean scrap *shapes*
in deep space are not reproducible across sessions even though their *positions* are.
Worth fixing when the pool learns to take an RNG.

**Save growth.** The consumed set grows without bound. In practice it's small — a key is
about twelve bytes and a player can only harvest so much — but a cell that has been fully
stripped should eventually collapse to a single "cell cleared" entry.

**Minimap churn.** Register/unregister happens on every cell transition. Batch it on
activate/release; never do it per frame.

**The emergence is slow.** A ring takes hours of play to turn appreciably, because it is
pinned to the same timescale the planets already run on (TERRA-0's year is about 35 hours).
Drift is visible moment to moment, but "this crossing is different from last time" is a
long-session effect, not a per-trip one. Speeding the field up would make it clash with
the planets it flies past.

**The scanner has no cost.** It shows everything in range for free, always. The design
doc's upgrade axis (range, and the unreliable `UNKNOWN` contacts a late-game scanner
picks up) is what makes it a progression, and none of that exists yet.

**Balance is unexamined.** There are now four encounter types with weights picked by eye
(cluster 1.0, container 0.35, derelict 0.12, clone wreck 0.04). Whether a container is
worth the fuel to reach it has not been played against the economy at all.
