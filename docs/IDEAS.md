# RETROGRADE - Ideas

**These are ideas, not plans.** Nothing here is built, and nothing here is committed. Some were
decided in an ADR and then not built, or built differently; those say so. The committed
premise and arc are `docs/STORY.md`; what is in the game is in the system docs
(`docs/README.md`).

Pick one up by checking it against `CONTEXT.md`'s rules and the current code first - several
were written for an earlier version of the game.

---

## 1. The Sweep as a language

*From the old `docs/SWEEP.md` and ADR 0005. The machinery is built and dormant
(`docs/SWEEP.md` §8); nothing in play uses it.*

The game has one verb for touching the world and it points at rocks. Everything the player
might want to interrogate - a dark Gate, the structure outside SR-7, a Module site, the sun -
is either a prompt (it matters) or scenery (it does not). The games this takes after solve it
with an input the player already has, used for something mundane, that turns out to address
things it was never advertised against. *The player carried the answer the whole time and did
not know the question.*

**Grammar.** Marks laid in the six Slots of the Resonance bar alternate Operation and
Argument; holding to the end is the Commit. A word is a pair, a **Procedure** two to four
words and a Commit. Six Operations, closed for the whole game, because the bar has six Slots:

| Slot | Operation | Means | First seen |
|---|---|---|---|
| 1 | SEAT | engage a connection | the Veld Gate |
| 2 | CYCLE | run through once | the Veld Gate |
| 3 | PURGE | clear a line or buffer | Crom |
| 4 | INDEX | address a subsystem | Sonder |
| 5 | ECHO | request a readback | Veld - the planetary survey |
| 6 | LOCKOUT | the interlock | Roke |

Escalation is arguments, not verbs: there is no OVERRIDE, override is `LOCKOUT·6`.

**Gates powered by Procedure** (ADR 0005, which the game does not follow: Gates cost Stores).
Each Gate prints its own Procedure on its face, seeded per save. It withholds nothing - it is
untranslated, not hidden. "Money gets you there, knowledge gets you in": physical gating paces
travel, Procedures pace Gates. A wiki can publish the method, never the answer. The Core's
Gate is the one place a Procedure can be read perfectly, executed perfectly, and still refused.

**The Notation.** Printed as a dot grid (copyable by someone who understands nothing) beside a
glyph column (decodable only by seeing the same glyph beside the same dots across dozens of
documents). A placard on a station core, a stencil at Crom, a research appendix at Sonder and
a training manual at Roke are the same object at different levels of formality. The Original
was a Module engineer; the Sweep is where inherited expertise stops being dialogue. Prior art:
`docs/research/NOTATION-PRIOR-ART.md`.

**Escalation inward.** Breadth over depth. Veld's Gate prints `⟨seat⟩ ⟨cycle⟩`. Crom puts the
first Procedure on a wall. Sonder's arguments vary by device and must be read off the
hardware - copying stops being enough. Roke's military Procedures open with `LOCKOUT·6`; the
test is a device whose manual burned, beside another device's manual: the copier holds two
wrong sequences, the reader composes the right one. TERRA-0 has no diagrams. Titan hardware
there wants a Mark in a **seventh Slot** - and the only way past Slot 6 is the hold that
human Notation spends as its terminator. The thing the player has used to say "done" is, to
the Titan, a letter.

**Graded confirmation.** Rejections say how wrong, never where: `UNRECOGNISED OPERATION`,
`INCOMPLETE OPERATION`, `2 STEPS OUT OF ORDER`, `INTERLOCK ENGAGED`. Per-slot validation
invites brute force; pass/fail is unfalsifiable; an error count falsifies a theory without
allowing a binary search. A Sweep at something that listens must always do something.

**ECHO and the Heartbeat.** The planetary survey as a learned Sweep, `⟨echo⟩ · <body>` - ask a
thing what it is. The Heartbeat is `⟨echo⟩·—`, echo with the address stripped: what the sun
has been saying since hour one, the Core asking for a status report from a system where every
listener is off.

Risks: casual sweeping must never compose; rhythm input cuts against the no-combat posture
(generous Slots, plus stepwise arrow entry at terminals); per-save seeding is the only defence
against a macro. Open: the six glyphs; chaining window and Slot width on real hardware;
whether a dead ship can still Sweep.

The SR-7 core once ran the first Procedure, a maintenance placard (`⟨seat⟩·1 ⟨cycle⟩·1`) so
the player would recognise the Veld Gate's face hours later: "I did this to my friend." It is
a console reboot now (`docs/OPENING.md` §6), which could grow into a short sequence puzzle.

## 2. The survey marker

*From the old `docs/OPENING.md` §7 and IDEAS "The Dead Object".*

Once Act 1 is done, Veld is meant to be finishable: emptiness is what makes a landmark read,
so the near field is exhaustible on purpose and exactly one thing is left over.

A short thick cylinder with a flared collar, like a conduit terminus with the conduit
missing, between SR-7 and the ring, slightly off the direct line: in frame on every run, never
close enough to clip. No lights, no door, no dock, debris palette. It must read as **one
machined piece, not wreckage** - wreckage has broken edges, this has tolerances.

UNIT-7 names it on approach, the way it names any Unidentified find, and the name closes the
question: `> SURVEY MARKER, DISUSED`. UNIT-7 believes it (ADR 0008). Late in the game it is the
worst line in Act 1.

On a Sweep, occasionally, one ring comes back - rare at Influence 0, consistent by 2-3. A dark
Gate returns nothing; a powered Gate returns a ring every time. **The thing parked outside the
player's house behaves like a powered Gate, and nobody powered it.** A contradiction the player
finds themselves, can re-check any time, and is never answered on Veld.

If the player plays the Heartbeat at it early: every ring comes back at once, hard, and then
nothing. Not *it works*, not *silence* - they were playing back a fragment.

**Unresolved:** what it is. The old idea - a live relay node of the Titan's cage, revealed when
the scanner retunes to the Heartbeat - died with the cage (ADR 0001). Candidates: a piece of
the Titan that was never fully shut off, quietly listening where the clones wake.

## 3. The curiosities

*From the old IDEAS "The Three Curiosities", written for the caged-Titan premise. Inspired by
Outer Wilds: physical mysteries the player can point at, gated by knowledge, not items.*

**The Heartbeat.** The sun pulses in a slow, structured rhythm: faint, ignorable and present
from the first hour, louder and more complex inward and as Modules come online. Research logs
at Sonder tried to decode it. Learning it is learning to say `⟨echo⟩·—` (§1).

**The Predecessor Trail.** Wrecks identical to the player's ship, scattered sunward, each a
little further than the last: damage patterns that match each zone's hazards, cargo that
matches each stage's gear, nav coordinates scratched into bulkheads. Decoration-as-data - the
player learns to read crime scenes, and realises unprompted: *they're all me, and I'm further
than any of them*. The last one landed on TERRA-0, and whoever flew it got out and walked. The
clone wreck (`docs/ENCOUNTERS.md` §5.4) is the seed.

**The Spire** (superseded). A needle on TERRA-0, older than everything, the master switch for
the cage, readable through containment notation learned across the game. The cage is gone and
the Notation moved into the Sweep (§1), so the Spire has no lever. Its literacy gate survives
as the seventh Slot.

Patterns worth keeping: Tunic's decoration-as-data, Outer Wilds' tool recontextualisation and
lore-as-instruction, Animal Well's retroactive map, cumulative literacy. The player makes the
connection; the game never announces it.

## 4. Anomalies

Rare, brief, deniable, silent, escalating and never explained. Always covered by a CRT glitch
or static burst, so the player can rationalise it. *...did that just happen?*

- **Ghost ship** - a ship identical to theirs already docked at SR-7; a glitch, and it's gone.
- **Extra log** - a flight log entry in their format for a route they didn't fly.
- **Wrong reflection** - their ship reflected in a hull panel with a part they don't have.
- **The watcher** - a ship-sized ping very close, then gone; something moves at the edge.
- **Station voice** - a human voice on the comms for a moment, eaten by static. UNIT-7 heard
  nothing.
- **Familiar wreck** - a looted wreck holding what is in their own hold, for a frame.
- **Heartbeat pause** - the sun goes quiet, a held breath, as if it noticed them listening.
- **Doppelganger signal** - their own transponder ID heading sunward faster than they can fly.
- **Boot line** - one line in a routine boot reads `CREW: 2`, or `WELCOME BACK (AGAIN)`.

Tiers by Influence: ambient (0-1, once every few hours), unsettling (2-3), intrusive (4),
resonant (5, anomalies respond to the player). Open: triggers and odds; which are clone,
Titan or neither; the glitch treatment.

## 5. The boot terminal

The relaunch screen is the cloning bay's real terminal asking to deploy the next clone. The
player who types something other than ENTER gets a command line: deployment history (the
numbers are high), template integrity, maybe notes clones left for each other, maybe processes
that shouldn't be running - the Titan making sure the next clone deploys and heads the right
way. Rewards curiosity about the game itself; the most vulnerable moment is the access point.
A seed only.

## 6. Titan Influence effects

*From DESIGN §5.4 and the old ENCOUNTERS.md. Built: the HUD glitch, the Guide's face flash,
Notes (`docs/WORLD.md` §6). Nothing touches gameplay.*

- **UI creep:** CRT distortion up a step per Module; HUD readouts briefly wrong; terminal text
  with characters that weren't there; the palette drifting warmer; comms static; boot lines
  that change.
- **Gameplay:** the ship drifts sunward - a frame at 1, correctable at 3, a nuisance at 5;
  scanner contacts that aren't there; dreams between trips; the ship's computer growing
  friendlier; Artifacts from a Module site performing better once that Module is online,
  unannounced.
- **Transit events:** at 2-3 a scanner ghost (a large shape at the edge of range), an
  unrequested terminal line, a radio fragment that doesn't sound human; at 4-5 something
  massive between ship and sun for seconds, terminal lines that answer the player's thoughts, a
  sustained low tone that feels like it is listening.
- Never show Influence on the HUD. The Roke board (`docs/STORY.md` §3) is the only readout.

## 7. The Merchant

*ADR 0006, which the game does not follow: powering a Gate charts its region (ADR 0002).*

A drifting vessel, one per region, that sells that region's Chart for Artifacts - the only
trade in the game, with the thing the player is switching on. Found by homing on a repeating
broadcast by ear; each sells a pointer to the next. It is the same mind as UNIT-7 behind a
scratched cover that reads as wear in hour three and concealment in hour twenty. "A process
that wants parts is a process that wants to be rebuilt."

## 8. Components and upgrades

*ADR 0007's direction, mostly unbuilt. Built: the Cargo Bay, the Cradle and SHIP
(`docs/FREIGHT.md`).*

- **Where they come from.** Void encounters and derelicts, placed unfarmably: a budgeted
  encounter is claimed by the first slots the player flies near and keeps it forever. Distance
  from the sun, not price, paces them; late parts don't exist in the outer system.
- **One object, one upgrade.** "You find a fuel tank, you bolt it on." Only a handful of
  game-changers are assemblies hunted from three places. Under six part types in the game.
  A part answers a Sweep; scrap only harvests.
- **Every upgrade felt, not just seen.** Stat parts (engine, thrusters, hull, tank, thermal)
  and new verbs: a **Tractor Beam** (rigid clamping left it something to be - a swinging
  tether?), **Salvage Arms** (sealed containers; ramming debris into scrap), a **Hacking
  Suite** (terminals, data cores).
- **Artifacts** - Titan tech, always superior, eventually required:

| Artifact | Replaces | Detail |
|---|---|---|
| Resonance Core | engine | 2x thrust; hums at a frequency you feel in your teeth |
| Phase Plating | hull | the hull heals, slowly |
| Void Capacitor | tank | fuel use near zero; the gauge sometimes reads negative |
| Echo Array | scanner | sees through everything, including things that aren't there |
| Thermal Lattice | thermal | the only way into TERRA-0 and the sun: the final gear check |

- **The patchwork ship.** Plating, bigger nozzles, fuel pods, dishes bolted on until it is a
  patchwork monster; Artifacts glow faint purple and geometric, until the ship looks like a
  piece of the Titan with a person in it.
- Cradles at other stations; SR-7's claw fitting a part in the world instead of on SHIP
  (ADR 0014); Freight damage ("a hit on the Freight is a hit on the hull; a harder one shears
  the clamp", ADR 0012).

## 9. Flight

- **Abandoning** (ADR 0011; built, then removed in f54a35e). A deliberate hold, anywhere,
  any time: the hull stays as a salvageable derelict with the haul and any clamped load; the
  next clone keeps fitted parts and wakes with an empty tank. Cost is legible, and it can't
  death-spiral. The player's abandoned hulls mixed in with stranded-clone wrecks, so they
  can't tell which is theirs.
- **Seams pay for speed** (ADR 0010). Volatiles under the crust of ice worlds and moons,
  worked with the Sweep: a moon landing is a fuel run. Seams are dormant (`docs/SWEEP.md` §7).
- **Drive intent** (ADR 0010, not met). The Aux low-*thrust*, not low-speed - slow to reach a
  speed and slow to shed it, top speed uncapped; the Burn 6-10x the Aux, not 2.7x; the Burn
  should look and sound like a different engine. Playtest a Veld-to-Crom crossing on the Aux
  with a full hold.
- **The junker as a character.** It groans and rattles; it gets tighter as it is built up.

## 10. Act 1

*Designed for the opening and not built (`docs/OPENING.md` §11 lists what is open).*

- The FUEL TANK **fused into a rock**, freed with the harvest Sweep.
- The DORSAL ARM **snarled in things that hurt**: debris is not scrap.
- **The array is the pointer, not a clock.** The SOLAR ARRAY answers a Sweep from beyond any
  other range - faint and broken at the edge, firming up with approach. Warmer, colder,
  entirely through the instrument. Things that answer from beyond the bar are part of
  something; scrap only reacts inside it. Would replace the minimap rim pins. Tune it by
  playtesting for a lost player.
- Sabotage clues: `LAST VECTOR: LOCAL DEBRIS` on a readout; the clone vats visible through the
  belly hull, one empty and cracked, a tally scratched beside the row.
- A speaker for a ship lost before the wake, which today relaunches in silence.
- `how long was that?` - UNIT-7's first question, answered much later.

## 11. Encounters

*From DESIGN §4.1, §4.3 and the old ENCOUNTERS.md. Built: the cell field and its single-point
wrecks (`docs/ENCOUNTERS.md`).*

- **Radio echoes.** Fragments of old transmissions on a ship's terminal in quiet transit, by
  region: supply manifests near Veld, shift rotations toward Crom, academic argument near
  Sonder, the shutdown order in pieces near Roke, evacuation and silence at TERRA-0. Needs an
  ambient presentation that isn't UNIT-7's face card.
- **Scanner contacts** (`DEBRIS`, `CONTAINER`, `DERELICT`, `ANOMALY`, `UNKNOWN`) to detour for
  or ignore. A bearing panel was built and removed: naming what was out there took something
  away from going to look.
- **Clone wreck extras.** `WRECK ANALYSIS: CONFIGURATION MATCH 98.7%. FLAGGED.`; nav logs of a
  journey the player never made; a distress beacon still pulsing.
- **Derelicts with several salvage points** (cargo bays, terminals, sealed panels), zone-themed
  from haulers at Veld to evacuation ships at TERRA-0, some with their own hazards.
- **Dead satellites**, once a hacking terminal exists.
- **Permanent orbital derelicts** on their own orbits, crossing the player's routes.

## 12. Hazards and the inner system

No combat; danger is environmental and automated. Built: collisions and the Void.

- **Tiers.** Each planet inward demands gear to survive it: radiation at Sonder, heat at Roke,
  Artifact thermal for TERRA-0. Sequence breaking allowed, bounded by the tiers.
- **Environmental:** radiation pockets, heat zones, gravitational anomalies near Module
  hardware, EM interference near Gates (or is that the Titan?).
- **Automated:** turrets that track unidentified ships (slow, avoidable), patrol drones,
  factory machinery on schedule at Crom.
- **Gate wardens**, from Sonder inward: the last standing order of a dead civilization,
  guarding a decision it nearly tore itself apart making. Disabled through a terminal - an
  override, not a hack; the player has the authority, inherited - one at a time, for better
  fuel economy. Never explained.

## 13. Surveying and the scanner

- A planetary survey: hold position in the inner orbit while a sweep arc turns and a meter
  fills; the readout types designation, type, gravity and seams into the Body's Record. Ready in
  code (`PlanetScan.readout_lines`), with no way in. ECHO (§1) is the leading idea.
- Scanner reach that reveals new things in old places - the main reason to revisit. Hinted
  diegetically, never by markers or percentages.
- Per-planet seams: ice gives shards and fuel, rock gives bigger gems.

## 14. Audio

Built: UNIT-7's procedural beeps only.

| Context | Audio |
|---|---|
| Stations | lo-fi ambient: cassette warble, mechanical hum, distant clanking |
| Deep space | near-silence: engine hum, hull creaks, scanner pings |
| Discoveries | analog synth swells |
| Titan presence | frequencies that shouldn't be there, sub-bass; one more layer per Module, never noticeably arriving |
| Story moments | dark synth: Blade Runner meets Alien: Isolation |

The silence of space is a feature, not a gap. Music is earned.
