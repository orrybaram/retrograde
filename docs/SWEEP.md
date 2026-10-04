# RETROGRADE - The Sweep

The ship's one always-available action, what answers it, and the loop it feeds: scrap,
harvesting, gems, the magnet and the hold. Also the tracker that points the ship at things.

Act 1's manual diagnostic and the wake are in `docs/OPENING.md`; Freight, the Cargo Bay,
Stores and the Deposit are in `docs/FREIGHT.md`; landing on a body is in `docs/FLIGHT.md`.

---

## 1. The Sweep

Letting go of `action` sends **one** ring out from the hull (`entities/Ship/SonarPulse.gd`).
A tap is an ordinary ring. Holding charges that one ring: every `CHARGE_TIME` held adds
another ordinary ring's reach, with no ceiling. Nothing says so but a faint glow at the hull
that brightens as the charge grows. The charged Sweep is left for the player to find.

| Constant | Value | Meaning |
|---|---|---|
| `END_RADIUS` | 280 px | Reach of a tap |
| `LIFETIME` | 1.0 s | How long a tap's ring lives |
| `CHARGE_TIME` | 1.5 s | Hold that adds one more tap's reach |
| `strength_for(h)` | `1 + h / 1.5` | Reach and lifetime both scale by this |
| `MAX_ALPHA` | 0.22 | The ring is faint, mustard (`Colors.PRIMARY`) |

The ring eases out (fast, then slowing). Rings already in flight finish on their own.

**Why one verb.** The game needs a way to touch the world that is neither a prompt (this
matters) nor scenery (this does not). The Sweep is an input the player already has, used for
something mundane, that turns out to address things it was never advertised against. There is
no vacuum field: holding `action` is the Sweep, and harvesting is what happens when it finds
something.

### Where it works

The ship's state decides (`ShipState.allows_sonar()`), and `Ship.wants_sonar()` also refuses
while a menu takes the key or the manual diagnostic holds `SWEEP` locked (`ControlLock`,
`docs/OPENING.md`).

| State | Sweep |
|---|---|
| `FlyingState` | Yes, except while coupled to, magnet-drawing or tugging Freight |
| `HarvestingState`, `PlanetLandedState` | Yes: the rings play under the harvest |
| `LandedState` (docked), `GateDockedState` | No: `action` is the port's or Gate's key |
| `CarryingState` | No: `action` releases the load (ADR 0012) |
| `DestroyedState`, `ConsumedState` | No |

A hold that began, or passed through, somewhere the Sweep is refused belongs to that thing:
any charge is dropped without a ring, and the rest of the hold is ignored until the key comes
up (`Ship._drive_sonar`). The hold that lets Freight go never fires a ring on release.

Tested by `test/SonarPulseTest.gd` and `playtests/sonar.play`.

---

## 2. What Answers

A ring does not touch everything it passes at launch. Each listener (group `sonar_listeners`,
with `sonar_point()` and `on_sonar_touched(strength)`) hears it the moment the ring's edge
actually arrives (`SonarPulse.time_to_reach`), so a far answer comes late. `EventBus.sonar_pulsed`
fires as the ring leaves.

| Listener | Answer |
|---|---|
| Scrap (`ScrapNode`) | Found, not answering: lights up, one cream ring (§3) |
| Freight Lug (`Freight`) | Titan-purple ring back; can answer from past the ring's reach, faint and broken (`docs/FREIGHT.md`) |
| SR-7's comm dish (`CommDish`) | Once powered and on the Sun, a great purple ping (`docs/OPENING.md`) |
| SR-7's core on standby (`CoreHousing`) | One dull ring off the hull; nothing when dead or running |

An answer is sent by `SonarEcho.answer_ping`: one ring from the thing answering, in the Titan's
purple, reaching `ANSWER_REACH` (0.5) of the ping that woke it and fading as slowly. A big
Sweep through a crowd of pieces comes back as a crowd of big rings. The colour is the point:
the things that answer are part of the Titan. Scrap is not, so scrap never answers in purple.

A Freight piece with `answer_clarity` can answer from beyond the ring: it hears it as the ring
dies, and its answer comes back as a broken ring (36 arcs, fewer drawn the fainter it is), on
its own generator so it never draws on `RNG.rng`.

`SonarPulse.sweep` distinguishes the ship's own Sweep from SR-7's dish pinging through the same
code: only a real Sweep calls `on_swept`, which tells UNIT-7 the ship has been shown scrap
(`EventBus.scrap_swept`, `RobotRadio.check_swept_scrap`).

---

## 3. Scrap and Debris

The home system has one debris ring, around **Rook** (`scenes/HomeSystem.tscn`,
`entities/resources/OrbitalRingSpawner.gd`):

| Export | Value |
|---|---|
| `max_resources` | 200 nodes |
| `debris_ratio` | 0.93 (186 debris, 14 scrap) |
| `inner_radius` / `outer_radius` | 800 / 2000 px beyond Rook's 1600 px radius |
| `density_gradient` | 1.814 (biased toward the inner edge) |
| `orbital_speed` | 10 (`angular_speed`: nearer in goes round faster) |

Nodes are spread evenly by angle with types shuffled, scaled 0.5-1.0, slowly spinning, and
drawn from `ResourceNodePool` (pooled, never freed).

**Debris** (`DebrisNode`) is a hazard and nothing else: no harvest, not on the minimap.
**Scrap** (`ScrapNode`, six shapes in `entities/resources/ScrapShapes/`) is what the ring is for.
Both collide the same way (`OrbitalNode._on_collision_area_entered`): above 50 px/s relative the
ship bounces off at 0.3 of its speed; above 150 px/s it takes `(speed - 150) * 0.5` hull damage.

### Scrap passes for debris

Until a Sweep ring reaches it, scrap is tinted down to `Colors.HULL_MID` (the debris colour),
its sparkles hidden, off the minimap, and it cannot be cut. A ring reaching it flashes it
(1.8x, settling over 0.6 s), fades its sparkles in, and sends one cream ring back
(`REVEAL_ECHO_RADIUS` 90 px over 1.0 s). From then until the pool reuses it, it stays lit.

This is what makes the ring a place to search rather than a place to vacuum: the scrap is
there, but only the Sweep shows which pieces. A hidden trophy does not pulse until found.
Sealed containers and derelict hulls (`ContainerNode`, `DerelictShip`) are never hidden: their
shape already says what they are (`docs/ENCOUNTERS.md`, `docs/FLIGHT.md`).

Tested by `test/ScrapRevealTest.gd`, `playtests/scrap_reveal.play`.

### Trophies

One scrap in ten rolls **trophy** (`RNG.rng`, on each spawn). A trophy breathes (a slow 1.15x
scale pulse) once found, takes five hits instead of three, gets the slower, tighter timing
(§4), and rolls better gems (§5).

### Refill

Docking at any space port, and a clone's relaunch, emit `EventBus.resources_refresh_requested`;
the spawner tops the ring back up to `max_resources` (`_on_resources_refresh_requested`). A
loaded save re-rolls the ring from scratch (`_on_planets_restored`). See §10 for a problem.

---

## 4. Harvesting

### Reach

`HarvestCone` is a circle of radius 60 px centred on the hull (the name is historical), so
scrap is reachable from any heading. Scrap in the cone offers `HARVEST` when all of these hold
(`ScrapInRangeState`):

- it has been revealed by a Sweep;
- relative speed to the scrap is under 100 px/s;
- the ship has a hold (`Ship.has_hold()`: a new game has none, `docs/OPENING.md`);
- the ship is not destroyed, landed on a body, or carrying Freight.

A full hold does **not** block harvesting: gems that do not fit wait in space (§6). Only the
nearest live revealed scrap answers a press, and while the ship is focused on one scrap only
that scrap does.

A harvest starts on a fresh **press** (`is_action_just_pressed`); the cut continues on the
held key. A player already holding a Sweep who drifts into range does not start cutting until
they let go and press again. The same guard keeps a sweeping ship from docking by accident.

### The cut

Hold `action` and a marker sweeps an `E X T R A C T` bar under the ship (`ui/HarvestMeter.gd`,
150x10 px, 46 px below the hull). Let go to grade the hit (`entities/resources/HarvestTiming.gd`):

| Release | Grade | Result |
|---|---|---|
| Before the zone | `EARLY` | Not a hit. Progress kept, decaying 0.35/s while the key is up |
| In the zone | `GOOD` (`C L E A N`) | Hit, normal rolls |
| In the zone's centre 34% | `PERFECT` | Hit, better rolls, bigger payoff |
| After the zone | `LATE` (`T O O   L A T E`) | Hit, shards only |
| Held to the end of the bar | `OVERLOAD` | Hit, shards only, fires without letting go |

| | Normal | Trophy |
|---|---|---|
| Bar time | 1.6 s | 2.0 s |
| Zone width | 0.20 of the bar | 0.13 |
| Hits to break | 3 | 5 |

The zone always lands in the right half of the bar (start 0.5 to `0.92 - width`), somewhere new
for every hit, from an unseeded session generator (different between runs). Botched timing
still counts as a hit: the scrap does not hand out free retries. Flying out of range forfeits
any partial progress (`ScrapIdleState`). The final hit adds `B R E A K` to the grade text.

### Focus

The first press puts the ship in `HarvestingState` focused on that scrap until it breaks or the
ship leaves the cone. The camera zooms to 1.5x and stays zoomed across hits; the ship's velocity
eases onto the scrap's orbit over 2.0 s. Any stick input releases the lock (the ship flies
normally, still focused); pressing on the scrap again re-engages. After the break the zoom
lingers 0.8 s so the burst and pickup read.

### Payoff

Each hit throws its gems out of the scrap (§5) and plays `HarvestJuice`, scaled by the best gem
in the hit:

| Best gem | Hitstop | Burst | Shake |
|---|---|---|---|
| Shard | 0 | 0.5 | 0.5 |
| Gem | 0.03 s | 0.8 | 0.9 |
| Crystal | 0.07 s | 1.4 | 1.6 |
| Artifact | 0.14 s | 2.4 | 3.0 |

PERFECT adds 0.05 s hitstop and a shockwave ring; the final break adds 0.04 s, 1.6x burst and
a wider ring. A botched hit shakes at 0.6 and throws a small `Colors.DANGER` ring.

Iterate with `playtests/harvest.play`; logic in `test/HarvestTimingTest.gd`.

---

## 5. Gems

Gems are what harvesting knocks loose (`scripts/GemData.gd`). Banked at a port, each is worth
its value in **Stores** (ST).

| Tier | Value (ST) | Hold space | Colour |
|---|---|---|---|
| Shard | 2 | 1 | `Colors.GEM_SHARD` |
| Gem | 8 | 1 | `Colors.GEM_GEM` |
| Crystal | 25 | 2 | `Colors.GEM_CRYSTAL` |
| Artifact | 100 | 3 | `Colors.GEM_ARTIFACT` |

### Drops per hit

| Source | Chip (not final) | Break (final) | PERFECT bonus |
|---|---|---|---|
| Scrap | 1-3 gems | 5-8 (+3 trophy) | +1 chip / +2 break |
| Ore seam | 2-4 | 6-9 | +1 chip / +2 break, and the best gem bumped one tier |

Roll weights, Shard / Gem / Crystal / Artifact:

| Roll | Weights |
|---|---|
| Scrap, GOOD | 60 / 30 / 9 / 1 |
| Scrap, PERFECT | 25 / 45 / 24 / 6 |
| Trophy, GOOD | 0 / 50 / 35 / 15 |
| Trophy, PERFECT | best of two trophy rolls |
| Seam | 25 / 50 / 23 / 2 |
| Rich seam (moon) | 0 / 45 / 45 / 10; PERFECT takes best of two |
| Any LATE / OVERLOAD | shards only |

Scrap is the trickle; a seam is the payday (`test/OreHarvestTest.gd` asserts it).

### Loose gems

A hit throws its gems out evenly around the source with jitter (`Gem.burst`): 30-70 px/s for a
chip, 60-140 for a break, damping back to the source's orbital drift. A loose gem lives 30 s,
blinks its last 5 s, and is gone. At most 300 gems exist; the oldest loose one is evicted first.

---

## 6. The Magnet and the Hold

`GemMagnet` is a small field on the ship (`entities/Ship/GemMagnet.gd`): gems within 70 px are
pulled in, 170 px/s closing speed up close falling to 35 at the edge, and collected on touching
the hull (14 px). Pulled gems streak. A gem that would not fit in the hold is ignored and keeps
floating until there is room or it expires; a full hold leaves the big gems out before the
small ones. The magnet is off while docked and while the ship is gone.

Collected gems pop as `+N` over the ship in their tier colour, batched over 0.35 s
(`scripts/ResourceManager.gd`); the HUD cargo readout punches.

The **hold** is `InventoryManager`: gem counts keyed by id, weighed in hold space. A new game's
ship has none (`max_cargo_weight` 0); the readouts stay hidden and nothing harvests until the
**Cargo Bay** Component is fitted, which gives 50 units (`Components.hold`, `docs/FREIGHT.md`).
UNIT-7 names the need when a Sweep finds scrap with no hold, and speaks up once when the hold
first fills (`RobotRadio.check_swept_scrap`, `check_cargo`). Tested by `test/EmptyHoldTest.gd`.

Docked at a port someone runs, the hold is **Deposited**: gems leave one at a time, cheapest
first, arc into the port, and count up as Stores (`HoldDeposit`, 2.4 s window). What Stores buy
is in `docs/FREIGHT.md`.

### Loss

When the ship is destroyed, 70% of each gem tier in the hold (rounded) spills out at the wreck
(`GemData.wreck_drops`, `DestroyedState`). Wreck gems never expire, survive the relaunch, are
saved (`Save`, section `wreck`) and can be flown back to and collected. The next clone starts
with an empty hold. `playtests/wreck.play`; magnet in `playtests/magnet.play`.

---

## 7. Ore Seams (dormant)

Built, tested, and not in play: a seam only surfaces once its body has been surveyed
(`Planet.is_scanned()`), and nothing surveys a body now. `GameState.scanned_planets` stays empty
and is not saved. Playtests survey by hand (`playtests/ores.play`, `seam.play`, `regrow.play`).

- **Where.** Every body grows its own (`Planet._spawn_ore`): 6-8 on a planet, 3-4 **rich** ones
  on a moon, none on the sun or a gas giant. Seeded from the body's save key, so the same seams
  sit in the same places every session, spaced so one landing reaches one seam.
- **What.** A few rough rock chunks 22-110 px under the surface (`OreDeposit`), mixed with the
  crust's own colour, mustard mineral flecks. Not a glowing marker: part of the crust that has to
  be broken apart. Shown on the minimap and trackable (`OreTrackingTarget`, label `ORE`).
- **Working it.** Land on the plain surface within `REACH` (150 px along the surface) of a seam
  (`PlanetLandedState`, `docs/FLIGHT.md`). `action` runs the same `HarvestTiming` cut as scrap;
  the seam owns the timing and its hits. 3 hits break a plain seam, 5 a rich one (with the
  trophy timing). Gems always come out as a gentle chip burst so the magnet catches them.
- **Lifting off** mid-seam keeps everything already knocked loose and leaves the rest standing.
- **Depletion.** The chunks crumble shallowest-first as hits land, throwing splinters and dust
  on the seam's own generator (never `RNG.rng`). The last hit spends it: it leaves the view, the
  minimap and the tracker, and the key offers `SEAM SPENT`.
- **Refill.** 300 s of play (450 s rich), ticked by `GameState` on play time only, never shown
  as a clock. Timers save with the game (`Save.save_ore_regrowth`); a new game refills all.

Tests: `test/OreDepositTest.gd`, `OreHarvestTest.gd`, `OreDepletionTest.gd`, `TouchdownTest.gd`.

---

## 8. Resonance and Procedures (built, dormant)

The Sweep is meant to become a language: hold lengths read as **Marks** in six **Slots**, a
sequence of them a **Procedure** that hardware answers. The machinery is built
(`entities/Ship/Resonance.gd`, `ui/ResonanceMeter.gd`, `ui/PlacardPanel.gd`,
`entities/procedure/ProcedureDef.gd`) and tested (`test/ProcedureTest.gd`), but nothing listens:
no node joins `procedure_listeners`, so in play no bar shows and no Mark is ever laid. SR-7's core
is rebooted from the dock's console instead (`CoreTerminal`, `docs/OPENING.md` §6;
`test/CoreHousingTest.gd` asserts it is off the Procedure), and Gates are powered with Stores.

How it works when something does listen:

- **Reach.** `Resonance.available_for(ship)`: flying free, within `REACH` (520 px) of a
  listener whose `listens()` is true.
- **Marks.** The bar is `BAR_TIME` (1.6 s, the harvest bar's length) cut into six Slots
  (~0.27 s each). The Slot the key comes up in is the Mark; a tap is Slot 1.
- **Commit.** Held past the end of the bar (`O V E R D R I V E`), the release is the Commit: it
  carries every Mark out on that ring to listeners with `on_procedure(marks)`. A Commit is a
  1.6 s charge, so its ring reaches past `REACH` and always arrives.
- **Chaining.** Marks chain while each press comes within `CHAIN_WINDOW` (1.2 s) of the last
  release; let it lapse, or leave reach, and they fall off the bar. The window does not run
  while the key is held.
- **The bar draws the diagram.** `R E S O N A N C E` over six Slot ticks, where the harvest bar
  sits; under it, one row per Mark with a dot in its Slot - the same rows printed on the placard.
  Copying a printed Procedure is verifiable as you play it.
- **The placard.** `PlacardPanel` shows a listener's `placard()` beside it as the ship closes in,
  rendered from the Procedure's own steps so the documentation cannot drift from what the
  hardware wants: a dot grid, a placeholder glyph column (`<seat>`, `-1`), and
  `OVERDRIVE TO COMMIT`. The dots are the part to copy; the glyphs are the optional channel.
- **The words.** A word is an Operation (odd Mark) and its Argument (even Mark). The six
  Operations, by Slot (`ProcedureDef.OPERATIONS`): `SEAT`, `CYCLE`, `PURGE`, `INDEX`, `ECHO`,
  `LOCKOUT`. The one Procedure on disk is `sr7_core.tres`: SR-7 / CORE, COLD START, `SEAT·1
  CYCLE·1`.
- **Checking.** `ProcedureDef.check()` reports whether a sequence matches and, if not, how many
  Marks are in their right place - a count, never which - and whether a word is missing its
  argument. Nothing consumes it yet.

The research on printing a timed pulse rhythm is `docs/research/NOTATION-PRIOR-ART.md`.

---

## 9. Tracking

The player tracks **one** target at a time (`scripts/NavSystem.gd`, a `Tracker` holding a
`TrackingTarget`). Nothing is tracked until the player asks: a tracker that always points
somewhere is a marker the player never chose.

- **Setting it.** On the Chart, ENTER hands the mark to the tracker: a body under it is tracked
  as that body (riding its orbit; SR-7 as `HOME`), bare space as a fixed `WAYPOINT`. The clear
  key drops it (`ui/system_map/SystemMap.gd`; the Chart itself is `docs/WORLD.md`).
- **Set for you.** Clamping Freight tracks where it goes home to; letting it go, losing it, or
  abandoning a hull with it on the nose tracks what was left behind; seating it at its Mount or
  Cradle clears the target (`Ship.gd`, `DerelictShip.gd`, `docs/FREIGHT.md`). Landing on a seam
  clears a seam target.
- **Clearing.** A waypoint is done once the ship is inside its arrival radius (80 px). Bodies,
  stations and Freight stay tracked until something else is. A target that stops existing drops.

The HUD guide (`ui/tracking/TrackingIndicator.gd`, `Colors.NAV`): on screen, a diamond over the
target with its name and distance; off screen, a chevron on the screen edge with a small readout:

```
HOME  4.2 km
+38 m/s          (closing; - receding; HOLD under 2 m/s)
DRIFT 12 m/s     (sideways)
```

Distances read in m under 1000, km above. The chevron and readout slide out from under HUD
panels, hide inside the arrival radius, and glitch with the rest of the HUD in the Void. The
maths is `TrackingSolution`, pure and shared. `test/TrackingTest.gd`, `playtests/tracking.play`,
`playtests/waypoint.play`.

---

## 10. Known gaps

- **The ring runs out of scrap.** Refill spawns the missing count at `debris_ratio` (0.93), but
  only scrap ever goes missing, so harvested scrap comes back mostly as debris: clear all 14 and
  a dock refills 13 debris and 1 scrap (`OrbitalRingSpawner._on_resources_refresh_requested`).
  Only a reload restores the mix.
- **Resonance is dormant.** Nothing joins `procedure_listeners`; `ResonanceMeter` and
  `PlacardPanel` are still added to the HUD (`ui/HUD.gd`) and never draw. `ProcedureDef.check`
  has no caller.
- **Seams are dormant.** No survey exists, so no seam surfaces in play and nothing outside
  playtests ever tracks one (`GameState.scanned_planets`, `OreDeposit`).
- **`HarvestTiming` says overload makes "Slag".** There is no Slag item; LATE and OVERLOAD
  roll shards (`GemData.roll`).
- **`Ship.is_locked_to_planet()`** is true while docked (`LandedState`), not landed on a body;
  the magnet uses it to switch off at port.
