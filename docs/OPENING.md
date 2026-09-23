# RETROGRADE - The Opening

Act 1: alone at a dead station, and the first thing the player ever switches on.

Companion to `docs/SWEEP.md` (the instrument) and ADR 0009 (the decision).
This document is the *content*; `docs/SWEEP.md` is the *system*.

---

## 1. The Shape

**Act 1 is the repair of SR-7 from its own debris.** Three Sections fetched, one thing woken.

It is not a tutorial for the game. It is the game, performed once on a building instead of
on a ship, before the player knows it is a mechanic:

> Find pieces. Bring them home. Something switches on and is glad.

That is Act 1. It is also every Gate, every Module, and the Core. The player learns the
game's only gesture on the one target where it is unambiguously good — fixing your own
house has no downside — and is therefore trained, by a genuinely benign example, to
perform it on everything else. **The con is self-administered.**

## 2. Why The Scene Already Supports It

`scenes/HomeSystem.tscn` parents `OrbitalRingSpawner` to **Rook**, alongside
`SpaceStation`. The debris is already in the right place.

`entities/structures/SpaceStation.tscn` is a kit of named parts under `Visuals` - one
polygon per piece of the station (`RingPod1-8`, `ModuleL/C/R`, `CentralHub`, `CentralCore`,
`FuelTankL`, `RefuelBoom`, `KeelLower`, ...), each carrying its own detail as children.

So a broken station is that scene with parts hidden, and a repair is a polygon appearing.
**The silhouette of the player's house is the progress bar** - no UI, visible from anywhere
in the ring, and legible at a glance from across the orbit.

And it is a bar the player fills by hand. Each Section is Freight: clamped rigidly to the
hull, flown home with its mass and shape dragging the ship's handling, and **released into
its own gap in the silhouette**. Not docked, not fitted from a menu - flown into the hole.
Components (ship upgrades) are delivered the same way, into the station's Cradle, and fitted
from the station's menus once docked. One delivery gesture for all Freight.

### Seating a Section

- **The Mount shows the cut, not the answer.** Where each Section belongs, the station
  draws the edge it was cut from: a straight torch line, a row of empty bolt holes, a few
  beads of slag. A gap in a silhouette does not read as a hole; a cut edge does. No ghost
  outline, no glowing socket. It is a *cut* and never a tear because SR-7 was not damaged,
  it was taken apart (§2, "Why it is broken").
- **One Section, one Mount.** The tank only goes in the empty tank cradle.
- **The flying is the hard part; the last few pixels are free.** Within about 40 px of its
  Mount and 30° of its rotation (the docking tolerance), the action prompt reads
  **RELEASE**. On release the Mount pulls it home over half a second, with a clunk, and the
  polygon is the station again.
- **Miss and nothing is lost.** Released outside tolerance, a Section just floats, still
  clampable. It is a physics body: a bad approach bumps and bounces off the station, which
  is feedback, and never damage.

### SR-7's layout (locked 2026-09-21)

Chosen from the silhouette lab (claude.ai/artifact/CCVHLMG6SyGxY5Shks5aSG, round 5,
**CYLINDERS**). Top to bottom:

- **Twin masts** on the top bar, a dish on each. Both stand; neither is a Section.
- **Container strip**, and standing up off its middle like a fin, the **DORSAL ARM**.
- **Ring pods**: eight habitat pods with berthing collars between them. Permanent, not a
  Section.
- **Arm block**: three pressurised modules, flanked by cold scissor **radiator fans**.
- **Hub** with a docking port at each end.
- **Core** in the middle, with a **long cylindrical tank** on each side of it. The right
  one is the **FUEL TANK** Section; its empty cradle is where the **refuel boom** comes off.
- **Refuel boom**: a truss out to the right ending in a docking head. **The ship docks
  here** (replacing the `SpacePort` docking). Its tank is gone, so the player's own dock
  is dry: the no-fuel opening, shown in the station itself.
- **Belly module**: the clone vats, legible through the hull. One vat is empty and cracked,
  and there is a tally scratched beside the row.
- **Truss keel** below, carrying two **solar wings**. The left wing is the **SOLAR ARRAY**
  Section. The right wing is still on its hinge but hangs 50° out of true, swaying limply
  (`ArrayNudge`): it is nudged home, not fetched. Pressed against it and moving or
  thrusting so as to turn it back, the ship's hull turns it; it only ever turns toward
  true, and within 3° it swings home and locks with the seating clunk.

Art direction for all of it: flat polygons in the three hull tones, one motif (45° corner
chamfers and a light edge band on the outward face), real station parts (truss lattice,
berthing collars, radiators, tanks), and no decorative clutter. Sections are the clean,
machined pieces; the scrap around them is irregular and has no Lug.

### Why it is broken

**Never stated. Only clued.** A previous clone worked out what the cycle is and tried to end
it by taking SR-7 apart. Everything in the opening is consistent with that, and nothing says
it. Clues, in the art and the text:

- **Cut, not torn.** Every Mount is a clean torch line with its bolts removed. There is no
  war damage anywhere on SR-7 ("nothing important happened here during the war").
- **One direction.** `LAST VECTOR: LOCAL DEBRIS`: the Sections were cut free and pushed out
  along roughly one heading, so they lie on a line, not scattered.
- **The tank went first.** Cutting the tank that feeds the dock meant no clone could fly
  out and do what the player is about to do.
- **The core is seated wrong** (§5). Somebody unseated it by hand; the cold start undoes
  their work.
- **The right solar wing** is wrenched 50° out of true, hanging limp off its hinge, but not
  thrown clear. They ran out of
  time, or were stopped.
- **The clone vats**: one empty and cracked, and a tally beside the row. Somebody was
  counting.
- **`0347 CYCLES SINCE EVENT`**: the event was not an accident.

Because the game is top-down, the station's interior is legible from outside by default.
`CentralCore` is a polygon at the middle of the station. The player can see it. They never
enter, and they never stop being the ship.

## 3. The Dead Station

The ship spawns docked, as it does today. Nothing is on the comms: UNIT-7 is off until the
wake (§5), so the game opens in silence. There is no damage report and no parts list -
**the station says what is wrong by how it looks** (decided 2026-09-22, replacing the
manifest):

- **No power.** Every light on SR-7 is out: dark glass in the windows, dead lenses on the
  beacons, the dock's lamps unlit. The power comes from the core, and the core only
  listens once every piece is home (§5, decided 2026-09-22). The wings are pieces like the
  others, not a switch (`StationPower`, `CoreHousing`).
- **The dish hangs limp.** The comm dish below the keel has no drive: bowl down, swaying
  a little on its post. Power back, it swings up and finds the Sun.
- **Every wound is alarmed.** At each empty Mount, and at the hanging wing's hinge, the
  severed lines along the cut spit sparks and a red emergency lamp pulses slowly beside it
  (`CutAlarm`). Each stops as its piece goes home, so the alarms are the to-do list.
- **Power comes on while the player watches.** The core's cold start (§5) lights the station
  slowly, one light at a time outward from the core, then the dock's lamps; only then does
  the dish strain up off its post, find the Sun, and send out one great ping in the Titan's purple - SR-7 back
  on the air, and every piece of scrap across the ring lights up at once. From then on,
  with the power on, a Sweep that reaches the dish is answered with the same purple ping.

- **Docking it is met by nobody** (decided 2026-09-22). The dock opens no hub and does not
  prompt for one, and the hold is not taken in: there is nobody there to receive it. The
  dock is a perch, and thrust is the way off it. The station's hub appears for the first
  time at the wake, so the wake is what hands the player the port. `SpacePort.needs_core`
  gates it on `GameState.core_started`, which §5's cold start sets and the save keeps -
  a station does not go back to being dead. The gate is the world's state, not the radio's:
  `RobotRadio.guide_awake` still governs only whether UNIT-7's tips play.

The emergency lamps are the only red on SR-7 (`Colors.DANGER`), and the pull still holds:
nothing is marked, nothing counts. Three red lights and a dark dish are four lines of
objective with zero instruction.

## 4. The Three Sections

| Missing | Section | Teaches |
|---|---|---|
| `FUEL TANK — ABSENT` | right cylindrical tank | flight under load; the harvest Sweep (it is fused into a rock) |
| `DORSAL ARM — ABSENT` | the fin on the container strip | debris is not scrap - it is tangled in things that hurt |
| `SOLAR ARRAY — ABSENT` | left keel wing | the Sweep as a **search** tool - it is dark and beyond visual range |

| Section | Size (px) | Mass | Accel | Lug |
|---|---|---|---|---|
| FUEL TANK | 130 × 50 capsule | 3.0 (full - fuel is heavy) | ×0.50 | middle of the outer flank, facing out; slides in sideways from the boom side |
| DORSAL ARM | 120 × 68 module | 2.0 | ×0.60 | top end, facing up; goes in nose-first from above |
| SOLAR ARRAY | 150 × 50 wing | 1.0 | ×0.75 | outer tip, facing out; light but long, so it swings like a lance |
| right wing (nudge) | 150 × 50 | - | push | none: it is still attached, and pushed home |

Placement (revised 2026-09-22), nearest first:

- **FUEL TANK**: adrift just off screen to the right of the dock, keeping pace with SR-7
  (not Rook). The first thing found by simply flying out.
- **DORSAL ARM**: adrift in Rook's debris ring (3000 px out), going round with the ring
  at the ring's own speed for that distance (`Mount.start_in_orbit`), so it has to be
  caught up with rather than flown to. A piece of scrap always goes round right beside it
  (`Mount.start_beside_scrap`), so the Sweep that finds the arm finds scrap too - the
  harvest is met by accident, on the way to something else.
- **SOLAR ARRAY**: buried in Rook's ground on its sunlit face - the far side of Rook from
  where SR-7 starts - with only its Lug end sticking out (`Mount.start_buried`). The
  magnet reaches it but can't lift it: each hold of the key is one tug that shudders it
  and knocks the ship back, and the third rips it out of the ground in a burst of dust,
  rock and sparks, leaving a scar (`Freight.tug`, `GroundBreakFX`).

Each hangs dead in its frame until the magnet first takes it.

Each is a single object, recovered and fitted - the same verb as every upgrade in the game
(ADR 0007), taught before the player has bolted anything to their own ship.

### The array is the important one

The first two can be found by looking. The array cannot: it is dark, it is outside visual
range, and in a debris field it looks like every other piece of junk.

It is found by **sweeping and listening for what answers**. In one gesture, with no words:

- the Sweep exists
- sweeping nothing returns nothing
- sweeping the right thing returns something
- **things that answer are part of something; things that do not are just scrap**

That last line is the rule the entire game runs on, taught in minute four as a way of
finding your own front door. It is also the first time the game asks the player to trust an
instrument over their eyes, which is the habit every later discovery depends on.

### The array is the pointer, not a clock

The opening has no clock. The Aux never runs out (ADR 0010), so nothing is draining
and nothing is urging. A player who cannot find the array must not be *hurried*; they must
be *pointed*.

So the array answers from further off than anything else. At the edge of its range a Sweep
gets back something faint and broken - a partial ring, a stutter - and the answer firms up
the closer the ship gets. Warmer, colder, entirely through the instrument. No timer, no
marker, no text.

This is also what separates "answers" from "harvestable": scrap only ever reacts inside
the emission, where the bar is. Something that answers from beyond the bar is part of
something.

When the same player later sweeps the survey marker outside the station and gets a ring
back, they already know exactly what that means.

## 5. The Wake

The station's parts are back. The alarms are quiet, and for the first time SR-7 makes no
noise at all - it is still dark. The only light on it is one standby lamp on the core
housing, blinking slowly.

Sweep the core before the repairs and nothing happens - it is not part of a working system.
Sweep it after, and it gives back a cold thump. It is listening. It is seated wrong. It is cold.

The placard on its housing is the first **Procedure** in the game:

```
SR-7 / CORE, COLD START
┌───┬───┬───┬───┬───┬───┐
│ ● │   │   │   │   │   │   ⟨seat⟩
│ ● │   │   │   │   │   │   ·1
│   │ ● │   │   │   │   │   ⟨cycle⟩
│ ● │   │   │   │   │   │   ·1
└───┴───┴───┴───┴───┴───┘
          ▓▓▓  OVERDRIVE TO COMMIT
```

Two words. The same two operations as the Veld Gate, with different arguments - so hours
later the player drifts up to a dead orbital structure the size of a city, reads its face,
and **recognises it**. *I have done this. I did this to my friend.*

### Performing it (built 2026-09-22)

The placard shows beside the housing as the ship comes close (`PlacardPanel`), and near the
core a Sweep shows **R E S O N A N C E** under the ship (`ResonanceMeter`): the bar is the
charge being held, split into six Slots, and the Slot the key comes up in is the Mark. A
tap is Slot 1. So the placard is: tap, tap, a short hold, tap, and a hold past the end of
the bar - **O V E R D R I V E** - which is the Commit. Under the bar each Mark is drawn as a
row with a dot in its Slot, the same rows as the placard. Marks fall off if the next press
is more than 1.2s after the last release (`Resonance`).

- **Wrong:** the core thumps, and one segment along the foot of the housing lights per Mark
  in its right place - how wrong, never where (`docs/SWEEP.md` §7).
- **Right:** SEAT - the core swings square in its housing with the seating clunk, undoing
  the previous clone's work. CYCLE - it turns over, stutters and catches. The power comes up
  from it: the lights one by one outward, the dock, then the dish finds the Sun and sends
  the purple ping that lights up the scrap across the ring. Then the radio clicks on.

There is no silhouette (decided 2026-09-22). Where UNIT-7 was is not shown.

### What it says first

It has been off for 347 cycles and, under ADR 0008, does not know what it is. So: not
"hello, welcome" - too composed. Confused first, and the cheer assembling itself out of
nothing:

```
> ...
> OH.
> Oh — hello! Hello. Sorry, I was — how long was that?
> Never mind. Never mind! Look at this place.
> You've been busy.
>
> Right. What are we doing?
```

`What are we doing?` is the first line of the trap, and it works because it is **sincere**.
It genuinely does not know. It is asking. And the player - who has just spent twenty
minutes learning, with no downside whatsoever, that fixing dead things is good - tells it.

`how long was that?` is a question the game answers much later.

## 6. Guidance Without Hand-Holding

The principle everything is held to, and the one Videocult spent years getting wrong
before conceding it eight months before Rain World shipped:

> **Cosmological illegibility is the point. Operational illegibility is a bug.**

The player must never wonder which button to press. They should constantly wonder what
things mean. The rat knows the way home; it has no idea what a subway is.

| Channel | Cost | Carries |
|---|---|---|
| Ship's cold-start boot text | free | the controls, literally, diegetically |
| The dead station | art | objectives: dark lights, a limp dish, a red alarm at every cut |
| Station silhouette | already built | progress |
| Shape language | art | Sections look like they belong to the station; scrap does not |
| `EventBus.action_message_changed` | already built | contextual verbs (HARVEST / DOCK) |

**Anti-patterns:** no Titan-drawn markers on the Chart, no "press X to Y" popups, no
completion percentage anywhere. The only list is the station itself: its alarms go quiet
one by one as the pieces go home.

**The ship's own marks are the exception, because they are the ship's.** The Chart's
regions are the Titan's; laid over them are marks the ship made itself - the player's
tracking point, and Freight it has handled (ADR 0012). Nothing is marked before the ship
has touched it, so the first search for every Section is still a search.

The boot text is the load-bearing one, and it promotes the Boot Terminal from
`docs/IDEAS.md` out of the late game. The first thing the player ever reads is the ship
talking to itself - which means that by the time they wonder whether that terminal accepts
input, they have been reading it since minute one.

## 7. What Veld Withholds

After the wake, Veld's job is to be **finishable**. Three to five hours: strip the ring,
learn the planetary Sweep, work Rook's seams, find the first found-object upgrades, find
the Gate, power it. Seen it, done it.

This is deliberate. Curiosity about something distant requires the near field to be spent -
emptiness is what makes a landmark read. So Veld is exhaustible on purpose, and exactly one
thing is left over.

### The survey marker

`docs/IDEAS.md` calls this the Dead Object. It sits between the station and the first
harvesting ring, slightly off the direct line: in frame on every run of the opening, never
close enough to clip. A short thick cylinder with a flared collar, like a conduit terminus
with the conduit missing. No lights, no door, no dock, debris palette.

The one visual property that has to land: **it is clearly one machined piece, not
wreckage.** Wreckage has broken edges. This has tolerances. That is what makes it read as
intentional without reading as important.

**Its name is boring, and that is the point.** `IDEAS.md` labels it `UNKNOWN`, which is an
invitation. Instead UNIT-7 names it on close approach, the way it names any Unidentified
find, and the name closes the question:

```
> SURVEY MARKER, DISUSED
```

That is not a lie. UNIT-7 sincerely reads it that way (ADR 0008). Late game, it is the
worst line in Act 1.

**On a Sweep, occasionally, one ring comes back.** No sound, no text, no HUD. Rare at
Influence 0, more reliable at 1, consistent by 2-3 - so a player who half-noticed in hour
two is confirmed in hour nine, keyed to the one dial the game already has.

### The contradiction

By the end of Veld the player can collect four readings for free, in any order, with an
instrument they have had since minute one:

| Sweep at | Returns |
|---|---|
| A rock | a hit |
| Empty space | nothing |
| The Gate, dark | nothing |
| The Gate, powered | a ring, every time |
| The survey marker | a ring, sometimes |

**The thing parked outside their house behaves like a powered Gate.** Which is impossible,
because nobody powered it.

That is Veld's payload. Not a puzzle and not an answer - a contradiction the player finds
themselves, that is fully falsifiable, and that they can go back and re-check any time.

### If they try the Heartbeat early

Somebody will. A rhythm input and an audible rhythm in the same game, and it is hour three.

Not *it works* (collapses the arc). Not *nothing* (punishes the right idea with silence).

**Every ring comes back at once, hard. And then nothing.** No reveal, no unlock. The object
heard the whole thing and had nothing to say.

They were not wrong. At Influence 0 the Heartbeat is faint and simple, and it gets louder
and more complex as Modules come online - they were playing back a fragment. That is
discoverable later, and in the meantime they will remember it for twenty hours.

## 8. What Veld Must Not Have

- No warden. (`docs/DESIGN.md` §4.6 already puts those from Sonder inward.)
- No terminal hacking.
- No answer to the survey marker.
- The Heartbeat audible but not actionable - "faint, ignorable, but present."
- No third Procedure. The core and the Gate are the only two, and they share their verbs.

---

## TODOs

> **TODO**: Place the survey marker as an actual coordinate relative to `SpaceStation` and
> `OrbitalRingSpawner` on Rook, and check it sits in frame on the common run without being
> a collision hazard.
> **TODO**: The tank is meant to be *fused into a rock* (§4, the harvest Sweep). Today it
> hangs free at the ring's inner edge; the rock and the Sweep that frees it are not built.
> **TODO**: The DORSAL ARM is meant to be snarled in things that hurt (§4). Today it hangs
> in ordinary debris.
> **TODO**: Write the ship's cold-start boot text. It has to carry thrust, turn, Sweep and
> dock without ever reading as a tutorial popup.
> **TODO**: The dry dock is not built. §3 says the player's own dock has no tank to fill
> from, but `LandedState` still refuels at any port, so a dead SR-7 hands out a free full
> tank. Gate refuelling on the FUEL TANK Section being seated - but not before ADR 0010's
> Aux exists, which it does not, or an empty tank before the tank is home is a soft-lock.
> **TODO**: What the dock offers *after* the wake is ADR 0007's, not this document's:
> there is no currency and no store, and SR-7 is a repair bay where UNIT-7 fits what the
> player brings. `Store.gd`, `StoreData.gd` and `SR7Store.tres` are still in the tree, so
> the hub the wake opens is the superseded shopfront until that lands.
> **TODO**: UNIT-7's functional calls (relaunch, tow, the Void) still come from UNIT-7
> before the core's cold start wakes it (`RobotRadio.wake_guide`), and need a speaker of
> their own.
> **TODO**: Playtest the opening for wandering. There is no clock by design; the array's
> long-range answer (§4) is the only pointer. Tune its range until a lost player picks it
> up without being led by the hand.
> **TODO**: Range separates "answers" from "harvestable" (§4). Still decide how the
> answering ring *looks* up close, where both are inside the bar.
> **TODO**: `0347` - pick the number deliberately against whatever the clone counter ends up
> being (`docs/DESIGN.md` §3.2 leaves it open).
