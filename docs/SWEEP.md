# RETROGRADE - The Sweep

The ship's one always-available action, and how it becomes a language.

The *system*. `docs/OPENING.md` is the content that teaches it; ADRs 0004, 0006 and 0008
are the decisions that rest on it.

---

## 1. The Problem

The game has one verb for touching the world and it points at rocks.

Everything the player might want to interrogate - a dark Gate, the structure parked outside
the home station, a Module site, the sun - is either a prompt or scenery. A prompt says the
thing matters. Scenery says it does not. There is no third option, so there is nowhere to
hide anything.

The games this project takes after all solve it the same way: an input the player already
has, used for something mundane, that turns out to address things it was never advertised
against. The player carried the answer the whole time and did not know the question.

Retrograde already has that input.

## 2. What Already Exists

`SonarPulse` ships today, and its own docstring states the design:

> Always on offer - in flight, over a scrap, on the ground - so it is the one thing the
> ship can always do; the states that can't (docked, stranded, gone) say so through
> `ShipState.allows_sonar()`, and Ship drives `emitting` from that every physics tick.
> Harvesting is what happens when a ring finds a scrap or a seam; **puzzles that listen
> for a ping hook `pulsed` (or `EventBus.sonar_pulsed`)**.

So the following is already true and already tested (`playtests/sonar.play`,
`test/SonarPulseTest.gd`):

- Letting go of `action` sends **one** ring from the hull, wherever the ship is free to act.
  A tap reaches `END_RADIUS` (280px); holding charges that one ring, adding another
  `END_RADIUS` of reach every `CHARGE_TIME` (1.5s), with no ceiling. Nothing says so but a
  faint glow at the hull: the charged ping is left for the player to find. (Earlier builds
  emitted a ring every 0.32s while held.)
- `Ship.wants_sonar()` gates on `ShipState.allows_sonar()` and on no UI blocking input.
- `SonarPulse.pulsed(origin)` and `EventBus.sonar_pulsed(origin)` exist as hooks.
- There is **no vacuum field** in the code. `action` in `FlyingState` only docks. The
  vacuum field in `docs/DESIGN.md` §4.2 was never built, and this document is the argument
  for never building it: the Sweep is what it wanted to be.

What is missing is the **bar**. A free Sweep emits rings and nothing else, because
`HarvestMeter` only draws when a scrap or seam is the source. A ping carries no information
about *when the player let go*.

That missing bar is the whole design.

## 3. The Bar Is A Ruler

`HarvestMeter` sits at `OFFSET_Y` 46 and is 150x10. `SonarPulse` runs to radius 280. **The
bar is already drawn inside the emission.** It is the readout of the ping and always was;
it just hides when there is nothing to break.

Change that: the bar shows whenever the ship is sweeping.

> **As built (2026-09-22):** the Sweep now charges one ring for as long as it is held, so
> the bar is a readout of the *charge*: `Resonance.BAR_TIME` (1.6s) split into six Slots, the
> Mark being the Slot the key comes up in (a tap is Slot 1), and a hold past the end the
> Commit - itself a charged ring, reaching further than the bar is shown. And the
> RESONANCE bar does **not** show everywhere: only while hardware that listens is within
> `Resonance.REACH`. Everywhere else a free Sweep shows no bar.

| Ship is | Bar shows | Release does |
|---|---|---|
| Sweeping, scrap or seam in reach | `E X T R A C T` - six **Slots**, the lit zone, the PERFECT slice | A graded hit. Unchanged. |
| Sweeping, nothing in reach | `R E S O N A N C E` - six **Slots**, no zone | Lays down a **Mark** in one Slot |
| Held to the end, nothing in reach | Bar full | **Commits** the accumulated Marks |

`E X T R A C T` and `R E S O N A N C E` are one instrument in two modes, and the header
swap is the only place the game ever says so. `RESONANCE` is already a scanner tier in
`docs/DESIGN.md` §4.9 and `SonarPulse` already calls itself "sonar resonance" - the word
was sitting there.

### Why the left half of the bar

`HarvestTiming.ZONE_MIN_START` is `0.5`. The sweet zone always lands in the right half, so
releasing before the midpoint returns `EARLY`: no hit, no penalty, progress kept and
decaying. **The first half of that bar has never meant anything.** It is the cleanest place
in the project to put something the player has been looking at for twenty hours.

The Slots span the whole bar, not just the dead half - six Slots at 1.6s
(`NORMAL_DURATION`) is ~0.27s each, roughly twice as forgiving as the PERFECT slice the
game already asks players to hit (`0.2 * 0.34 = 0.068` wide). But the dead half is the
poetic hook and is worth protecting.

### The bar draws the diagram as you play it

Each committed Mark leaves its Slot lit. A player working a Procedure watches a row of dots
accumulate on the bar - **the same row of dots printed on the thing they are working on.**

This is the most important UI decision in the system. It makes copying a printed Procedure
trivially verifiable, and it welds the two representations together in the player's head
without a word of explanation.

Marks chain only while consecutive releases land within the **chaining window** (~1.2s).
Let it lapse and the Marks visibly fall off the bar. A sequence must never be discarded
silently: a player who cannot tell "wrong" from "not listening" stops forming theories.

---

## 4. The Grammar

Six Slots, so six operations. **The vocabulary is closed for the whole game.**

Marks alternate:

> odd Mark = **Operation** · even Mark = **Argument** · hold to the end = **Commit**

A *word* is a pair. A **Procedure** is two to four words and a Commit. Thirty-six words
exist in total - small enough to hold in the head, and a three-word Procedure is 46,656
combinations, clear of anything a player brute-forces by hand.

| Slot | Operation | Means | First seen |
|---|---|---|---|
| 1 | **SEAT** | engage a connection | SR-7 core, then the Veld Gate |
| 2 | **CYCLE** | run through once | SR-7 core, then the Veld Gate |
| 3 | **PURGE** | clear a line or a buffer | Crom |
| 4 | **INDEX** | address a subsystem | Sonder |
| 5 | **ECHO** | request a readback | Veld - the planetary scan |
| 6 | **LOCKOUT** | the interlock | Roke |

**The escalation is arguments, not verbs.** There is no OVERRIDE operation - override is
`LOCKOUT·6`. Every act makes words the player already has mean more, rather than handing
them new ones to memorise. It is also why the list can close at six: the bar has six Slots,
and the language is shaped by the instrument rather than the other way round.

Arguments are per-operation. `SEAT·3` is the third housing; `INDEX·2` the second subsystem;
`LOCKOUT·1` sets the interlock and `LOCKOUT·6` releases it, with four graded states between.

### ECHO, and the thing it gives you for free

The Planetary Scanner is not a purchase. It is a **learned Sweep** - the Procedure a survey
rig was built to run:

```
⟨echo⟩ · <body>          — ask a thing what it is
```

And the Heartbeat (`docs/IDEAS.md`) is `⟨echo⟩·—`. **Echo with the address stripped off.**

The first thing the player learns to say is the thing the sun has been saying since hour
one, aimed at nobody. They learn it in hour two and cannot read it for twenty more. A
readback request addressed to nothing, repeating: the Core asking for a status report from
a system in which every listener is switched off.

`has_planet_scanner` survives as a flag; only its source changes. ADR 0003's reasoning
shifts but its conclusion - Visited marked at `scan_radius()` - is untouched.

---

## 5. The Notation

The printed form of a Procedure, rendered **from the Procedure's own data** so that
documentation can never drift from the sequence it documents:

```
 KI-3 MAINT / HOUSING CLAMP, MK IV
 ┌───┬───┬───┬───┬───┬───┐
 │   │ ● │   │   │   │   │   ⟨seat⟩
 │   │   │ ● │   │   │   │   ·3
 │ ● │   │   │   │   │   │   ⟨cycle⟩
 │ ● │   │   │   │   │   │   ·1
 └───┴───┴───┴───┴───┴───┘
           ▓▓▓  OVERDRIVE TO COMMIT
```

Two channels, and the split is the whole point:

- **The dots are the required channel.** Copyable by a player who understands nothing. This
  is the load-bearing half; essentially no Tunic puzzle requires reading Trunic, because
  the *illustrations* carry the instruction.
- **The glyph column is the optional channel.** In the Notation's own marks, not English.
  Decodable only because the same glyph sits beside the same dot pattern across dozens of
  documents - which is free, because real maintenance paperwork is repetitive. Nobody is
  locked out; anybody who digs is paid.

A placard on a station core, a wall stencil at Crom, a research appendix at Sonder and a
training manual at Roke are the same object at different levels of formality.

### Where the Notation lives

Everywhere, as technical flavour, long before it means anything. `docs/DESIGN.md` already
fills the world with manufacturing labels, spec codes and capacity ratings because the
setting demands them. The Notation is that, with a payload.

The in-fiction reason the player can read it is already written: the Original was a Module
engineer (§3.1.1) and inherited expertise is established as something that "feels like
instinct." The Sweep is where that stops being a line of dialogue.

---

## 6. Escalation

Breadth over depth on the way in. Many shallow places to stub a toe on this, and no single
clue load-bearing.

**SR-7 - the first Procedure is a person.** Two words on a maintenance placard, waking
UNIT-7 (`docs/OPENING.md` §5). Before that, three station components teach the Sweep as a
*search* tool: things that answer are part of something.

**Veld - `ECHO`, and the first Gate.** The planetary scan is learned. The Veld Gate prints
`⟨seat⟩ ⟨cycle⟩` on its face - **the same two operations that woke UNIT-7**, different
arguments. The player recognises it. *I have done this. I did this to my friend.*

**Crom - `PURGE`, and the first Procedure printed on a wall.** Three words. An industrial
world where the machinery is still running and the instructions are stencilled beside the
machine, because that is where maintenance instructions go.

**Sonder - `INDEX` arrives.** Its argument is the first that varies by device, so the
diagram gives the operation but the argument must come off the hardware itself - a serial
stencil, a readout. Copying stops being enough.

**Roke - the authority prologue.** Military hardware assumes a hostile operator, so every
military Procedure opens with `LOCKOUT·6`:

```
Crom, housing clamp:     ⟨seat⟩·3   ⟨cycle⟩·1   [commit]
Roke, the same job:      ⟨lockout⟩·6   ⟨seat⟩·3   ⟨cycle⟩·1   [commit]
```

And then the test: a device whose wall manual burned, and a *different* device's manual
nearby reading `⟨lockout⟩·6 / ⟨purge⟩·2 / [commit]`. A player who only copies now holds two
sequences and both are wrong. A player who *read* sees that `⟨lockout⟩·6` is the prologue on
everything military, and that the body they need is the `⟨seat⟩·3 / ⟨cycle⟩·1` they learned
at Crom eight hours ago.

They compose a sentence nobody wrote down. That is the payoff of the whole system, and it
is understanding rather than finding.

**TERRA-0 - no diagrams.** The Titan's own hardware answers the same six operations, because
it was built by the same civilisation and the Original helped write the documentation.
Nothing is printed anywhere. Compose or do not.

### Gates

Per ADR 0005, every Gate prints its own Procedure and each is seeded from the save. The
Gate is not hidden information, it is untranslated information, and its difficulty is purely
how much Notation the player can read. A wiki can publish the method; it cannot publish the
answer.

### Gate wardens

`docs/DESIGN.md` §4.6 asks that the warden disable "read as an override, not a hack - the
player has the authority, inherited." A Procedure is exactly that: not breaking in,
performing a maintenance action you were qualified for. Wardens stand from Sonder inward,
which matches the escalation above.

A player who read the manuals clears a warden in fifteen seconds. A player who did not can
still grind through. Soft gate, never hard.

---

## 7. Graded Confirmation

The terminal answers in the flat monospace voice the game already speaks. Every rejection
says **how wrong**, never **where wrong**:

```
> UNRECOGNISED OPERATION          - not speaking the language at all
> INCOMPLETE OPERATION            - odd number of Marks; a word is missing its argument
> 2 STEPS OUT OF ORDER            - right words, wrong order. A count, never a position
> INTERLOCK ENGAGED               - right Procedure, missing prologue
```

This is the design problem knowledge-gating always has: per-slot validation invites brute
force, whole-sequence pass/fail is unfalsifiable and enraging. An error *count* falsifies a
theory without letting the player binary-search the answer.

Hardware with no screen gives the same information physically - a near miss lights one
segment and stops. **A Sweep at something that listens must always do something**, even when
wrong, or the player learns the world is not answering and stops investigating anything.

---

## 8. The Seventh Slot

Human Notation has six Slots. Titan hardware at TERRA-0 wants a Mark in a seventh.

The only way to Mark past the sixth Slot is to hold to the end - which the human Notation
spends as its terminator. **The thing the player has been using to say "done" is, to the
Titan, a letter.**

Costs nothing, and it is the right way for the language to start failing in the last act:
not by getting harder, but by turning out to be a dialect.

---

## 9. Build Order

The delta from what ships today is small. Most of it is moving one object.

1. **`HarvestTiming` moves from node-owned to Ship-owned.** Today
   `ScrapHarvestingState.enter()` creates it on the ScrapNode and re-creates it after each
   hit. The Ship holds one instead, and a focused node contributes `zone_start`/`zone_end`
   when in reach. Touches `ScrapNode`, `OreDeposit`, the scrap states, `HarvestMeter`,
   `HarvestingState`. This is the real work.
2. **`HarvestMeter._active()` accepts a sourceless Sweep.**
3. **Six Slot ticks in `HarvestMeter.draw_sweep()`.** It is a static taking a `Rect2` and a
   `HarvestTiming`, so they appear everywhere the meter draws, for free.
4. **Header swaps on whether a target is in reach.**
5. **Committed Marks light their Slots and persist** until Commit or until the chaining
   window lapses.
6. **`SonarPulse` grows `committed(marks: Array[int])`** alongside `pulsed`.
7. **`ProcedureDef` resource** - `id`, `Array[Vector2i]` of (operation, argument),
   `rejection_policy`, `seeded: bool`. The Notation diagram renders from the same array, so
   a Procedure and its documentation cannot drift.
8. **A listener component** that accumulates Marks in range and matches a `ProcedureDef`.

Nothing above changes flight, fuel or the Chart.

**Built (2026-09-22), for SR-7's core:** 2-6 as a separate `ResonanceMeter` rather than a mode
of `HarvestMeter` (the two never show together: resonance only while flying free), with
Marks counted on the ship (`Resonance`) and a Commit carried on its ring to
`on_procedure(marks)` (`SonarPulse.fire`); 7 as `ProcedureDef`; 8 as `CoreHousing`. Step 1 was
not needed and is not done. Stepwise arrow-key entry (§10) is for hardware with a
terminal, and waits for the Gate.

---

## 10. Risks

**The mid-hold transition.** `ScrapInRangeState` starts a harvest on
`is_action_just_pressed` while `ScrapHarvestingState` continues on `is_action_pressed`, so a
player already sweeping who drifts into scrap range does **not** start harvesting - they
must release and press again. `PlanetLandedState` has the same split. This is probably a
load-bearing guard rather than a bug: it is exactly what stops a Mark sequence leaking into
a harvest start. It was not designed for that, so confirm it *feels* right rather than sticky.

**Docking.** `FlyingState._attempt_dock()` uses `is_action_just_pressed`, so a sweeping
player does not dock by accident. Marks should not register while a dockable is in range and
aligned.

**Casual sweeping must never compose.** The chaining window is the guard. First thing to put
in front of a playtester and the most likely thing to feel bad.

**Slot legibility is a two-sided tuning problem.** Too visible and the ticks announce a
secret; too faint and nobody connects them to a diagram. Bias toward too visible - the
recurring lesson from every game this borrows from is that designers badly underestimate how
much repetition a clue needs before players read it as instruction rather than flavour.

**Execution vs. patience.** A rhythm input is an execution requirement, which cuts against
the game's no-combat, patience-over-reflexes posture. Slot boundaries should be generous, and
terminals should additionally accept a Procedure entered stepwise with the arrow keys, since
every terminal UI in the project is already arrow-driven. That keeps the Sweep as the
*native* expression without making it the only one.

**Brute force.** 36^3 is clear of hand-guessing but a macro could beat one Gate. Per-save
seeding (ADR 0005) is the real defence; beyond that, let it open and keep what cannot be
brute-forced - composing, the Heartbeat, TERRA-0 - behind it.

---

## 11. What This Supersedes

`docs/IDEAS.md` "Curiosity 3: The Spire" proposes a **containment engineering notation**:
technical marks that appear everywhere as flavour and turn out to be readable, with partial
rosetta stones at NT-12 and MV-1. That instinct is right and this document replaces it, with
two changes.

- **Post-ADR 0001 it cannot be about containment.** There is no cage, no grid and nothing to
  dismantle. The Notation is *maintenance* documentation, which fits better anyway: the
  Original was a Module engineer, not a jailer, and the player only ever restores.
- **It has a mechanical payload, not just a semantic one.** In `IDEAS.md` the Notation is
  something the player comes to *understand*. Here it is something they can *execute*, with
  an input they have had since the first ten minutes. That is the difference between a lore
  reward and a verb.

`IDEAS.md` §"The Locked Door (The Dead Object)" survives and is handled in
`docs/OPENING.md` §7. Its Heartbeat dependency is answered in §4 above.

The three Curiosities still need their post-ADR-0001 rewrite; this document does not do it,
and **the Spire remains homeless** - it was the lever that dropped a cage that no longer
exists.

---

## 12. Vocabulary

**Sweep**: Holding `action`. The one thing the ship can always do — except while carrying Freight, when `action` releases it (ADR 0012).
_Avoid_: minigame, ping (the rings are the ping, the Sweep is the act)

**Mark**: One release, landing in one **Slot**.
_Avoid_: input, beat, note

**Slot**: One of the six divisions of the bar.
_Avoid_: step, position, frequency

**Commit**: Holding to the end of the bar, firing the accumulated **Marks**. The grade
`OVERLOAD` keeps its old meaning when something is being harvested.
_Avoid_: submit, cast, execute

**Procedure**: A sequence of **Marks** that a piece of hardware answers.
_Avoid_: code, combo, sequence puzzle, spell

**Operation / Argument**: The two halves of a word. Odd **Marks** are Operations, even ones
are Arguments.
_Avoid_: verb/noun (right idea, wrong register for a maintenance manual)

**Notation**: The printed form of a **Procedure** - dots plus glyphs.
_Avoid_: language, cipher, runes, Trunic

---

## TODOs

> **TODO**: Design the six Operation glyphs. They must read as industrial stamping rather
> than as an alphabet - closer to a hazard symbol than to a letter.
> **TODO**: Tune the chaining window and Slot boundaries against a real controller and a real
> keyboard. 1.2s and ~0.27s are estimates.
> **TODO**: Decide whether the six Slot ticks are visible before the first Procedure is found,
> or fade in with the first Notation the player sees. Leaning toward always visible - the
> whole point is that they were always there.
> **TODO**: Write the Crom wall stencil, the Sonder appendix and the Roke training manual for
> the *same* Procedure, so the three registers can be compared side by side.
> **TODO**: Specify the per-save seeding for Gate Procedures - which parts vary and which are
> fixed, so a Gate is never unreadable and never guessable.
> **TODO**: Confirm the mid-hold transition (§10): `tools/play.sh playtests/sonar.play`, then
> a live session holding `action` while drifting into scrap range.
> **TODO**: Revisit `StrandedState`. `SonarPulse`'s docstring puts "stranded" among the states
> that say no, which is correct for a ship with no power - but the fuel-death sequence in
> `docs/DESIGN.md` §4.7 is the one moment where the player sits alone in a dead ship with
> nothing to do but press the beacon. A ship that can still emit, into nothing, is a very
> different scene. Decide deliberately rather than by default.
