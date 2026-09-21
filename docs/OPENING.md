# RETROGRADE - The Opening

Act 1: alone at a dead station, and the first thing the player ever switches on.

Companion to `docs/SWEEP.md` (the instrument) and ADR 0009 (the decision).
This document is the *content*; `docs/SWEEP.md` is the *system*.

---

## 1. The Shape

**Act 1 is the repair of SR-7 from its own debris.** Three components fetched, one thing woken.

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

`entities/structures/SpaceStation.tscn` is already a kit of named parts under `Visuals`:

```
MainRing   CentralHub   CentralCore   TopArm
Tower1  Tower2  Tower4  ExtraModule3
SmallModule3/4/5   Detail2/4/5/6/7/8
```

So a broken station is that scene with parts hidden, and a repair is a polygon appearing.
**The silhouette of the player's house is the progress bar** - no UI, visible from anywhere
in the ring, and legible at a glance from across the orbit.

Because the game is top-down, the station's interior is legible from outside by default.
`CentralCore` is a polygon at the middle of the station. The player can see it. They never
enter, and they never stop being the ship.

## 3. The Manifest

The ship spawns docked, as it does today. Docking a dead station gives the damage report,
not the store. The emergency bus prints a parts list - not advice, not a character, a
machine doing inventory:

```
SR-7 / AUXILIARY BUS
DAMAGE REPORT — 0347 CYCLES SINCE EVENT

  MAIN RING .......... BREACHED
  DORSAL ARM ......... ABSENT
  MAST 1 ............. ABSENT
  CORE ............... PRESENT / NO DRAW

  3 COMPONENTS UNACCOUNTED FOR
  LAST VECTOR: LOCAL DEBRIS
```

Four lines of objective and zero instruction, in exactly what `TerminalWindow` and
`Typewriter` already do.

Three things it is doing quietly:

- **The count says 3, not 4.** When the player returns three components and the station
  still is not right, the answer has been in the manifest the whole time. They have to go
  and read it again. Pull, never push.
- **`CORE — PRESENT / NO DRAW` is the only asymmetric line.** Three things are gone; one
  is here and not working. That is the entire pointer to the wake, phrased as inventory.
- **`0347 CYCLES SINCE EVENT`** means nothing in hour one and something else entirely once
  the player knows about the clone system. Leave it ambiguous deliberately, not by accident.

**The manifest updates.** Re-dock after a repair and the line reads `MAIN RING …
RESTORED`. Completion tracking that lives in the fiction and that the player has to choose
to look at.

## 4. The Three Components

| Manifest line | Node | Teaches |
|---|---|---|
| `MAIN RING — BREACHED` | `MainRing` | flight; the harvest Sweep (it is fused into a rock) |
| `DORSAL ARM — ABSENT` | `TopArm` | debris is not scrap - it is tangled in things that hurt |
| `MAST 1 — ABSENT` | `Tower1` | the Sweep as a **search** tool - it is dark and beyond visual range |

Each is a single object, recovered and fitted - the same verb as every upgrade in the game
(ADR 0007), taught before the player has bolted anything to their own ship.

### The mast is the important one

The first two can be found by looking. The mast cannot: it is dark, it is outside visual
range, and in a debris field it looks like every other piece of junk.

It is found by **sweeping and listening for what answers**. In one gesture, with no words:

- the Sweep exists
- sweeping nothing returns nothing
- sweeping the right thing returns something
- **things that answer are part of something; things that do not are just scrap**

That last line is the rule the entire game runs on, taught in minute four as a way of
finding your own front door. It is also the first time the game asks the player to trust an
instrument over their eyes, which is the habit every later discovery depends on.

When the same player later sweeps the survey marker outside the station and gets a ring
back, they already know exactly what that means.

## 5. The Wake

Power comes up. The station's parts are back. One thing in the middle of it is still dark.

Sweep the core before the repairs and nothing happens - it is not part of a working system.
Sweep it after, and it still does not answer. It is seated wrong. It is cold.

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

The core lights. The rest of the station comes up with it.

**And there is a silhouette in it.**

The player did not fetch a friend. They repaired their house and found out somebody had
been in there the whole time, through every docking trip of the opening, in the dark.

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
| The manifest | one `.tres` | objectives |
| Station silhouette | already built | progress |
| Shape language | art | components look like they belong to the station; scrap does not |
| `EventBus.action_message_changed` | already built | contextual verbs (HARVEST / DOCK) |

**Anti-patterns:** no markers on the Chart, no "press X to Y" popups, no completion
percentage anywhere. The manifest is the only list and it is a diegetic object the player
has to travel to.

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
> **TODO**: Decide which `Polygon2D` parts are hidden at start. Three named components are
> specified; the `Detail*` and `SmallModule*` parts probably stay present so the wreck still
> reads as a station rather than as a frame.
> **TODO**: Write the ship's cold-start boot text. It has to carry thrust, turn, Sweep and
> dock without ever reading as a tutorial popup.
> **TODO**: Gate `SpacePortDialogue` on UNIT-7 being awake; the dead station shows the
> manifest terminal instead.
> **TODO**: Playtest the opening for wandering. Fuel is the only clock and a player who
> cannot find the mast has no pressure and no pointer.
> **TODO**: Decide how the mast's answering ring differs from a scrap node's, so "answers"
> and "harvestable" are distinguishable at a glance.
> **TODO**: `0347` - pick the number deliberately against whatever the clone counter ends up
> being (`docs/DESIGN.md` §3.2 leaves it open).
