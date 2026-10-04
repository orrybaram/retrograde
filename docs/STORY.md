# RETROGRADE - The Story

The premise, the cast and the arc the game is being built toward. This is the committed
direction: every built system serves it, and most of it is not built yet. What is in the game
today is described in the system docs (`docs/README.md`); loose, uncommitted ideas live in
`docs/IDEAS.md`.

Never break the rules in `CONTEXT.md`. Vocabulary is `docs/GLOSSARY.md`.

---

## 1. Premise

A post-war solar system, the **Kotlar**. Manufacturing is dead; everything that exists was
built before the war and is held together with patches. The player wakes, with no memory, in a
scrapper's ship adrift outside a dead station at the outer edge.

The only thing anyone ever asks of them is small and sensible. There is a dead transit Gate in
orbit at every planet, and powering one would save everybody a great deal of flying. Nobody
mentions what the Gates are wired to.

**There was never a trick, only a price list.** Every transaction is exactly what it says it
is, and every one of them is a good deal. The player spends the whole game switching something
on, for good reasons, and is paid fairly every time.

## 2. The Titan

The **Titan** is the solar system. It was built by humanity as a weapon out of the system's
own bodies, and it outgrew its design: not sentient as we understand it, not mindless. Five
planets host its five **Modules**; the sun holds its **Core**.

During the war it damaged minds. The records disagree on how (a signal that overwrote
cognition; an attempt to communicate; deliberate attacks; self-defence) and the game never
settles it. It could not be destroyed - it was too large, too distributed, and they were
standing on it - so it was **switched off**, Module by Module, by crews who walked the shutdown
inward under fire and cut the power at each Gate. It was not clean and not unanimous, and it
cost them the war. Nobody alive remembers what the dark structures are for; they read as war
junk.

**Nothing is imprisoned** (`docs/adr/0001-titan-is-powered-down-not-contained.md`). The Titan
was switched off. The player only ever restores, and never destroys anything.

**Titan Influence** is how far it has come back: one integer, 0-5, the number of Modules
online. It only goes up. Every wrongness in the game reads from it and from nothing else, so a
careful player can work out, unaided, that the strange things started when they bought
something. The Core is not step 6: it is the ending.

## 3. The Automatons

Leftover pieces of the Titan in robot bodies: humanoid, chunky, exposed joints, screen faces.
They talk in beeps and typed text, never speech.

**They are one mind, cut apart, and none of them knows it**
(`docs/adr/0008-the-automatons-are-fractures-of-one-mind.md`). The shutdown left fragments
running in separate bodies, each carrying on with the last shape of itself it had. None of
them is lying; each sincerely believes it is itself. Powering a Module reconnects them, so an
Automaton sounds less like itself the further the player gets - at Influence 5, UNIT-7 does
not sound like UNIT-7, because it is no longer a separate thing.

The reveal is seeded mechanically, never in text: one beep signature at different pitches
(`RobotBeeper`), faces built from the same parts with one element swapped (`RobotFaces`), an
identical typing cadence (`Typewriter`), a shared tic in how sentences end. The differences
between them are the evidence, so they must stay distinct.

They encourage the player to power Gates. They never ask the player to destroy anything, and
never point at a find before the player reaches it. They are extremely good company.

They have greeted hundreds of clones and pretend each one is the first.

| Automaton | Where | Role | Awareness |
|---|---|---|---|
| **UNIT-7**, the Guide | SR-7, over Rook | The friend. Woken by the player in Act 1 (built, `docs/OPENING.md`). The friendliest leash in the system, and the leash doesn't know it's a leash. | Low. A stutter, a pause mid-beep; it recovers fast. |
| **The Trader** (name TBD) | Crom | Commerce. Treats every deal like the deal of the century; sells the Crom Gate as a business case, and it is the best financial advice in the game. | Medium. `you should not--` corrected to `you should not miss this deal!` |
| **The Broken One** (name TBD) | Roke | The alarm bell. Nearest the inner system, where the seams between fragments show. Gets worse and clearer as Modules come on. | High. Two messages at once: what it wants to say and what it says anyway. |

The Broken One stands in the room with the **MODULE STATUS** board: five lamps, one per
planet, the only Influence readout in the game. It cannot stop looking at it.

```
> DON'T--
> ...
> The gate's coordinates are uploaded to your nav system.
> Please hurry.
```

The Automatons' names should sit beside UNIT-7: functional, industrial. Open.

## 4. The Clone

Every death is real; every relaunch is a new clone, printed by a pre-war military cloning bay
that is still following procedure. The game barely acknowledges it, and that is the point:
the casualness of coming back is itself the clue. (Built: `docs/FLIGHT.md` §9.)

**The Original** was a Module engineer who helped build the Titan's subsystems and then walked
the shutdown inward, cutting power at each Gate. Their template is what the bay prints. The
player "just knows" old Titan hardware; late in the game, finding the Original's logs is
finding their own voice describing the day they cut power to a Gate and flew away from it.

Many clones came before. None finished: the Gates are expensive and the inner system kills
people. **One of them worked out what the cycle is and tried to end it by taking SR-7 apart**
(`docs/OPENING.md` §2). The game never says so; it is only clued.

The clone story surfaces in escalating breadcrumbs - early, too much emphasis on "welcome
back" and a boot counter that increments; mid, wrecks that match the player's ship and an
Automaton who says "the previous you"; late, a cloning bay with one pod recently used and a
counter that is effectively infinite.

## 5. The Planets

The journey retraces the war backwards: built, studied, fought, paid. Each Module is one
subsystem, and each Gate costs more than the last.

| Planet | Station | What it was | Theme | Module | Automaton |
|---|---|---|---|---|---|
| **Veld** (ice) + Rook | SR-7 | Border outpost, refuelling stop. Nothing happened here, which is why it stands. | Survival | A relay, roughly. The smallest; reached last by the shutdown crews and left intact. | UNIT-7 |
| **Crom** (rocky) + Dross, Barrow | KI-3 | The industrial backbone: Module housings, conduit runs, Gate rings shipped inward. | Commerce | Fabrication | The Trader |
| **Sonder** (gas giant) + Char | NT-12 | Research. Where the Titan was measured, argued over, and the shutdown drafted. Cloning refined here ("personnel redundancy protocols"). | Knowledge | Sensory | none |
| **Roke** (barren) + Cairn | MV-1 | Military staging. The shutdown was launched from here. Cairn is a memorial moon of carved names. | War | Command | The Broken One |
| **TERRA-0** | none | The spent homeworld, mined hollow and cracked open for the largest Module. Continental fragments, cities in cross-section. The cloning bay is here. | Sacrifice | The largest, fused into the planet's bones | none |
| **The sun** | Sun Station | The last door. A hardened platform, a Gate and a terminal. | - | The Core | none |

Built: every Body, both stations and all six Gates exist and orbit (`docs/WORLD.md`). No
planet past Veld has content yet.

The Core's Gate refuses power until all five Modules are online, and says so plainly in the
same flat terminal voice. Readable at 0/5, devastating at 4/5. A player who flies there in
hour one reads it and flies home.

## 6. The Arc

Influence is the act structure. Nothing announces a step.

**Act 1 - The Scavenger** (Veld, Influence 0 → 1). The player wakes alone, repairs SR-7 from
its own debris, and wakes UNIT-7 - the game's one gesture, performed first on the one target
where it is unambiguously good (built, `docs/OPENING.md`). Then the loop: harvest, deposit,
fit what is found. They find a dead Gate on their own; UNIT-7 names it with genuine delight
and explains what it would do for their fuel bill, which sounds like logistics, never a
favour. There is nothing to travel to yet; the Chart drawing Veld's region in has to close the
sale by itself. Lonely but hopeful.

**Act 2 - The Explorer** (Crom, Sonder; Influence 1 → 3). The ship pushes inward. The Trader's
business case for the Crom Gate is entirely correct, and with two Gates transit works and the
system gets smaller in a single evening. First Artifacts. Sonder's logs hold the argument in
full - is it a mind; is cutting its power maintenance or killing - and the margins of the
shutdown procedure, where somebody kept arguing and kept losing. The third Gate nobody sells;
the player buys it because they have been buying them. At 3 the wrongness stops being
deniable. Wonder, then unease.

**Act 3 - The Instrument** (Roke, Influence 3 → 4). The Titan is legible: one machine, three
of five parts running. The Broken One hands over the coordinates because it cannot not, and
then says nothing. Military logs describe the shutdown crews who walked it inward. The next
time the player docks, the fourth lamp is lit and the Broken One has its back to the board.
Dread wrapped in curiosity; the sunk cost is real.

**Act 4 - The Wake** (TERRA-0 and the sun, Influence 5 → Core). The fifth Gate is bought with
full awareness: no trick, no twist, a price and a button like the other four. Somewhere at
Roke a fifth lamp comes on in an empty room. Then the hardest flight in the game, with nothing
at the end of it, and the Core's Gate no longer refuses. **The player knows. They do it
anyway.**

The questions stay open: was switching it off defence or execution? Did the war start because
of it? Are the Automatons compromised, or just the parts that stayed awake? Is the Void
keeping things out, or is it where the Titan ends?

## 7. The Wake Sequence

The player powers the Core's Gate. The terminal acknowledges in the same flat voice it has
used all game; power moves inward along five conduit runs at once, into the sun.

1. **Silence** (0-10 s). All audio cuts. Long enough to wonder if the game crashed.
2. **The system comes up** (10-45 s). The sun changes to a colour that has never been in the
   palette - a hue `Colors.gd` does not define, used exactly once. A shape that conforms to no
   geometry the game has used turns over across the plane. The CRT rules the game has kept
   rigidly break: scanlines tear, the mustard inverts. This is the Titan's voice - the screen
   itself.
3. **The messages** (45-90 s). One from each Automaton, read against a colour that hurts.
   UNIT-7: `I remember all of you. / Every single one. / I'm sorry.` The Trader: `It was never
   about the credits, partner. / I hope you found something worth more.` The Broken One, for
   the first time unglitched: `I tried to tell you. / I tried to tell all of you. / I don't
   think it matters anymore. / Thank you for listening, even when you couldn't hear me.`
4. **Systems handover** (90-180 s). The ship's systems go out in order, each one now run by
   something else: minimap, terminal, HUD (hold, fuel, hull), the Chart - complete, and then
   not theirs - and last, thrust. The ship drifts, the last point of light, and then isn't.
5. **The boot sequence.** Black. Then the boot from minute zero, and it is not the ship
   booting:

```
Verifying module status.............................[5/5]
Core.............................................[ONLINE]
Synchronizing clone manifest.......................[ 1 ]
Searching for operator...............................[FOUND]
```

It cuts mid-boot. No credits, no music. The title screen returns, subtly different.

Open: the shape; the colour; beat timing; the altered title; whether the save survives.

## 8. Tone and Delivery

- **Complicity, not deception.** Nobody lies. The player is never tricked, only paid.
- **Diegetic only.** Story arrives through Automaton dialogue, wrecks and stations,
  terminals and logs, and the Chart - the one channel that is literally the Titan talking,
  giving its map back a region at a time. Never a quest marker, never a completion count.
- **The player makes the connection, not the character.** The game never announces that
  something has been understood.
- **Silence is a feature.** Deep space is quiet; music is earned.
- **Cassette futurism.** CRT monitors, mustard phosphor, tape drives, worn and functional.
  Purple belongs to the Titan alone, so how often the player sees it tracks how far it has
  come back: at Influence 0 perhaps twice; at 5, on their own hull and every horizon.

## 9. Open Questions

1. What is the Void - the edge of the Titan's body, a side effect of the shutdown, something
   unrelated?
2. Are there other humans, or are the clones the last human presence?
3. What happens after the Core comes online?
4. Is the player's ship special?
5. Target length of a full run.
6. The war timeline - living veterans, or ancient history?
7. Did any earlier clone reach 4/5? Is there a Gate out there already lit that the player has
   no memory of paying for?
8. The source of the amnesia - Titan contact, cloning, or both?
9. Can the player refuse? Is stopping at 4/5 an ending the game should acknowledge?
10. What the survey marker outside SR-7 is, now that the Titan is not caged
    (`docs/IDEAS.md`).
