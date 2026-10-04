# RETROGRADE - Freight

Things too big for the hold, flown home on the nose, and what the station does with them.

The *system*: **Freight**, the clamp and the pull, SR-7's **Mounts** and **Cradle**,
**Components** and the **SHIP** screen, and the **Stores** the dock spends on the ship.
`docs/OPENING.md` places each Section and tells the Act 1 story around them. ADRs 0007, 0012,
0013 and 0014 are the decisions.

---

## 1. The Rule

**There is no store and no currency** (`docs/adr/0007-no-currency-upgrades-are-found-objects.md`).
An upgrade is a physical object found in the world and fitted at a station. A scrapper
finds a thing and bolts it on.

Two flows come out of that, and they never mix:

| Stream | Source | Refreshes | Pays for |
|---|---|---|---|
| Gems → **Stores** | Scrap, harvested with the Sweep (`docs/SWEEP.md`) | Yes | The trip: hull patch, fuel past the free half (§8) |
| **Components** | Found objects, carried home as Freight | **No** | The ship (§6) |

**The ring pays for the trip; found objects pay for the ship.** Only the first can be farmed,
and it buys nothing permanent. The ship's limits (`max_hull` 100, `max_fuel` 150) are fixed;
only fitting a Component changes the ship (`test/NoStoreTest.gd`).

---

## 2. Freight

Freight is anything too big for the hold: **clamped rigidly to the ship's nose** at its one
**Lug** and pushed home ahead of the ship like a barge
(`docs/adr/0012-freight-is-clamped-not-stowed.md`). It never enters the hold and never counts
against cargo. It is a physical category, not a purpose: a **Section** (§4) and a
**Component** (§6) are both Freight. `entities/freight/Freight.gd` is a `RigidBody2D`;
`entities/Ship/states/CarryingState.gd` is the ship while it holds one.

### The Lug

Every piece has exactly one Lug, drawn as a light flange across one end. The magnet always
seats the piece at it, so a load always sits the same way and handles the same way every
carry. Where the designer puts the Lug relative to the piece's Mount heading decides how
hard seating is. Scrap has no Lug, which is a quiet tell alongside answering a Sweep.

Any Freight answers a Sweep **at its Lug** (`Freight.sonar_point`): the Lug lights and pings
back a ring as strong as the one that reached it. A piece with an `answer_range` answers
from past the ring's own reach, fainter and broken the further off
(`Freight.long_answer_clarity`, down to 0.2 clarity at the edge).

### Clamping

Clamping is a hold, not a docking manoeuvre. Hold `action` with the nose within
**25 px** of a loose piece's Lug (`MAGNET_RANGE`) and a magnet draws it in and turns it
into its pose, at any approach angle or speed. Once pulling, it keeps hold out to 50 px
while the ship drifts. Let go of the key mid-pull and the piece stops, moving with the ship.
It clamps when it is within 3 px and 0.08 rad of its pose (`SEAT_DISTANCE`, `SEAT_ANGLE`),
with a clunk: a beat of hitstop, a burst, two rings, and the whole piece flashing cream.

Holding `action` is also the Sweep; a piece that answers a Sweep comes to the ship. Near a
harvestable scrap the harvest keeps the key (`FlyingState._update_magnet`).

| Magnet | Value |
|---|---|
| Reach to start | 25 px, nose to Lug |
| Keeps hold to | 50 px |
| Pull | gain 6/s, up to 160 px/s and 4 rad/s, never creeping the last few px |

### Carrying

While clamped, the piece is not a body of its own: `Ship.carry` folds its mass, outline and
inertia into the ship's (`Ship._combined`), and its outline becomes a collider on the ship.

- **Acceleration** falls with combined mass. The ship is 3.0; the full FUEL TANK (3.0)
  halves it. The cruise cap does not change: a loaded ship takes longer to reach it and to
  shed it, which makes the Burn worth more under load.
- **Turning** reads inertia. Target spin is `turn × turn_speed × ratio`, where `ratio` is the
  ship's own inertia over the combined inertia, softened by `Ship.FREIGHT_TURN_EXPONENT`
  (0.5, a square root: the honest ratio left a long piece all but unturnable). Spin eases
  toward the target over a wind-up of `2 × FlyingState.TURN_LAG × (1 − ratio)` (up to 0.6 s),
  so a heavy load turns sluggishly and carries the turn on after the key is up. Unladen,
  both reduce to the ship's ordinary turn exactly (`FlyingState.turned_spin`).
- **No nose drift.** Thrust acts through the combined centre of mass. A load off to one side
  makes the ship heavy, never lopsided; shape matters only through inertia, so a long piece
  turns far worse than a compact one of the same mass.

While carrying, `action` means one thing: **release**. A carrying ship cannot Sweep, dock,
harvest or touch down (`CarryingState.allows_sonar`, `_ground_contact`). One key, one meaning.

### Release

Release is a deliberate **0.8 s hold** of `action` (`CarryingState.RELEASE_HOLD`), anywhere,
so a tap never drops a load. The prompt is blank until the hold starts, then reads
`RELEASING ███···` as six cells fill. Where the load would go home if let go of now (its
Mount, or the Cradle), the prompt reads **RELEASE** before the hold starts.

Let go of, a piece **coasts**: the ship's velocity and heading at that moment, plus a nudge
of 6 px/s off the nose (`Ship.RELEASE_DRIFT`, so it does not read as still attached), no spin,
and no gravity. Its only drag is `Freight.DRAG`, 0.1% of its speed per second: too slight to
notice, but a piece let go of after a long Burn slows below cruise in time and can be caught.

### Knocks

Nudging Freight about is expected, so it is gentle on the hull.

- Bumping a **loose** piece only hurts above 250 px/s closing speed
  (`Freight.KNOCK_DAMAGE_SPEED`), against the ship's ordinary 50.
- A knock on a **clamped** load bounces the ship and never reaches the hull, against rocks,
  stations and scrap alike (`playtests/freight_scrap.play`).
- Loose Freight bounces off scrap and debris the way the ship does; scrap stays on its rails.

Beyond that Freight collides and nothing more: it cannot be destroyed and the clamp never
shears.

---

## 3. Buried Freight and the Pull

A piece can be **buried** in a planet's ground, Lug end up (`Freight.bury_in`). It draws
under the planet's disc, so only what sticks out shows. The magnet reaches it but cannot
lift it.

A hold of `action` at its Lug **couples** on: the nose closes onto the Lug with the clamp's
clunk, and stays coupled with the key let go. Flying away from the ground pulls at it
(`FlyingState.pull_force`): thrust along the outward line, as a share of the Aux's full
thrust, multiplied by `boost_power_multiplier` (2.667) while the Burn is lit.

- Past the piece's **pull threshold**, progress builds over its `pull_time`. Short of it,
  progress drains at 0.6 of that rate. The piece rises up to 18 px out of the ground as the
  pull builds, and never sinks back.
- Straining shakes the camera, trembles the piece and throws dust off the ground, harder
  the nearer the pull is to the threshold (`Freight.strain`, `GroundBreakFX`).
- Full, it **tears free**: a burst, a scar on the ground, a hard shake, and the magnet pulls
  it straight onto the nose without the key held.
- A fresh press while coupled lets go. Progress is not saved: a load starts the pull over.

A threshold **under 1** the Aux can beat; **over 1** only the Burn can. So a light piece on a
small moon teaches the verb on the Aux, and the same verb fails on a heavy piece until the
player spends fuel on it.

---

## 4. Sections and Mounts

A **Section** is one of SR-7's missing structural parts, recovered as Freight and released
into its own gap in the station's silhouette. Data in `entities/freight/Sections.gd`; the
place it goes is a **Mount** (`entities/structures/Mount.gd`), three of them in
`entities/structures/SpaceStation.tscn`. Where each one lies and why is `docs/OPENING.md`'s.

| Section | Mass | Outline | Lug | Starts | Pull threshold | Carry (approx.) |
|---|---|---|---|---|---|---|
| FUEL TANK | 3.0 | 126 × 46 capsule | middle of a flank: rides sideways | lodged, held in the station's frame | – | accel ×0.50, turn ×0.19 |
| SOLAR ARRAY | 1.0 | 146 × 46 panel | outer tip: swings like a lance | buried in Rook, Lug up | 0.6 (Aux), 1.3 s | accel ×0.75, turn ×0.17 |
| DORSAL ARM | 2.0 | 236 × 65, the arm folded | elbow end; goes in shoulder-first | adrift in Rook's debris ring, going round with it | – | accel ×0.60, turn ×0.09 |

Carry figures are combined-body ratios against the bare ship (3.0), from `Ship._combined`.
The DORSAL ARM, long and thin, is by far the worst to turn (`test/CradleTest.gd`,
`test_the_folded_arm_is_the_hardest_carry`).

The right solar wing is not Freight. It never came off: it hangs 50° out of true on its
hinge and is pushed home with the hull (`entities/structures/ArrayNudge.gd`). Pressed against
it and moving or thrusting so as to turn it back, the ship turns it, only ever toward true,
at most 35°/s; within 3° it swings home and locks with the Mount's clunk and the same seated
record (`Sections.SOLAR_ARRAY_2`).

### A missing Section is never lost

While a Mount is empty and no piece of its Section exists anywhere (a new game, or an old
save), the Mount puts one in the world (`Mount.ensure_section`). Until the magnet first
takes it, the piece is **lodged**: held at a fixed offset in its anchor's frame (the station,
or the planet), turning with a debris ring if it starts in one, so to the player it simply
hangs there. From then on it is ordinary Freight. A seated Section clears any stale copy.

Each unseated Section also shows as a faint ping on the minimap, held on the rim for a
bearing when out of range, and hidden while clamped (`ui/minimap/SectionMinimapTarget.gd`).

### The cut

The Mount shows **the cut, not the answer**. While empty, the station's polygon for the
part is hidden, its exposed pieces are cut out of the station's collision (a missing part
is not a wall), and each cut edge is drawn as it was left: a 3 px lip with a straight torch
line, emptied bolt holes every 10 px, beads of slag, two bracket stubs cut square, sparks,
and a red lamp on the hull behind the longest edge (`Mount._draw_cut_edge`,
`entities/structures/CutAlarm.gd`). Never a ghost outline, never a socket. A gap in a
silhouette does not read as a hole; a cut edge does. It is a *cut*, never a tear, because
SR-7 was taken apart, not broken.

The Mounts share the station's one hull, which is recut for every empty Mount at once
(`Mount.recut`).

### Seating

**The flying is the hard part; the last few pixels are free.**

- **One Section, one Mount.** Only the Section with the Mount's id fits.
- Released within **40 px and 30°** of a seat (`Mount.SEAT_RANGE`, `SEAT_ANGLE`), the Mount
  pulls it home over **0.5 s**, eased, with a clunk (sparks, two rings, a camera bump felt
  within 1500 px), and the polygon is the station again.
- **Any gap, either way round.** A part that shows in several places leaves several gaps,
  and each seats it; a piece fits turned end for end (`Mount.seats`).
- **Miss and nothing is lost.** Released elsewhere, the Section coasts on, still clampable. A
  bad approach bounces off the station and never damages it.
- Seating writes `Progress.SEATED_SECTIONS` to the save at once and drops the Freight row,
  then emits `EventBus.section_seated` (what the core and the dock's arm listen for,
  `docs/OPENING.md`).

---

## 5. The Cradle

The **Cradle** is where a Component delivered as Freight is let go of, to be fitted from
SHIP once docked. `entities/structures/Cradle.gd` is the contract (what it holds, fitting,
stowing); SR-7's one Cradle is a **drop bay worked by the DORSAL ARM**
(`entities/structures/dorsal_claw/DorsalClaw.gd`,
`docs/adr/0013-the-dorsal-arm-is-the-cradle.md`).

The arm is a knuckle boom on a turntable in the container strip, a claw on a free wrist.
Until the DORSAL ARM Section is seated there is no arm and nothing is taken; seated, it works
once SR-7's core is running (`DorsalClaw.is_working`).

1. **Approach.** Nothing on the strip lights until a ship carrying a Component is within
   450 px of the **drop point** off the right mast. Then two **glide slope lamps** on the mast
   light: both sage when level (within 30 px), the top one rust when too high, the bottom one
   rust when too low. A faint beam shines up out of the bay. The tracker reads `CRADLE`.
2. **Reach** (`ClawReaching`, 1.0 s). With the load's centre within **110 px** of the drop
   point, **at any angle**, and its free end (away from the ship) inside the arm's 400 px
   reach, the arm unfolds up and over, lines up 40 px out along the load and slides on and
   closes. The prompt reads RELEASE. If the load leaves the radius, the arm folds again.
3. **Let go** with the ordinary 0.8 s hold. The Component is the Cradle's at once:
   appended to `GameState.cradled` and saved (`Save.save_cradled`). If the claw had not got
   there yet, it is taken where it is.
4. **Deliver** (`ClawDelivering`). The arm lifts it clear of the mast (1.4 s swing), turns it
   level, Lug outboard, and sets it on the pad (0.8 s).
5. **Stow** (`ClawStowing`). The jaws open, the arm lifts clear and folds back upright, and the
   pad sinks 150 px below deck with the clunk. The pad comes back up empty 1.5 s later; until
   then the bay is busy.

**The Cradle is always open:** any number of Components can wait in it, oldest first. Only
the strip collides; the arm, crates and turntable are art. `refresh` on a load leaves the
arm folded and the bay empty, since anything mid-delivery is already in `cradled`.

`dev/claw_lab` (`tools/clawlab.sh`) is the bench the claw was tuned on: the real station
held still and whole, a Cargo Bay on the nose, the catch radius drawn, and every export live
in the remote inspector. It never touches the real save.

---

## 6. Components

A **Component** is a found object fitted to the ship at a station. Data in
`entities/freight/Components.gd`: each has a Freight form (outline, Lug, mass, how it lies in
the world) and a **fitted** form, cut down to what the ship needs. There is one so far.

### The Cargo Bay

The ship wakes with **no hold** (`Ship.max_cargo_weight` 0). Not a small one: none. No
cargo readout, nothing harvests, though a Sweep still lights scrap up. The **Cargo Bay** is
the first Component and ADR 0007's model case made literal: a hold too big to fit in the hold
you have, carried home handling badly.

It stands Lug-up between the broken halves of a crashed hauler on Veld
(`entities/structures/HaulerWreck.gd`, `HAULER, DOWN`).

| Cargo Bay | Value |
|---|---|
| Freight form | 116 × 60 box, mass **4.0** (heavier than any Section): accel ×0.43, turn ×0.13 |
| Lug | one short end |
| Buried | pull threshold **1.6** (the Aux tops out at 1.0, the Burn at 2.667), `pull_time` **4.25 s** |
| Answers a Sweep | not at all until SR-7's cold start; then from up to **5000 px** (`answer_range`) |
| Fitted form | 12 × 22 container strapped across the spine behind the cockpit, mass **+0.35** |
| Fitted gives | a hold of **50** (`Components.hold`) |

Torn free on the Burn, it lifts off Veld on the Aux. The dock's free half (§8) covers the
tear-out with room to spare.

### Fitted

A fitted Component is **part of the ship you fly**
(`docs/adr/0014-fitted-components-are-on-the-hull.md`): drawn on the hull, added to its mass,
and solid (`entities/Ship/FittedParts.gd`). `Ship.refit` rebuilds the parts from
`GameState.fitted()` on every fit, stow and load.

- **One place each.** Each Component names its `place` on the hull ("spine" for the Cargo
  Bay). The player chooses whether to fit it, never where. Fitting one where another sits
  sends the old one to the Cradle. Places are never shown empty.
- **Cut down.** The Cargo Bay is 116 × 60 as Freight against a hull of about 22 × 18; fitted
  whole the ship would be a cab pulling a box. The fitted form never reaches aft of the hull's
  tail (x −13), or the docked ship would sit in SR-7's port pad.
- **Heavy.** The fitted Cargo Bay keeps about 93% of the turn, and SHIP's handling bar drops
  from 8 segments to 7 (`test/ShipFittedTest.gd`).
- **Outlives the ship.** Fitted parts persist through loss and relaunch (the cloning bay
  prints the spec, ADR 0011). A derelict drawn from the hull keeps drawing them as dead
  metal (`test_an_abandoned_hull_keeps_drawing_its_parts`).
- **Saved as before.** `Progress.FITTED_COMPONENTS` is a ledger that never unmarks; what is
  on the hull is that, less anything waiting in the Cradle (`GameState.fitted`). Components
  are one of a kind, which makes that sound.
- A Component in the Cradle or fitted is never in the world again: the hauler leaves no
  copy (`HaulerWreck.ensure_cargo_bay`).

---

## 7. SHIP

Docked at SR-7, the hub (`ui/SpacePortDialogue.gd`) offers **SHIP** above **DEPART**, with
a count of Components waiting in the Cradle beside it and nothing when none are. Elsewhere
the only row is DEPART. There is nothing to buy.

SHIP widens the panel into `ui/ShipPage.gd`:

- A line drawing of the ship from above (`ui/ShipSchematic.gd`): mustard hull, fitted parts
  in cream, drawn from the same outlines the hull wears, so it cannot disagree with the ship.
- **S T A T U S**: HULL, FUEL, HOLD (only once there is one) and **HANDLING**, an
  eight-segment bar (turn × acceleration, `Ship.handling`), never a number.
- Rows: `FIT <X>` for each Component waiting, `STOW <X>` for each one on the hull, `BACK`.

**The row previews itself.** The cursor on `FIT <X>` blinks it in its place and shows the
change in STATUS (`- -> 50` for HOLD; segments lost shown in rust); on `STOW <X>` it dims it.
ENTER does it, with no confirm step. `Cradle.fit` runs `Ship.refit`, so the docked ship
gains the part behind the menu at the same moment, and the save is written at once.

Stowing is allowed even for the only hold: a ship with no hold is a state the game already
has. Fitting the Cargo Bay gets UNIT-7's word (`cargo_bay_fitted.tres`), and only then does
the cutting tutorial wait for the first scrap (`playtests/cargo_bay_lines.play`).

---

## 8. Stores and the Dock

Gems become SR-7's **Stores** (`GameState.stores`, shown on the HUD as `N ST`). Docking at
an open port (SR-7 with its core running, `SpacePort.is_open`) runs the dock's work in
`entities/Ship/states/LandedState.gd`, with no menu:

1. **The free half.** SR-7 tops the tank up to **half** (`Drive.FREE_FRACTION`) on every dock
   and every relaunch, never higher, and never drains a fuller tank. A dead SR-7 gives
   nothing. A full tank fills in 5 s, so the free half takes 2.5 s.
2. **The Deposit** (`entities/Ship/HoldDeposit.gd`). The hold empties into the port gem by
   gem, cheapest first so the big ones close it out, in arcs, within a 2.4 s launch window.
   The cargo readout drains as the Stores count rolls up. Taking off early banks the rest at
   once. A closed port takes no delivery: the hold keeps what it carries.
3. **Service.** Then Stores are spent on the ship: the **hull first** (3 ST a point, a whole
   hull in 3 s), then the **tank past the free half** (2 ST a point), as far as the Stores go
   (`Economy.REPAIR_COST_PER_POINT`, `REFUEL_COST_PER_POINT`). Out of Stores with the hull
   still open, nothing goes to the tank. Fractions are charged as whole Stores, never more
   than the Stores cover.

The hub's menu opens once the Deposit has played out. Relaunching costs nothing.

### Tuning

Checked by `test/EconomyTest.gd`, `playtests/cargo_bay.play` and `playtests/dock.play`.

| | Value | Where |
|---|---|---|
| Tank | 150 fuel; the Aux costs nothing, the Burn 6/s | `Drive.CAPACITY`, `scenes/Main.tscn` |
| Free half | 75 fuel on every dock or relaunch, never higher | `Drive.FREE_FRACTION` |
| Tear-out | 4.25 s past 1.6; about 29-30 fuel of Burn with the latch, about 20% of the tank | `Components`, measured |
| Low tank | 15% runs dry mid-pull and the ground holds; the Aux flies home for another half | measured |
| Ordinary gem | 6.85 ST in 1.11 hold units on average (GOOD rolls on plain scrap) | `GemData.ROLL_WEIGHTS` |
| Full hold | 50 units of ordinary gems, about 309 ST | `EconomyTest` |
| Fuel | 2 ST a point: a full tank from empty is 300 ST, the tank past half 150 ST | `Economy` |
| Hull | 3 ST a point: a whole hull is 300 ST, paid first | `Economy` |

So **one full hold of ordinary gems is about a full tank from empty**; a hold spent on a
badly holed hull goes mostly to the patch.

---

## 9. Freight Is Never Lost

A Section that cannot be recovered is a soft-lock, so nothing removes Freight from the world
but delivering it (`test/FreightNeverLostTest.gd`).

- **Saved where it is.** Every piece is saved with position, rotation, velocity, and whether
  it is clamped, lodged or buried (`Freight.to_row`, the `wreck/freight` save rows), and never
  respawns or despawns. Saved with a load clamped, the ship comes back in flight carrying it
  (`playtests/freight_reload.play`). Reloads never duplicate or lose a piece.
- **Lost with a load on.** A destroyed ship's load is let go of where it was lost and coasts
  on; the next clone comes up at home without it (`Ship.relaunch`).
- **The Void cannot take it.** A load stays clamped through the edge. When the dark takes the
  ship (`ConsumedState`, no wreck), the load turns up on the same bearing from the sun,
  **1000 px** (1 km on the HUD) inside the edge, at rest, marked and tracked. Loose Freight
  headed out is stopped 8 px inside the edge; a piece let go of past it stops where it is
  (`Freight.held_at_edge`, `playtests/freight_void.play`).
- **Handled Freight is marked and tracked.** Once the ship has clamped a piece and let go of
  it, it is drawn on the Chart as a hollow square with its label and becomes the tracked
  target at once, over a manual waypoint (`ui/system_map/SystemMap.gd`). Clamping it clears
  the mark and tracks its destination: the Section's `MOUNT`, the `CRADLE` drop point, or
  home for anything else. Delivering falls back to home. Freight never touched has no mark,
  so every first search is still a search. The marks are the ship's, not the Titan's: they
  draw over uncharted space (`playtests/freight_track.play`).

---

## 10. Testing

| What | Where |
|---|---|
| Magnet, clamp pose, turning under load, knocks, Lug answers | `test/FreightTest.gd`, `playtests/freight.play`, `playtests/freight_scrap.play` |
| Never lost: Void, saves, marks, drag | `test/FreightNeverLostTest.gd`, `playtests/freight_reload.play`, `freight_void.play`, `freight_track.play` |
| Mounts, the cut, seating, lodging | `test/MountTest.gd`, `test/ArrayNudgeTest.gd`, `test/SectionMinimapTargetTest.gd`, `playtests/restore_sr7.play` |
| The station's tanks and damage art | `test/StationTanksTest.gd` |
| The claw and the Cradle | `test/CradleTest.gd`, `playtests/cradle.play`, `dev/claw_lab` |
| The Cargo Bay: buried, answering, the pull | `playtests/cargo_bay.play`, `test/HaulerWreckMinimapTargetTest.gd` |
| Fitting, stowing, SHIP | `test/FitCargoBayTest.gd`, `test/ShipFittedTest.gd`, `playtests/cargo_bay_lines.play` |
| Stores, Deposit, service, no store | `test/StoresTest.gd`, `test/HoldDepositTest.gd`, `test/EconomyTest.gd`, `test/NoStoreTest.gd`, `playtests/dock.play` |

---

## Known gaps

- **Abandoning with a load is dormant.** `Ship.hand_over` and `DerelictShip.hold_freight`
  (a hull holding Freight damps to a stop; breaking it frees the load) exist and are tested,
  but nothing in the game abandons the ship, so only `scripts/Playtest.gd` reaches them.
- **The FUEL TANK's meter never moves.** `entities/structures/FuelGauge.gd` draws a level
  that nothing sets; it is waiting for fuel brought home that is not built.
- **The tank is "full" and "empty" at once.** `Sections.gd` gives the FUEL TANK its 3.0 mass
  because "fuel is heavy"; `FuelGauge.gd` and `StationTanksTest` say it comes home empty.
- **The Lug answers in purple.** `Freight.on_sonar_touched` lights the Lug in
  `Colors.TITAN`, which CLAUDE.md reserves for the Titan and Artifacts.
- **One Cradle, one Component.** `Cradle.find` returns the first Cradle in the tree, and
  only SR-7 has one; `Components.DATA` holds only the Cargo Bay, so place displacement
  (`Cradle.displaces`) has never had a second part to swap.
- **A pull's rise can stack across loads.** Pull progress resets on load by design, but the
  rise it had won is saved in `lodged_offset` while `Freight._risen` restarts at 0, so a
  reloaded piece can rise a further 18 px on the next pull (`Freight.pull`).
