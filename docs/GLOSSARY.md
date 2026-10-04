# Glossary

Retrograde's vocabulary, in full: what each term means, what to call it instead of, and how the terms relate. `CONTEXT.md` is the short index; this is the reference. Use these words in code, comments, docs and dialogue.

Every term here names something in the game, or something `docs/STORY.md` commits to. Where a term is story-only, it says so. Terms for loose ideas (the Merchant, the Notation, wardens) live with the ideas in `docs/IDEAS.md`.

## The Titan

**Kotlar**:
The solar system's name, military designation **KSD-78**. Automatons say "the Kotlar"; the military writes KSD-78. Both hide the pre-war catalog name, Kessler's Star: Kessler syndrome is the debris cascade that a war of anti-satellite weapons leaves behind, first described in 1978, and *Kotlar* is the Czech form of the same trade as Kessler (a kettle-maker, a tinker). Never state the Kessler link; it is lore to find, not to tell.
_Avoid_: Kessler, Kessel (Star Wars), the home system (code name only)

**Titan**:
The solar-system-scale AI that the war shut down; the whole system is its body.
_Avoid_: the prisoner, the contained AI, the thing in the sun

**Module**:
One subsystem of the Titan, hosted by one planet, offline until its Gate is powered.
_Avoid_: containment node, pylon, grid anchor

**Gate**:
The dormant orbital structure at a planet that powers its Module when the player pays its price in Stores at its terminal, and links it to the other powered Gates; transit between Gates is the side effect that lures the player (`docs/WORLD.md` §4-5).
_Avoid_: warp gate, teleporter, jump gate. "Transit gate" is what automatons call it in dialogue only. A Gate's docking surface is its **berth**, not a cradle.

**Core**:
The Titan's sixth part, in the sun, whose Gate only takes power once all five Modules are online; powering it is the endgame (story-only: the Gate exists, the ending does not).
_Avoid_: sixth module, the sun's module

**Sun Station**:
The station at the sun beside the Core's Gate; the last and hardest place to reach.

**Titan Influence**:
How awake the Titan is, 0 to 5, one step per Module online; every "wrongness" effect reads from it.
_Avoid_: corruption level, glitch level

## Automatons

**Automaton**:
A leftover fragment of the Titan wearing a robot body, who frames reactivation as efficiency or commerce. Every **Automaton** is the same mind, cut apart by the shutdown and left running in pieces that **do not know about each other** (docs/adr/0008). None of them is lying; each sincerely believes it is itself. UNIT-7 is the only one in the game; the Trader and the Broken One are story-only (`docs/STORY.md` §3).
_Avoid_: mask, puppet, persona, servant

**Guide**:
UNIT-7, the **Automaton** at SR-7 over Rook: the one who names an **Unidentified** find on close approach, and the voice on the ship's comms. It is stationed at SR-7 and never travels; the comms panel is a link to it, not a crew member aboard. The player does **not** start with it — it is dark in the station's core until they repair SR-7, dock, and reboot the core from the station's console (docs/adr/0009, docs/OPENING.md). Until then it says nothing at all.
_Avoid_: crew, companion, ship AI, assistant

## Finding things

**Unidentified**:
A find the player has not reached yet, and so has no name. UNIT-7 names it on close approach (1,000 px), never before. An Unidentified Gate is not on the minimap at all; naming it puts it there. Gates and the Cargo Bay's hauler use the pattern (`scripts/Identifiable.gd`).
_Avoid_: unknown contact, structure, anomaly, `???`

**Charted**:
A region the Chart draws: a planet, its orbit, its moons, its station and its Gate. A region is Charted when its Gate is powered (docs/adr/0002). Flying there, or naming the Gate, charts nothing.
_Avoid_: discovered, explored, revealed

**Chart**:
The star chart (`SystemMap`, the Log's MAP tab), which starts holding only Rook, SR-7 and the Void, and draws one region in per Gate powered. It is the Titan's own map, handed over piece by piece.
_Avoid_: system map, star map

**Void**:
The dark past the last orbit, where the system stops being a system. Nothing orbits, reflects or answers out there; the deeper the ship goes the worse its instruments get, and too deep it is **consumed** — no blast, no wreck, nothing to come back for. Depth decides, never time.
_Avoid_: deep space, out of bounds, edge of the map

**Body**:
A planet, a moon or the sun. The sun is not a special case — it is **Visited** by the same rule.
_Avoid_: celestial object, POI, location

**Visited**:
A **Body** whose inner orbit the ship has entered. Visiting earns the **Body** its **Record**.
_Avoid_: sighted, discovered, explored

## What the ship does

**Aux**:
The ship's ordinary thrust: free, always available, never out, with no meter (docs/adr/0010).
_Avoid_: main engine, normal thrust

**Burn**:
The boost, held with thrust: the only thing fuel is ever spent on. The Burn is what tears buried **Freight** out of the ground.
_Avoid_: boost (in dialogue and docs; `boost` is the input's name), afterburner, nitro

**Sweep**:
Letting go of `action` sends one ring out from the ship; holding first charges that ring to reach further. Things that are part of something **answer** it in purple; at a scrap or seam the bar fills and releasing grades the cut. It is the one thing the ship can always do in open flight — except while carrying **Freight**, when `action` clamps and releases instead (docs/SWEEP.md).
_Avoid_: minigame, ping, scan

**Procedure**:
A sequence of **Marks** laid down with the **Sweep** that a piece of hardware answers. Built and dormant: nothing in play uses one (`docs/SWEEP.md` §8, `docs/IDEAS.md` §1).
_Avoid_: code, combo, puzzle, spell

## Stores and the dock

**Stores**:
SR-7's stock, in `ST`: what the hold's gems become when they are **Deposited**. Stores are spent automatically on the ship at the dock (hull first, then the tank past the free half) and at a Gate's terminal to power it. Not a currency for buying parts: Components are only ever found (docs/adr/0007).
_Avoid_: credits, money, currency, cash

**Deposit**:
Docking at an open port empties the hold into it, gem by gem, as Stores.
_Avoid_: sell, cash in, trade

**Free half**:
A running SR-7 tops the tank up to half on every dock and relaunch, never higher (`Drive.FREE_FRACTION`).

## Freight and SR-7

**Component**:
A physical object recovered from the world and fitted to the ship from **SHIP** at a station with a **Cradle** — the only way the ship is ever upgraded (docs/adr/0007). Only one exists: the **Cargo Bay**. A Component is a destination, not a size: it may be found as **Freight** and flown home clamped to the hull.
Fitted, it is part of the ship: bolted on in its one place on the hull, drawn there, solid and heavy. Each Component has exactly one place; the player chooses whether to fit it, never where, and fitting one where another sits sends the old one to the Cradle. A fitted Component is cut down from its Freight form to what the ship needs, so it is smaller on the hull than it was on the clamp. It can be taken off again, and waits in the Cradle. The places are never shown empty: the player learns a place exists only by finding what goes there (ADR 0014).
_Avoid_: credits, loot, crafting material, resource, module (a Module is the Titan's), upgrade (as a noun for the object)

**Cargo Bay**:
The first Component: buried in a crashed hauler on Veld, torn free with the **Burn**, and the thing that gives the ship a hold. A new game has no hold, and nothing harvests until it is fitted.
_Avoid_: hold upgrade, cargo pod

**Freight**:
An object too big for the hold, **clamped** rigidly to the outside of the hull and flown home by hand; while clamped, its mass and shape become the ship's — slower to speed up, slower to turn, slower to stop. Freight is a physical category, not a purpose — a **Section** and a **Component** can both arrive as Freight.
_Avoid_: carryable, tow, cargo, salvage, component

**Clamp**:
Attaching **Freight** to the ship: hold `action` with the nose near its **Lug** and the piece is drawn in and turned onto the nose. Freight rides ahead of the ship and is pushed along. **Release** is a deliberate hold of `action` while carrying, anywhere; a carrying ship cannot **Sweep** or dock.
_Avoid_: grab, pick up, tow, attach

**Pull**:
Freight buried in the ground does not come up on the clamp: the ship flies away from the ground, straining, and past the piece's threshold it tears free. Light pieces come free on the **Aux**; the Cargo Bay needs the **Burn**.
_Avoid_: tug, yank, dig

**Lug**:
The single hardpoint on a piece of **Freight** where the ship takes hold of it. It fixes how the load sits on the ship, so each piece always handles the same way; scrap has none.
_Avoid_: handle, grip, clamp point, hardpoint

**Section**:
One of SR-7's missing structural parts (its FUEL TANK, DORSAL ARM and SOLAR ARRAY), recovered as **Freight** and released into its own gap in the station's silhouette in Act 1; the player fills the hole by flying, not through a menu.
_Avoid_: component, station part, piece

**Mount**:
The cut place on SR-7 where a **Section** belongs — a straight torch line, emptied bolt holes and squared-off bracket stubs around a gap in the silhouette (SR-7 was taken apart, not broken). Each Mount takes exactly one Section.
_Avoid_: socket, slot, dock, marker

**Cradle**:
The place at a station that takes any **Component** delivered as **Freight**, where it waits to be fitted. SR-7's is a drop bay in its container strip, worked by the **DORSAL ARM**'s claw, and always open: any number of **Components** can wait in it (ADR 0013). What waits there is fitted from **SHIP**, and a Component taken off the ship goes back into it. SR-7 has the only one.
_Avoid_: bay, dock, drop-off, loading zone

**SHIP**:
The station screen, docked at a station with a **Cradle**, that shows the ship as a line drawing and is where **Components** are fitted and taken off. Its dock row carries a count of Components waiting in the Cradle, and nothing when none are. Fitting happens on the screen, and the ship in the world changes at the same moment.
_Avoid_: install, upgrade menu, loadout, hangar, garage, inventory

## The Log

**Log**:
The player's own screen (`I`), kept by the ship, not by the Titan: what is in the hold and what the player has learned. Tabs: **SHIP** (hull, fuel, hold), **RECORDS** and **MAP** (the **Chart**). The **Chart** is the Titan's map, handed over; the **Log** is the player's, accrued. No **Automaton** speaks from inside the **Log** — it is the player's own instrument, read alone.
_Avoid_: inventory, menu, codex, knowledge repository, database

**Record**:
One entry in the **Log**: a **Body** the player has **Visited**, or an **Automaton** they have met. A **Body**'s **Record** reads `UNSURVEYED`: nothing surveys a Body yet. The **Log** never shows `? ? ?` — a thing the player has not reached has no row at all, so the **Log** cannot reveal the shape of the system (docs/adr/0003).
_Avoid_: entry, dossier, file

**Note**:
One line of a **Record**, written in the player's own voice, that appears once **Titan Influence** reaches the step it is keyed to. **Notes** are how an **Automaton**'s **Record** sours as the **Titan** wakes: the player writes down what they noticed, including things the **Automaton** would never say about itself.
_Avoid_: lore, bio, log entry, description

## Relationships

- The **Titan** is five **Modules**, one per planet, plus the **Core** in the sun.
- A **Module** is powered by exactly one **Gate**; the **Core** has its own **Gate** at the **Sun Station**.
- The **Core**'s **Gate** refuses power until all five **Modules** are online.
- **Titan Influence** equals the number of **Modules** online; the **Core** coming online is a separate, final state, not step 6.
- Powering a **Gate** brings its **Module** online, charts its region, and adds it to the transit network. There is no way to power a **Module** down again and nothing refunds.
- Transit runs only between powered **Gates**; the first one powered links nowhere.
- **Gems** are harvested, **Deposited** as **Stores**, and spent on the hull, the tank and **Gates**. **Components** are never bought.
- **Freight** is flown, never stowed: it never enters the hold and never counts against cargo capacity. While clamped, the ship is the ship plus the Freight — heavier and slower to turn, but never lopsided: the nose goes where the player points it.
- A found **Component** too big for the hold is **Freight** until it is released into the **Cradle**; it becomes part of the ship only when fitted there from **SHIP**.
- A fitted **Component** outlives the ship: the next clone's ship is printed with it.
- **Freight** is never lost. Released, it coasts on as the ship was moving — same velocity, same heading, plus a slow drift off the nose — and gravity never bends its path. A clamp will not hold past the edge of the **Void**, so all Freight is always inside the system. A ship destroyed with **Freight** clamped lets it go where it was lost.
- **Freight** the ship has clamped and then let go of is marked on the **Chart** and tracked at once. These are the ship's own marks, drawn over the Titan's map whether or not the region is **Charted**; **Freight** never touched is never marked. Clamping it again clears the mark and tracks its destination instead: a **Section**'s **Mount**, or the **Cradle** for a **Component**.
- Each **Section** has exactly one **Mount**; the fuel tank only ever goes where the fuel tank was.
- A **Section** is **Freight** that is fitted to SR-7, not to the ship. All **Freight** is delivered the same way: pushed into its place and released — a **Section** into its **Mount**, a **Component** into the **Cradle**.
- The **Guide** is one of the **Automatons**, not a separate kind of thing. The player starts alone and the **Log** starts genuinely empty; the **Guide**'s **Record** is the first one they earn, by waking it.
- Every **Automaton** is the same mind in a different body, and none of them knows it. The differences between them are evidence, not characterisation. Powering a **Module** reconnects the pieces, so an **Automaton** sounds less like itself the further the player gets.
- **Automatons** encourage the player to power **Gates**; they never ask the player to destroy anything.
- A **Gate** is **Unidentified** until the player reaches it; the Guide names it, never points at it beforehand.
- The **Chart** draws nothing for a region until it is **Charted**; the minimap still shows whatever is in range, so the world stays open to fly.
- **Visiting** a **Body** earns its **Record**; **Charting** does not. A planet can be **Charted** with no **Record**, or hold a **Record** and never be **Charted**.
- A moon and the sun are **Bodies** like any planet. The **Log** groups them under one heading, not three.
- The **Log** lists only **Visited** **Bodies**, so it never names somewhere the player has not flown to. An empty **Records** list is correct for a player who has stayed home.
- An **Automaton**'s **Record** gains **Notes** as **Titan Influence** rises; the **Record** appears on first meeting and is never complete until the end.
- The **Log** only ever gains **Records**; nothing the player has learned is taken back, the same way no **Module** goes back offline.

## Example dialogue

> **Dev:** "So the player dismantles containment infrastructure to free the Titan?"
> **Domain expert:** "No. Nothing is imprisoned. The Titan was *switched off*. The player only ever restores: each **Gate** they power wakes one **Module**, and the transit it gives them is the bait."
> **Dev:** "Can I skip a planet and go straight for the sun?"
> **Domain expert:** "You can fly there. The **Core**'s **Gate** won't take power until all five **Modules** are online."
> **Dev:** "I flew to Crom before powering anything. Is Crom on the **Chart**?"
> **Domain expert:** "No. The minimap showed it while you were there. The **Chart** only knows what the Titan has handed over. Power Crom's **Gate** and the whole region appears."
> **Dev:** "Does a **Gate** work on its own?"
> **Domain expert:** "It powers its **Module** on its own. Transit needs a second powered **Gate** to go to."
