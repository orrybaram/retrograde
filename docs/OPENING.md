# RETROGRADE - The Opening

Act 1 as built: alone at a dead station, the repair of it from its own debris, and the
first thing the player ever switches on. Then the first Component.

The decisions behind it are ADR 0009 (the game opens alone) and ADR 0008 (UNIT-7 is a
sincere fragment). The mechanics it runs on live elsewhere: Freight, Mounts, the Cradle,
Components and Stores in `docs/FREIGHT.md`; the Sweep in `docs/SWEEP.md`; the drives and
fuel in `docs/FLIGHT.md`. This document owns the beats, the placements, the words and the
pacing.

---

## 1. The Shape

**Act 1 is the repair of SR-7 from its own debris.** Three Sections fetched, one wing
pushed home, one core woken.

It is not a tutorial for the game. It is the game, performed once on a building instead of
on a ship, before the player knows it is a mechanic:

> Find pieces. Bring them home. Something switches on and is glad.

That is Act 1. It is also every Gate, every Module, and the Core. The player learns the
game's only gesture on the one target where it is unambiguously good — fixing your own
house has no downside — and is therefore trained, by a genuinely benign example, to
perform it on everything else. **The con is self-administered.**

In play order:

1. A record typed on a dark screen (§3).
2. The ship adrift outside a dead SR-7, its controls locked (§3, §4).
3. The ship's manual diagnostic hands the controls back one system at a time (§4).
4. Three Sections fetched and seated, the hanging wing pushed home (§5).
5. The core comes to standby, the dock runs out, the console reboots the core, the power
   comes up (§6).
6. UNIT-7 comes on the comms (§7).
7. The dock opens (§8), and the first thing to go and get is a hold (§9).

There is no clock anywhere in it. The Aux never runs out (ADR 0010), so nothing drains and
nothing urges; a lost player is pointed, not hurried (§10).

## 2. SR-7

`entities/structures/SpaceStation.tscn`, parented to **Rook** in `scenes/HomeSystem.tscn`
alongside Rook's `OrbitalRingSpawner`, 6000 px out. It is a kit of named polygons under
`Visuals`, so a missing part is a hidden polygon and a repair is one appearing. **The
silhouette of the player's house is the progress bar** — no UI, legible from across the
orbit.

Top to bottom: twin masts (`Mast1`, `Mast2`); the container strip (`Deck`) with the
**DORSAL ARM**'s turntable (`Turntable`) and the Cradle's bay (`docs/FREIGHT.md`); eight
ring pods; the three-module arm block flanked by radiator fans; the hub; the core
(`CentralCore`, §6) with a long tank either side — the left one blown out, the right one the
**FUEL TANK** Section; the refuel boom and dock (`DockArm`, §6); the belly module; and the
truss keel carrying two solar wings, the left one the **SOLAR ARRAY** Section, the right one
still on its hinge (`ArrayNudge`, §5). The comm dish hangs below the keel (`CommDish`).

Sections are the clean, machined pieces. Everything else is weathered: `HullDamage` lays
soot, scorch, punctures, dents, missing plates and a few tumbling chunks over the hull from
a fixed seed (347), leaving the Sections and the core's bay clean. None of it is ever
repaired — the cold start brings the lights back, not the paint. The left tank
(`TankBreach`) has a ragged hole in its outer face and bleeds a thin sputtering stream of
vapour forever; it is never fixed, because the tank that feeds the dock is the other one.

### Why it is broken

**Never stated. Only clued.** A previous clone worked out what the cycle is and tried to end
it by taking SR-7 apart. Nothing in the game says so. What is built that is consistent with
it:

- **Cut, not torn.** Every Mount is drawn as a clean torch line: a lip of plate, empty bolt
  holes every 10 px, a bead of slag every third hole, squared bracket stubs (`Mount._draw`).
  No ghost outline, no socket. A gap in a silhouette does not read as a hole; a cut edge
  does.
- **The tank that feeds the dock went first.** No clone could refuel and fly out to do what
  the player is about to do.
- **The core's slots sit out of true** (`CoreHousing.SLOT_KINK`), the way a panel refitted
  in a hurry sits. The cold start does not straighten them, and nothing else does.
- **The right wing** hangs 50° out of true off its hinge, not thrown clear. They ran out of
  time, or were stopped.
- **`0 CYCLES SINCE EVENT`** — the first thing the game says (§3). The event was not an
  accident, and it has only just happened.

Because the game is top-down, the station's interior is legible from outside. The player
never enters and never stops being the ship.

## 3. Waking Adrift

### The record

Only **New Game** opens on the intro (`ui/IntroScreen.gd`): three lines typed close up on a
screen near enough to show its scanlines, a block cursor blinking before each, the picture
creeping 3.5% closer as it plays.

```
KSD-78 SYSTEM, OUTER REGION.
0 CYCLES SINCE EVENT.
ALL FUNCTIONS CRITICAL.
```

Where you are, that something has just happened, and that everything is failing — in the
flat voice of a record nobody signs. It never says what happened and never mentions the
player. It holds on the finished text until ENTER (a first press finishes the typing;
`PRESS ENTER` fades in dim a second after). `playtests/intro.play`.

### The dark

No boot terminal: that is the ship's computer coming up on a powered station
(`ui/LoadingScreen.gd`), and SR-7 is dead. The intro hands straight to black, held 0.8 s,
then the world fades up over 1.8 s (`Main.WAKE_BLACK_HOLD`, `WAKE_FADE_TIME`). The new game
runs through `Session.new_game()`: world reset, UNIT-7 off (`RobotRadio.guide_awake =
false`), ship reset to an empty tank and no hold.

### Adrift

The ship wakes **adrift below and out past SR-7's belly** (`ShipSpawner.spawn_adrift`,
`ADRIFT_OFFSET` (700, 1100) in the station's frame): the station just off the top of the
screen, Rook's debris ring (2400 px off the station at its nearest) out of view, the FUEL
TANK in view ahead. It is turning slowly over (0.32 rad/s, `Ship.drift_spin`) and drifting
off the station at a few px/s, among 42 flakes of fine debris that spread and are gone
within two minutes (`WakeDrift`, 120 s, fading over the last 40). Touching a turn key stops
the tumble at once.

Where the dock should be there is nothing: the boom is run in, back inside the belly
(`DockArm`, `SpacePort.deployed` false), so nothing offers DOCK. A relaunch or a load
before the station is whole wakes the ship in the same place without the debris
(`ShipSpawner.spawn_home`).

Nothing is on the comms. UNIT-7 is off until the wake (§7); every radio call is dropped
until then, so the game opens in silence.

### What the station says

There is no damage report and no parts list. **The station says what is wrong by how it
looks:**

- **No power.** Every window and beacon is dark (`StationLights`, `StationPower`). The
  power comes from the core, and the core only reboots once every piece is home. The wings
  are pieces like the others, not a switch.
- **The dish hangs limp.** No drive: bowl down at 115°, swaying ±4° on its post
  (`CommDish`).
- **Every wound is alarmed.** At each empty Mount, and at the hanging wing's hinge, the
  severed lines spit sparks and a red emergency lamp pulses on a 2.8 s cycle, never fully
  out (`CutAlarm`). Each stops as its piece goes home, so **the alarms are the to-do list.**
  They are the only red on SR-7 (`Colors.DANGER`), and they are out of step with each other
  so the station never flashes like one sign.

Four wounds and a dark dish are the objective, with zero instruction.

## 4. The Manual Diagnostic

The ship's own boot text, in flight (`ui/BootLog.gd` draws `scripts/BootChecklist.gd`;
`scripts/ControlLock.gd` holds the controls). New game only, never saved, and a continue
never shows it. `playtests/boot_log.play`.

**The controls are locked from the new game's first frame** (`BootLog.prepare`), through
the intro's dark and the wake, so the fade from black is not a window to fly in. 1.2 s into
flight the log starts typing into the HUD's bottom-right corner, growing upward, in bare
terminal text with no frame (above UNIT-7's panel when that is up):

```
MANUAL DIAGNOSTIC
CTRL AUTH ................. SYSTEM

PROPULSION
THRUST ....... [UP]          [ OK ]
REVERSE ...... [DOWN]        [ -- ]
YAW .......... [LEFT][RIGHT] [ -- ]
```

A flight-computer readout, no sentences. Headings name the hardware under test, rows the
control that exercises it. Each section's controls come back the moment its heading has
typed. Each row stamps `[ OK ]` the first time the pilot uses it (YAW and STRAFE need both
ways), so **the controls are taught as a checklist the player ticks off, not as popups.**

| Section | Opens when | Gives back | Row(s) |
|---|---|---|---|
| PROPULSION | 1.2 s after control | thrust, reverse, turn | THRUST, REVERSE, YAW |
| SONAR | a loose piece's Lug within 360 px (a tapped Sweep's 280 + 80) | the Sweep | SWEEP; a Sweep that reaches Freight adds `CONTACT ... FREIGHT` |
| CLAMP | the nose within 50 px of a Lug | the clamp | ENGAGE (HOLD; the stamp fills as the magnet pulls) |
| RCS | 2.4 s after the pickup | strafe | STRAFE |
| CLAMP RELEASE | a carried Section within 150 px of a seat | the let-go | RELEASE (HOLD; seating also passes it) |

A section whose rows are all OK clears 2 s later, and its name joins a list of passes under
the header (`PROPULSION ..... [ OK ]`), so the log only holds what is still to do. A row left
waiting more than 7 s flickers now and then; nothing else nags. Later sections unfold only
when their moment comes, so the log never tells the player the shape of Act 1 before they
have seen a tank. With all five cleared it prints `DIAGNOSTIC ... PASS` and
`CTRL AUTH ... PILOT`, holds 3.5 s, and fades for good.

While CTRL AUTH is the system's, thrust is held to 50 px/s **relative to SR-7**
(`ControlLock.SYSTEM_SPEED`; the frame the station, the tank and its Mount all move in), and
the Burn is held off. Finishing, a load, a new game or a quit clears every lock and the cap,
so none can outlive the log. A ship lost mid-diagnostic relaunches locked where it left off:
the passed sections come back passed, the rest run again from their triggers. One lost after
it passed brings nothing back.

It never names a place or a goal — only the ship's own controls.

## 5. The Three Sections

Each Section is Freight (`docs/FREIGHT.md`): clamped by its Lug, carried home rigid on the
nose with its mass dragging the handling, and **released into its own gap in the
silhouette** — not docked, not fitted from a menu, flown into the hole. Only the Section with
the Mount's id fits, either way round; the flying is the hard part and the last few pixels
are free (seat tolerance and the clunk are in `docs/FREIGHT.md`). Data in
`entities/freight/Sections.gd`; placement on each `Mount` node in `SpaceStation.tscn`.

| Section | Mass (ship is 3.0) | Lug | Where a new game leaves it |
|---|---|---|---|
| FUEL TANK | 3.0 — full, fuel is heavy | middle of its flank; goes in sideways from the boom side | adrift, keeping pace with SR-7 at (1300, 1080) in the station's frame: about 600 px right of where the ship wakes, in view, well clear of the ring |
| DORSAL ARM | 2.0 | elbow end; goes in shoulder-first onto the turntable | adrift in Rook's debris ring, 3000 px from Rook, going round at the ring's own speed for that distance (`Mount.start_in_orbit`) — caught up with, not flown to |
| SOLAR ARRAY | 1.0 — light but long, swings like a lance | outer tip | buried in Rook's ground on its sunlit face, 62 px of it standing out, Lug end up (`Mount.start_buried`) |

Nearest first: the tank is the first thing found by simply flying out; the arm teaches that
the ring moves; the array teaches the pull.

**The array's pull.** The magnet couples onto its Lug but cannot lift it. The ship clamps
and flies away from the ground: short of the pull threshold it only strains (the ground
shudders and throws dust); held past it, it tears free in a burst of dust, rock and sparks
(`Freight.pull`, `GroundBreakFX`). The array's threshold is the default 0.6 of the Aux's full
thrust, so the Aux does it. The same verb fails on Veld (§9).

**The fourth wound.** The right wing is not Freight and is never clamped (`ArrayNudge`). It
hangs 50° out of true, swaying ±2.5°. Pressed against it with the hull (within 16 px) and
moving or thrusting so as to turn it back, the wing turns, no faster than 35°/s and only
ever toward true; within 3° it swings home and locks with the seating clunk.

**Finding them.** Every Section hangs dead in its frame until the magnet first takes it.
Each answers a Sweep that reaches its Lug with a ping in the Titan's purple
(`Freight.on_sonar_touched`) — **things that answer are part of something; scrap is not.**
On the minimap each missing Section is a ping held on the rim, giving its bearing from the
first frame (`ui/minimap/SectionMinimapTarget.gd`); it goes while the piece is clamped and
for good once it is seated.

A Section is never lost: while its Mount is empty and no piece of it exists, `Mount.ensure_section`
puts one back where a new game leaves it. Seated state is the ledger's
`Progress.SEATED_SECTIONS` and survives reloads. `playtests/restore_sr7.play`.

## 6. The Wake

### Standby

The last piece home and the station is whole (`GameState.station_whole`: three Sections and
the wing). The alarms are quiet and SR-7 is still dark. Then, 0.8 s after the last clunk,
the core's **auxiliary lighting** comes up and catches with the same stutter as every other
light on SR-7: two strips along the lip of its bay, the only light on the station until the
wake (`CoreHousing`).

There is no standby lamp and nothing blinks. A blinking dot is a marker, and it collides with
`CutAlarm` — the player has spent the act learning that a pulsing light is a wound. Service
lighting is not addressed to the player at all: a panel at standby has lit its own working
area, and would have whether anybody was watching or not. It also explains itself on a
station with no power: the core is running the strips off its own battery.

**What the core is.** Not a component in a housing — no disc, no rotor. It is a recessed bay
of window slots set in ordinary hull, drawn exactly as `StationLights` draws every window on
SR-7: four slots, then a fifth, wider and set apart, the row permanently out of true. The
strips light the recess around the slots, barely (`BAY_WASH` 0.05), so the dark slots read as
five faint notches. On standby a Sweep that reaches it gets a dull ring back; dead or running,
nothing.

### The arm comes out

On the same battery, 2.2 s after the last piece goes home, **the dock's arm runs out**
(`DockArm`). It unlatches with the seating clunk where the boom leaves the belly, shudders
10 px, telescopes out along its track over 3.4 s and locks with another clunk at the head.
Half a second later the dock's lamps catch and blink: the first light on SR-7 that is
addressed to the player, and it says only *here*.

The arm's track is a mask the boom slides out through, so it emerges from the hull rather than
appearing over it. Whether it is out is the world's state — station whole, or core running —
never saved on its own; a load snaps it.

### The console

Docking at the head of the boom opens **the station's own maintenance console**
(`ui/CoreTerminal.gd`), not the hub and not UNIT-7:

```
/ S R - 7   C O R E /
C O R E   O F F L I N E
AUX BATTERY ....... STANDBY
HULL SECTIONS ..... SEATED
DOCK ARM .......... LOCKED OUT
CORE .............. COLD

> REBOOT CORE
  DEPART                UNDOCK
```

Every line is true of a station that has just had its last piece put back. BACK leaves it;
the action key brings it back while docked (the prompt reads `TERMINAL`). The tank is not
topped up and the hold is not taken in: there is nobody there to receive it.

**REBOOT CORE** types `SEAT .... OK`, `CYCLE .... OK`, `CORE .... CAUGHT` (the action key
skips), closes, and hands the reboot to the core. The camera pulls back so the player
watches the rest from where they sit (`LandedState._on_reboot_requested`):

- **SEAT** — 0.5 s, the seating clunk and the shake. Heard, never seen: nothing on the hull
  moves, and the crooked row stays crooked.
- **CYCLE** — 0.9 s later it turns over and the slots catch outward over 1.4 s, stuttering
  before they hold. `Progress.CORE_STARTED` is flagged here, and saved.
- **The power** comes up from the core: the station's lights catch one by one outward from
  it, one every 0.16 s (`StationLights.WAKE_ORIGIN` is the core, so the wake is not a
  cutscene played near it — it is the same light spreading from the first windows to catch).
- **The dish** strains up off its post, slowly, finds the Sun, and sends out one great ping in
  the Titan's purple (`CommDish.ping`, 12 Sweeps' reach): SR-7 back on the air, on whose
  frequency is left to wonder. Scrap across the ring lights up at once. From now on a Sweep
  that reaches the dish is answered the same way. The ping is not a Sweep and calls nothing.
- 4 s for the ping to spread (`StationPower.PING_WATCH`), then UNIT-7 comes on (§7), and the
  camera comes back in.

The Procedure system is not used here. The core's operations are named SEAT and CYCLE,
the two the Gates use (`docs/SWEEP.md`), and are done for the player by the console.
`entities/procedure/sr7_core.tres` is read only by `test/ProcedureTest.gd`.
`playtests/core_cold_start.play`.

## 7. UNIT-7 Comes On

The radio (`scripts/RobotRadio.gd`, shown by `ui/RadioPanel.gd`) is a link to UNIT-7 at
SR-7, not a unit aboard. Until the cold start `guide_awake` is false and `request()` drops
everything — tips, alarms, the Void, a lost ship. `CoreHousing` calls
`RobotRadio.wake_guide()` once the station's power has finished waking, and the first
transmission is `first_wake.tres`, which holds the game:

```
> ...
> OH.
> Oh — hello! Hello. Sorry, I was — how long was that?
> Never mind. Never mind! Look at this place.
> You've been busy.
>
> Right. What are we doing?
```

It does not know what it is (ADR 0008). Not "hello, welcome" — too composed. Confused first,
the cheer assembling itself out of nothing. `What are we doing?` is the first line of the
trap, and it works because it is **sincere**: it genuinely does not know, and the player —
who has just spent the act learning, with no downside, that fixing dead things is good —
tells it. `how long was that?` is a question the game does not answer.

The first transmission also files UNIT-7's Record in the Log (`_mark_guide_met`). A load
sets `guide_awake` from the ledger. `playtests/radio.play` wakes it by hand to test the
radio itself.

## 8. After The Wake: The Dock

With the core running, `SpacePort.is_open()` is true for good (`needs_core` gated on
`CORE_STARTED`; a station does not go back to being dead). The gate is the world's state,
not the radio's: `guide_awake` only governs whether UNIT-7 speaks.

On the dock, a running SR-7:

- **Tops the tank up to half** (`Drive.free_floor`, `FREE_FRACTION` 0.5 of 150) on every
  dock and relaunch, never higher. A dead SR-7 gives nothing. The first thing it does after
  the reboot is this.
- **Takes in the hold** as Stores (the Deposit) and spends them on the ship with no menu —
  `docs/FREIGHT.md`.
- **Offers the hub** (`ui/SpacePortDialogue.gd`): `SHIP`, with a count of Components waiting
  in the Cradle, above `DEPART`. There is no store (ADR 0007). SHIP is where Components are
  fitted and stowed (ADR 0014, `docs/FREIGHT.md`).

From here a relaunch or a continue comes up behind the **boot terminal**
(`ui/LoadingScreen.gd`, a power-on self test whose sixth line is `Synchronizing clone
manifest`), because the ship's computer is coming up on a powered station
(`Session.relaunch`/`resume`, `launch.boots`). A new game never sees it.

## 9. The Cargo Bay

The ship wakes with **nothing**: an empty tank and no hold (`Ship.base_max_cargo_weight`
0). No scrap, derelict, container or seam will harvest; a Sweep still lights them up and puts
them on the minimap, but there is nothing to put anything in. Act 1 does not need one, and so
the first thing after the wake is to go and get one.

**The Cargo Bay is the first Component**, ADR 0007's model case made literal
(`entities/freight/Components.gd`). It stands Lug-up between the two halves of a crashed
hauler on Veld's ground, 205° round from Veld's +x (`entities/structures/HaulerWreck.gd`). It
is in the world from minute one and dead to the Sweep until the cold start.

1. **Heard.** The dish's ping at the cold start reaches the wreck from across the system, and
   it pings on the minimap, held on the rim for its bearing, until it is identified
   (`HaulerWreckMinimapTarget`). The bay answers a Sweep from up to 5000 px off, faint and
   broken at the edge and firming up closer — warmer, colder, entirely through the
   instrument (`Freight.answer_clarity`).
2. **The need.** The first Sweep that finds scrap with no hold fitted, UNIT-7 names the
   problem, never the place (`first_no_hold.tres`, pauses): `Oh. You haven't got a hold.
   Not a small one. None at all.` ... `I'd tell you where to find one if I knew. I don't.
   Sorry, pilot.` Sincere: it does not know where a hold is.
3. **Named.** Within 1000 px (`Identifiable.RANGE`), UNIT-7 names the wreck flatly
   (`hauler_identified.tres`, no pause): `Got it. HAULER, DOWN.` / `An old freighter. Came
   down hard and broke her back, a long time ago. Nobody aboard.` Nobody can name it before
   the cold start.
4. **The pull.** The same verb as the array, and it fails: on the Aux the ship strains at the
   end of the clamp and the ground holds. Only the Burn tears it free, on the half tank SR-7
   gives. The lesson learned on Rook is the one that fails on Veld. Once free, the Aux lifts it
   off. (Threshold, pull time and fuel cost: `docs/FREIGHT.md`, `playtests/cargo_bay.play`.)
5. **Home.** Flown back as heavy Freight and delivered to SR-7's Cradle (`docs/FREIGHT.md`).
6. **Fitted.** Docked, the hub's SHIP row counts it waiting; SHIP offers `FIT CARGO BAY`.
   Fitted, the hold is 50, the cargo readout appears, and everything harvests. UNIT-7 says so
   (`cargo_bay_fitted.tres`): `There. Bolted on, sealed, holding pressure. That is a hold!` /
   `Fifty units. Everything out there will cut now, and whatever you bring home goes into the
   Stores.` / `And the Stores keep you flying. Go on, then. Fill it.`

Only then does the cutting tutorial (`first_scrap.tres`) wait for the first scrap the ship
can cut (`RobotRadio.check_scrap`). `playtests/cargo_bay_lines.play`, `playtests/cargo_bay.play`.

## 10. Guidance Without Hand-Holding

> **Cosmological illegibility is the point. Operational illegibility is a bug.**

The player must never wonder which button to press. They should constantly wonder what
things mean.

| Channel | Carries |
|---|---|
| The intro record (§3) | where, and that something has just happened |
| The manual diagnostic (§4) | the controls, literally, diegetically, as each is first needed |
| The dead station (§3) | the objectives: dark lights, a limp dish, a red alarm at every cut |
| The station's silhouette | progress |
| Shape language | Sections are machined and look like the station; scrap does not |
| The Sweep's purple answer (§5) | which things are part of something |
| The minimap's rim pings (§5, §9) | the bearing to each missing piece, and to the hauler once heard |
| `EventBus.action_message_changed` | contextual verbs (DOCK, TERMINAL, RELEASE) |

No completion percentage, no "press X to Y" popups, no text objective. The only list is the
station itself: its alarms go quiet one by one as the pieces go home. The diagnostic is the
ship talking to itself, so by the time the player wonders whether its terminal accepts
input, they have been reading it since minute one.

## 11. Known Gaps

- **The CoreTerminal's `DEPART  UNDOCK` row only closes the console**; it does not undock
  (`ui/CoreTerminal.gd` `open()`: its action is `close`). Thrust is the way off.
- **The SOLAR ARRAY has no long-range answer.** Sections have `answer_range` 0 and answer only
  inside a Sweep's ring; the bearing comes from the minimap's rim ping instead, which is up
  from the first frame. ADR 0009's "the mast answers from beyond the range anything else
  does" is built only for the Cargo Bay.
- **The station is battle-worn.** `HullDamage` (punctures, scorching, torn rims) and
  `TankBreach` (a blown-out tank) sit uneasily beside the clue that SR-7 was cut apart and
  not damaged; only the Mounts read as deliberate.
- **The intro's `0 CYCLES SINCE EVENT`** is not squared with anything else: the clone count
  (`GameState.death_count`) is shown nowhere but the dev panel.
- **No speaker before the wake.** A ship lost or taken by the Void before the cold start
  relaunches in silence: `RobotRadio.request` drops the call rather than anyone else making
  it.
