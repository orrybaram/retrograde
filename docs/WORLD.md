# RETROGRADE - The World

The system the player flies through: its Bodies and orbits, the Gates and the link they make,
Titan Influence, and the three instruments that describe the world - the minimap, the Chart
and the Log. Plus the Void, where the system stops.

What is here is what is built. Designed-but-unbuilt world material (planet lore, the Core
endgame, the Merchant, Procedure-powered Gates) lives in `docs/STORY.md` and `docs/IDEAS.md`.
Neighbouring docs: `docs/FLIGHT.md` (the ship, docking, death and relaunch),
`docs/SWEEP.md` (sonar, scrap, seams, tracking), `docs/FREIGHT.md` (Freight, Components,
Stores, station service), `docs/OPENING.md` (Act 1 at SR-7), `docs/ENCOUNTERS.md` (the
deep-space field).

---

## 1. The System

The **Kotlar** (KSD-78). One scene, `scenes/HomeSystem.tscn`: a sun, five planets, five
moons, two stations and six Gates. Everything is a child of the thing it orbits, so a moon
rides its planet and a station rides its moon.

The **Titan** is the system: five planets host its five **Modules**, the sun holds its
**Core**. It is switched off. Nothing in the world says so; the dead structures in orbit read
as war junk.

| Body | Type | Radius | Orbits | Distance | Period | Moons |
|---|---|---|---|---|---|---|
| Sun | SUN | 9000 | - | - | - | - |
| TERRA-0 | EARTH_LIKE | 4400 | Sun | 50,000 | 34.9 h | - |
| Roke | BARREN | 2800 | Sun | 75,000 | 42.6 h | Cairn |
| Sonder | GAS_GIANT | 6400 | Sun | 112,500 | 52.9 h | Char |
| Crom | ROCKY | 3200 | Sun | 168,750 | 64.6 h | Dross, Barrow |
| Veld | ICE | 2400 | Sun | 253,125 | 79.3 h | Rook |
| Rook | BARREN | 1600 | Veld | 20,000 | 0.9 h | - |
| Cairn / Char / Dross / Barrow | BARREN | 448 / 1280 / 704 / 576 | parent | 10.5k / 21.6k / 8.4k / 13.2k | 1.0-2.5 h | - |

- The player lives at the outer edge: **SR-7** orbits Rook (6,000 out) which orbits Veld. Act 1
  is entirely there (`docs/OPENING.md`).
- Each planet carries a `planet_role` (FRONTIER, INDUSTRIAL, RESEARCH, MILITARY, HOMEWORLD for
  Veld → TERRA-0). Nothing reads it yet.
- `habitability` is 0 on every Body.
- Sonder is a gas giant: its collision core is 30% of its drawn radius, and it grows no seams.

### Orbits

`scripts/OrbitalMotion.gd`. Every Body, station and Gate sets its own position and velocity
from `orbital_distance`, `orbital_speed`, `initial_angle` and `eccentricity` (all
eccentricities are 0.01-0.06). Nothing is integrated, so nothing drifts.

- Orbits run on **wall-clock time** (`Time.get_ticks_msec`), shifted forward by however long
  the game was paused (`EventBus.game_unpaused`), so a menu does not move the planets.
- Angular speed is `orbital_speed / 100 * 0.01` rad/s. The planets crawl - a Veld year is 79
  hours - and moons lap them in about an hour. Rook's 20 against Veld's 0.22 is why the home
  station feels like it moves and the rest of the system does not.
- A save keeps every Body's current angle (`Save.gd`, `[planets]`); a load resumes there. A new
  game calls `reset_orbit()` on every Body and Gate so it starts from the scene's angles.
- **Geosync.** `Gate.geosync_with` phase-locks a Gate's angle to a sibling's orbit
  (`OrbitalMotion.angle_source`). Veld's Gate rides at 10,800 on the Veld-Rook line, so flown
  up to from home, Rook sits dead ahead through the ring and the Gate never has to be chased.

---

## 2. Bodies and Gravity

A **Body** is a planet, a moon or the sun; the sun is not special-cased anywhere it can be
avoided. `entities/Planet/Planet.gd`.

**Mass is derived, never authored** (`docs/adr/0004-how-heavy-every-body-is.md`):

    surface G = 5.2 * DENSITY[type] * density_trim * sqrt(radius / 4400)

anchored on TERRA-0 at 5.2 G. Pull grows with the **square root** of radius: over a system
spanning 448 to 9000 px, a linear rule cannot be felt on a pebble without putting the big
worlds past landable. `DENSITY` is deliberately narrow (0.8-1.0, sun 2.7). Mass only feeds
the gravity field and the readout; orbits never read it.

| Body | Surface | Field reach | Inner orbit |
|---|---|---|---|
| Sun | 20.1 G | 45,000 | 16,120 |
| TERRA-0 | 5.2 G | 13,200 | 6,080 |
| Sonder | 5.0 G | 19,200 | 8,880 |
| Crom | 4.3 G | 9,600 | 4,400 |
| Roke | 3.9 G | 8,400 | 3,840 |
| Veld | 3.4 G | 7,200 | 3,280 |
| Char | 2.7 G | 3,840 | 1,712 |
| Dross | 2.0 G | 2,112 | 906 |
| Barrow | 1.8 G | 1,728 | 726 |
| Cairn | 1.6 G | 1,344 | 547 |
| Rook | 1.0 G | 4,320 | 2,064 |

- **Field reach** is `radius * gravity_radius_multiplier` (3.0; the sun 5.0; Rook 2.7). Outside
  it a Body does not pull at all, so sitting at a moon is never dragged on by its planet.
  `PlanetGravityField.gd` pulls the ship only, through its centre of mass.
- **Inner orbit** (`Planet.scan_radius()`) is the first ring of the six drawn gravity rings
  that clears the surface. Entering it marks the Body **Visited** (§9).
- **Rook is trimmed light** (`density_trim = 0.336`), the one Body that deviates from its class.
  It is home: the ship lives in its well.
- The dev panel's GRAVITY section moves `Planet.dev_gravity_scale` and `density_trim` live;
  nothing it does is saved.
- Seams grow on every Body but the sun and the gas giant, seeded from the save key
  (`Planet._spawn_ore`); what happens to them is `docs/SWEEP.md`.

Tests: `test/PlanetGravityTest.gd` rebuilds the Bodies from `HomeSystem.tscn` and holds the
order (wider outpulls narrower, no moon outweighs its parent).

---

## 3. Stations

Two. Both are `SpaceStation` scenes; the Sun Station is its own scene, never inherited.

- **SR-7** - the home station, over Rook. The only member of the `space_stations` group:
  home tracking, the Chart's home label and the respawn all read the first node in it. What
  happens there is `docs/OPENING.md` and `docs/FREIGHT.md`.
- **Sun Station** (`entities/structures/SunStation.tscn`) - at 20,000 from the sun's centre,
  orbit speed 3, inside the sun's field (about a fifth of the surface pull, still the heaviest
  place anyone docks). It keeps
  out of `space_stations` (`SunStation.GROUP = &"sun_station"`) so it can never become home.
  Its two ports are open from the start, so a dock there tops the tank to SR-7's free half and
  deposits the hold as Stores like any open port; its hub offers only DEPART. The Core's Gate
  rides the same orbit 8° ahead of it.

---

## 4. Gates

`entities/structures/Gate.gd`, `ui/GateTerminal.gd`, `entities/Ship/states/GateDockedState.gd`.

A **Gate** is the dormant structure in a planet's orbit that powers that planet's Module.
Seven quarried blocks in a ring (radius 100, about 200 px across), the inner faces carved with
script, a wider keystone at the top carrying a sigil and one slow amber blinker, and a docking
**berth** across the 52° mouth at the bottom. The stonework is cut once from a generator
seeded by the Gate's save key - never the shared `RNG` - so each Gate looks the same every
visit and no two look alike.

| Gate | Orbits | Distance | Start angle | Cost |
|---|---|---|---|---|
| Veld | Veld (geosync with Rook) | 10,800 | 180° | 600 ST |
| Crom | Crom | 14,400 | 140° | 1,200 ST |
| Sonder | Sonder | 28,800 | 220° | 2,000 ST |
| Roke | Roke | 12,600 | 300° | 3,200 ST |
| TERRA-0 | TERRA-0 | 19,800 | 15° | 5,000 ST |
| Core | Sun (`is_core`) | 20,000 | 8° | - |

Every planetary Gate sits outside its planet's gravity field; orbit speed is 3 (5.8 h).

### Docking and the terminal

- The berth docks like a port (`Dockable`): 60 px reach, come in slow and lined up. The ship
  rides the Gate's orbit, locked. Docking rules are `docs/FLIGHT.md`.
- The **GATE** terminal opens on arrival. `menu_action` UP/DOWN, ENTER, ESC. ESC leaves the
  terminal but not the berth; `action` reopens it, thrust lifts off.
- Dormant: status `MODULE OFFLINE`, one row `POWER GATE  <cost> ST`. It stays selectable when
  the player cannot afford it (red cost) so the price can always be read.
- A Gate gives **no fuel and no service**. It is not a port. `test/GateTransitTest.gd`
  (`test_a_gate_dock_does_not_refuel`).

### Powering

- ENTER on `POWER GATE` spends the Stores and marks the Gate in `Progress.POWERED_GATES`. That
  is the Module coming online. There is **no way back**: the ledger never unmarks, nothing
  refunds.
- The terminal types a boot log (`POWER ... OK`, `LINK ... OK`, `MODULE ... ONLINE`, the last
  in Titan purple); `action` skips it.
- The ship takes one shake and the HUD one glitch hit, no damage, and the game autosaves.
- The ring comes up over 1.6 s: the carved script lights and a reading head runs it, the sigil
  and the channel behind the blocks fill with `Colors.TITAN`, the blinker holds steady purple.
  The stone only catches the spill.
- The hub then reads `MODULE ONLINE` with `TRANSIT  <n> LINKED` above `DEPART`.

Stores are earned at SR-7 (`docs/FREIGHT.md`). Veld's Gate, at 600, is about two full holds.

### The Core's Gate

The sixth Gate, beside the Sun Station. It is not a Module and never a transit destination.
Its terminal reads `CORE OFFLINE` and one row:

- Fewer than five Modules online: `POWER INSUFFICIENT  MODULES OFFLINE`, dimmed. It does not
  count them for the player.
- All five: `POWER CORE`, which does nothing yet (prints a placeholder; no state changes).

The endgame behind it is unbuilt. `test/SunStationTest.gd`.

Tests and playtests: `test/GateTest.gd`, `playtests/gate.play`, `playtests/gate_showcase.play`,
`playtests/gates_showcase.play`.

---

## 5. Transit

`scripts/GateTransit.gd`. The link exists only between Modules that are online.

- A powered Gate's `TRANSIT` view lists every **other powered Gate**, sorted sun outwards
  (TERRA-0 first, Veld last), labelled by planet. With one Gate powered it shows a dimmed
  `NO LINKED GATES` - the first Gate the player powers moves nobody anywhere.
- Taking one: the terminal closes, the screen cuts to black for 0.9 s, the ship is set down
  docked in the destination's berth, the game saves, and the screen wakes.
- **It costs nothing**: no fuel, hull, hold or Stores. The tree is never paused, so orbits,
  the encounter field and every Gate keep moving through the cut.
- The first transit gets UNIT-7's `first_transit` call (pausing, show-once).

`test/GateTransitTest.gd`, `playtests/transit.play`.

---

## 6. Titan Influence

**One integer, 0-5: the number of Modules online** - `GameState.titan_influence()`, which is
`Progress.count(POWERED_GATES)`. It changes only when a Gate is powered and never goes down.
Every "wrongness" effect reads it and nothing else, so a player can work out unaided that the
strange things started when they bought something. The Core is not step 6.

Built effects, all tuning in `scripts/TitanInfluence.gd`, none of it touching gameplay:

| Effect | Where | Rule |
|---|---|---|
| Dashboard floor | `ui/HudGlitch.gd` | baseline glitch `0.3 * influence / 5`; never reaches `ROT_THRESHOLD` (0.35), so readouts dim but never rot |
| Dashboard blinks | `ui/HudGlitch.gd` | a 0.2 s burst - panel tears 5 px sideways, flickers, text scrambles into Titan purple - every 12 s at 1 Module down to 2.5 s at 5, ±40% |
| The Guide's face | `ui/RadioPanel.gd`, `RobotView.titan_flash` | from 3 Modules, about every second UNIT-7 line flashes Titan purple for 0.05 s |
| Notes | `entities/Robot/CheerfulGuideNPC.tres` | UNIT-7's Record gains Notes at 0, 1, 3 and 5 (§9) |

The radio panel is never glitched: the robot is the one voice still telling the player what
to do. VFX draw from their own generators, never `RNG.rng`.

The dev panel's MODULES ONLINE row powers Gates in save-key order for free, which is the
preview path for every row above. `test/TitanInfluenceTest.gd`, `playtests/notes.play`.

---

## 7. The Minimap

`ui/minimap/Minimap.gd`. The ship's sonar, on the HUD from the first minute: radius 70 px,
**10,000 world units** of range, centred on the ship.

- A beam sweeps the scope every 5 s. Whatever it crosses is stamped as an **echo** where it
  was found and fades over 3 s to a floor; moving contacts leave stale returns behind.
- **Solid echoes** - Bodies, stations, Gates, hulls, scrap - are the same mustard smudge. Size
  is the only legend: a Body is a disc at 1.3x true scale, everything else is drawn to its
  world radius down to 2.2 px. Reading the scope is a skill.
- **Pings** - things that answer (Sections, the heard hauler) - send a hollow ring out when
  the beam crosses them.
- Stations are the one diamond (the Sun Station too).
- Some targets pin to the rim when out of range (derelicts, Sections, the hauler) so a bearing
  can always be found.
- Anything that becomes visible after the game has started rings out once on its first echo:
  a **discovery**.
- The nav target is a blue diamond around what it sits on, never swept; out of range it is a
  rim arrow (`docs/SWEEP.md` for tracking).
- The Void is hatched in red exactly as the Chart draws it (§11).

There are no labels and no `???` text anywhere on the scope. A **Gate does not appear at all**
until it is named (§10) - `GateMinimapTarget.is_minimap_visible()` - and since naming happens
at 1,000 px, a Gate is found by eye, then rings out as a discovery.

`test/MinimapSonarTest.gd`, `test/MinimapVoidTest.gd`, `playtests/minimap.play`.

---

## 8. The Chart

`ui/system_map/SystemMap.gd`, carried in the Log's MAP tab (`ui/log/MapTab.gd`). `M` opens the
Log straight onto it, or closes it.

**The Chart starts blank and is filled by powering Gates**
(`docs/adr/0002-chart-starts-blank-and-is-filled-by-gates.md`). The minimap covers "what is near
me"; the Chart is the Titan's own map of its body, handed over a region at a time.

- A new game's Chart holds **Rook, SR-7 and the Void**. Not Veld, not the orbit that carries
  Rook, not the sun.
- A region is **Charted** when its planet's Gate is in `POWERED_GATES`. A region is the planet,
  its orbit around the sun, its moons and their orbits, its station and orbit, and the Gate.
  Flying there, or naming the Gate, charts nothing.
- A newly Charted region **draws itself in** the next time the Chart opens: planet, orbit,
  moons, station, Gate, each 0.9 s with a 0.15 s stagger. A load takes every region already
  online as always held, so reveals are never replayed.
- Powered Gates are a purple ring glyph with the berth's mouth, labelled `<PLANET> GATE`, and
  **a line is drawn between every pair** of powered Gates: the network, as it grows.
- The sun is drawn only if its region is Charted, which nothing does - the middle of the Chart
  stays empty all game. The Sun Station and the Core's Gate are never drawn.
- The Void: red hatching from `EDGE_RADIUS` out, doubled past `DEEP_RADIUS`, one `THE VOID`
  label in the dark. The boundary breathes red while the ship is out there, and a `VOID`
  readout shows how far is left.
- **The ship's own marks** are drawn over uncharted space too: Freight it has let go of, and
  hulls abandoned with Freight clamped (`SystemMap.freight_marks`, `docs/FREIGHT.md`).

### Navigating it

| Key | Does |
|---|---|
| Arrows / LS | drive the **mark** at a steady 420 px/s; the view scrolls when it reaches the edge |
| `=` / `-`, triggers | zoom (1x fits the system, 25x default, 100x max), around the mark |
| `WASD` / RS | pan |
| `C` / Y | recenter on the ship |
| ENTER | **track** what the mark is on: a Charted Body, SR-7 (as HOME), or a powered Gate within 14 px snaps; anything else becomes a fixed waypoint |
| Del / Backspace / X | clear the tracking point |

An uncharted planet is bare space to the mark: it passes straight over it, and a waypoint can
still be dropped there. A readout shows zoom, ship position and mark in Mm, and the nav target
and its range.

`test/SystemMapTest.gd`, `playtests/chart.play`.

---

## 9. The Log and Records

`ui/log/LogUI.gd`. The player's own instrument, kept by the ship, not by the Titan. `I` opens
it; TAB / Shift+TAB (bumpers) cycle tabs; ESC closes. It does not pause the game. Tabs:
**SHIP** (gauges and hold manifest, `docs/FREIGHT.md`), **RECORDS**, **MAP** (§8). No
Automaton speaks from inside it.

### Records

`ui/log/RecordsTab.gd`. **One Record per Body the player has Visited and per Automaton they
have met. Nothing else** (`docs/adr/0003-the-log-lists-only-what-the-player-reached.md`): no
`? ? ?` rows, no counts. The row count itself would tell the player how many Bodies exist,
which is the spoiler the Chart protects.

- **Bodies.** `entities/Ship/PlanetLog.gd` marks a Body Visited the moment the ship enters its
  inner orbit (§2) - the deepest one if nested, so a moon wins inside its planet. Listed in
  visit order. The row and detail read `UNSURVEYED`: nothing surveys a Body in play
  (`PlanetScan.readout_lines` is ready for when something does; the sun reads honestly through
  it). The detail shows DESIGNATION, and ORBITS for a moon.
- **Automatons.** One today: UNIT-7, marked met on the first transmission that reaches the air
  (`RobotRadio._mark_guide_met`). Row: designation, station. Detail: designation, `STATION SR-7`,
  then its Notes.
- One cursor runs through both sections; one detail column on the right.
- Empty, the tab says only what earns a Record, never how many there are.

### Notes

A **Note** is one line of an Automaton's Record in the player's own voice, shown once Titan
Influence reaches its step (`NPCData.notes_at`). Absent until then - nothing stands in for
it. UNIT-7's four sour as the Modules come up:

| Influence | Note (abridged) |
|---|---|
| 0 | `UNIT-7 AT SR-7. WALKED ME THROUGH THE BEAM TWICE. GOOD VOICE TO HAVE OUT HERE.` |
| 1 | `FIRST GATE LIT. IT CHEERED, THEN IT THANKED ME. LIKE THE GATE WAS ITS.` |
| 3 | `ASKED WHAT THE MODULES DO. BEEP CAME OUT WRONG...` |
| 5 | `ALL FIVE LIT. PAUSED BEFORE IT SAID PILOT...` |

A Body's Record is instrument output; an Automaton's is a notebook. They share a column, not
a voice. `test/PlanetLogTest.gd`, `test/AutomatonRecordTest.gd`, `test/LogUITest.gd`,
`playtests/log.play`, `playtests/records.play`, `playtests/notes.play`.

---

## 10. Unidentified

`scripts/Identifiable.gd`. A find the player has never reached stays unnamed until UNIT-7 names
it on close approach: **1,000 px** (`Identifiable.RANGE`). The Guide never points at a find
beforehand - the bait has to be something the player believes they discovered.

- **Gates.** `Gate._watch_for_the_ship` names the Gate once the ship is in range (or on
  docking, for a ship that spawns in the berth). Marked in `IDENTIFIED_GATES`, written through
  at once. The `gate_identified` call ("that's an old transit gate... have a read of the
  terminal") is show-once per save, so only the first Gate gets a word; the rest flip
  silently. Naming puts the Gate on the minimap; it does not put it on the Chart.
- **The hauler on Veld** uses the same pattern (`IDENTIFIED_WRECKS`, `docs/OPENING.md`).

`playtests/gate_identify.play`.

---

## 11. The Void

`scripts/VoidZone.gd` (autoload). The dark past the last orbit. Nothing orbits, reflects or
answers out there. **There is no clock: depth decides everything.**

| | Distance from the sun |
|---|---|
| Veld's orbit | 253,125 (SR-7 swings out to about 295,000) |
| `EDGE_RADIUS` | 340,000 |
| `DEEP_RADIUS` | 360,000 - consumed |
| `RE_ENTRY_MARGIN` | must come back 4,000 inside the edge before the Void lets go |

- `depth` runs 0 at the edge to 1 at deep; `shroud` (what every effect reads) is the depth
  while the ship is flying or harvesting out there, and 0 when docked, dead or in a menu.
- Crossing the edge sends UNIT-7's `void_edge` warning, urgent and **every crossing**, not
  once. The margin keeps a ship skimming the boundary from retriggering it.
- The deeper, the worse: the starfield thins, `HudGlitch` and `VoidGlitch` (on the Log, its
  Chart and the tracker) rot text, wander and drop out in longer cuts, and `VoidShroud`
  (layer 40, over the HUD) closes in - pulling back to 35% over a full-screen instrument so
  one readable panel is left to steer out by.
- Loitering never kills. Turning back hands everything back at once.
- At `DEEP_RADIUS` the ship is **consumed** (`ConsumedState`): no blast, no wreck. The hull is
  simply gone, 2.4 s of silence, then game over "Consumed" and a garbled `void_consumed` call.
  A clamp lets go at the edge, so Freight is never lost out there (`docs/FREIGHT.md`).
  Relaunch is `docs/FLIGHT.md`.

`test/VoidZoneTest.gd`, `test/MinimapVoidTest.gd`, `playtests/void.play`.

---

## 12. What Persists

`scripts/Progress.gd` - the **Progress ledger**, owned by `GameState.progress`. Every fact the
player earns, by kind. A fact once marked holds for the rest of the save: there is no unmark.
Each mark writes through to the save file at once, because Visiting a Body or naming a Gate
happens in open flight with no dock to hang a save off.

| Kind | Key | Earned by |
|---|---|---|
| `visited_bodies` | `Planet.save_key()` | entering a Body's inner orbit |
| `identified_gates` | `Gate.save_key()` | coming within 1,000 px |
| `identified_wrecks` | wreck key | the same, for the hauler |
| `met_automatons` | `NPCData.record_key()` | the first transmission on air |
| `powered_gates` | `Gate.save_key()` | POWER GATE; its count is Titan Influence |
| `seated_sections`, `fitted_components`, `core_started` | | `docs/OPENING.md`, `docs/FREIGHT.md` |

Save keys are the node path from the sun: `Sun`, `Sun/Veld`, `Veld/Rook`. A Gate's key is its
planet's, so the Core's Gate is `Sun`. A new game is `progress.fresh()`; a continue is
`resumed()`. Adding a kind is one constant in `KINDS`. `test/ProgressTest.gd`.

---

## Known gaps

- **Gate naming is silent before the wake.** `RobotRadio.request` drops everything while
  `guide_awake` is false, so a Gate reached before SR-7's cold start is named with no word from
  the Guide; the show-once line then goes to the first Gate reached after the wake.
- **`first_transit` promises fuel the Gate does not give.** Its second line ("Sit in the cradle
  and the tank fills on the house") contradicts `GateTerminal`/`GateDockedState` and
  `test_a_gate_dock_does_not_refuel`.
- **Gates never show on the minimap by survey.** `GateMinimapTarget` also reveals a Gate once its
  planet is scanned, but nothing scans (`GameState.scanned_planets` is never marked in play), so
  every Gate stays off the scope until 1,000 px. `playtests/gate.play`'s comment still describes
  the scan path.
- **Stale comments.** `Gate.is_identified` says the minimap reads `? ? ?` (it shows nothing);
  `Gate` says naming lets "the chart name it" (the Chart draws only powered Gates);
  `void_edge.tres` says the Void "kills in thirty seconds" (there is no clock); `LogUI` says
  the Log opens on the Hold (the tab is SHIP).
- **`Gate.offers_transit()` is test-only.** Transit excludes the Core's Gate only because it can
  never be powered.
- **The Sun Station is a working port.** Its ports are open (`SpacePort.needs_core` false), so it
  deposits, tops up and shows a hub. Nothing marks it as the place that offers nothing.
