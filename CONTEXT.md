# Retrograde

The solar system is a single powered-down machine. The player, a scrapper, is nudged by its leftover automatons into switching it back on, one planet at a time.

## Language

**Titan**:
The solar-system-scale AI that the war shut down; the whole system is its body.
_Avoid_: the prisoner, the contained AI, the thing in the sun

**Module**:
One subsystem of the Titan, hosted by one planet, offline until its Gate is powered.
_Avoid_: containment node, pylon, grid anchor

**Gate**:
The dormant orbital structure at a planet that powers its Module and links it to the other powered Modules; transit between Gates is the side effect that lures the player.
_Avoid_: warp gate, teleporter, jump gate. "Transit gate" is what automatons call it in dialogue only.

**Core**:
The Titan's sixth part, in the sun, whose Gate only takes power once all five Modules are online; powering it is the endgame.
_Avoid_: sixth module, the sun's module

**Sun Station**:
The station at the sun where the Core's Gate is powered; the last and hardest place to reach.

**Titan Influence**:
How awake the Titan is, 0 to 5, one step per Module online; every "wrongness" effect reads from it.
_Avoid_: corruption level, glitch level

**Automaton**:
A leftover subprocess of the Titan wearing a robot body, who frames reactivation as efficiency or commerce.

**Guide**:
UNIT-7, the **Automaton** at SR-7 over Rook: the first one the player meets, the one who names an **Unidentified** find on close approach, and the voice on the ship's comms. It is stationed at SR-7 and never travels; the comms panel is a link to it, not a crew member aboard.
_Avoid_: crew, companion, ship AI, assistant

**Unidentified**:
A thing the minimap shows as `???` until an Automaton names it on close approach; a Gate is Unidentified until first reached.
_Avoid_: unknown contact, structure, anomaly

**Charted**:
A region the star chart draws: a planet, its orbit, its moons, its station and its Gate, named and live; a region is Charted only once its Gate is powered.
_Avoid_: discovered, explored, revealed

**Chart**:
The full-screen star chart (`SystemMap`), which starts holding only Rook, its station and the void, and fills in one Charted region per powered Gate.
_Avoid_: system map, star map

**Log**:
The player's own screen (`I`), kept by the ship, not by the Titan: what is in the hold and what the player has learned. Opens on the **Ship** tab — hull, fuel, hold and upgrades; the **Records** tab holds one entry per thing the player has worked for. The **Chart** is the Titan's map, handed over; the **Log** is the player's, accrued. No **Automaton** speaks from inside the **Log** — it is the player's own instrument, read alone. UNIT-7 is met at SR-7 and heard on the radio in flight, never carried around in a menu.
_Avoid_: inventory, menu, codex, knowledge repository, database

**Record**:
One entry in the **Log**: a **Body** the player has **Visited**, or an **Automaton** they have met. A **Body**'s **Record** carries no survey until it is scanned. The **Log** never shows `? ? ?` — a thing the player has not reached has no row at all, so the **Log** cannot reveal the shape of the system (docs/adr/0002).
_Avoid_: entry, dossier, file

**Note**:
One line of a **Record**, written in the player's own voice, that appears once **Titan Influence** reaches the step it is keyed to. **Notes** are how an **Automaton**'s **Record** sours as the **Titan** wakes: the player writes down what they noticed, including things the **Automaton** would never say about itself.
_Avoid_: lore, bio, log entry, description

**Body**:
Anything the scanner can survey: a planet, a moon, or the sun. The sun is not a special case — it is **Visited** and scanned by the same rules, and its survey honestly reports no ore and no habitability.
_Avoid_: celestial object, POI, location

**Visited**:
A **Body** whose inner orbit the ship has entered — the same reach the Planetary Scanner needs to work. Visiting earns the **Body** its **Record**; scanning fills that **Record** in.
_Avoid_: sighted, discovered, explored

## Relationships

- The **Titan** is five **Modules**, one per planet, plus the **Core** in the sun.
- A **Module** is powered by exactly one **Gate**; the **Core** has its own **Gate** at the **Sun Station**.
- The **Core**'s **Gate** refuses power until all five **Modules** are online.
- **Titan Influence** equals the number of **Modules** online; the **Core** coming online is a separate, final state, not step 6.
- Powering a **Gate** brings its **Module** online; there is no way to power a **Module** down again.
- The **Guide** is one of the **Automatons**, not a separate kind of thing; the player holds its **Record** from the first transmission, so the **Log** is never empty. Holding a **Record** about an **Automaton** is the player's note on it, not the **Automaton** being present.
- **Automatons** encourage the player to power **Gates**; they never ask the player to destroy anything.
- A **Gate** is **Unidentified** until the player reaches it; the Guide names it, never points at it beforehand. The **Unidentified** pattern is shared with future finds.
- The **Chart** draws nothing for a region until it is **Charted**; the minimap still shows whatever is in scanner range, so the world stays open to fly.
- Powering a **Gate** charts its region. The **Chart** is the Titan's map, handed over piece by piece, and is the main reward for powering a **Gate** besides transit.
- **Visiting** a **Body** earns its **Record**; scanning fills the survey inside it; **Charting** does neither. All three are independent: a planet can be **Charted** with no **Record**, or hold a **Record** and never be **Charted**.
- A moon and the sun are **Bodies** like any planet. The **Log** groups them under one heading, not three.
- The **Log** lists only **Visited** **Bodies**, so it never names somewhere the player has not flown to. An empty **Records** list is correct for a player who has stayed home.
- An **Automaton**'s **Record** gains **Notes** as **Titan Influence** rises; the **Record** appears on first meeting and is never complete until the end.
- A **Record** for a **Body** is instrument output (the survey); a **Record** for an **Automaton** is **Notes**. The **Log** holds both a printout and a notebook, and they do not share a voice.
- The **Log** only ever gains **Records**; nothing the player has learned is taken back, the same way no **Module** goes back offline.

## Example dialogue

> **Dev:** "So the player dismantles containment infrastructure to free the Titan?"
> **Domain expert:** "No. Nothing is imprisoned. The Titan was *switched off*. The player only ever restores: each **Gate** they power wakes one **Module**, and the transit it gives them is the bait."
> **Dev:** "Can I skip a planet and go straight for the sun?"
> **Domain expert:** "You can fly there. The **Core**'s **Gate** won't take power until all five **Modules** are online. It tells you so."
> **Dev:** "I flew to Crom before powering anything. Is Crom on the **Chart**?"
> **Domain expert:** "No. The minimap showed it while you were there. The **Chart** only knows what the Titan has handed over. Power Crom's **Gate** and the whole region appears."
> **Dev:** "Does a **Gate** work on its own?"
> **Domain expert:** "It powers its **Module** on its own. Transit needs a second powered **Gate** to go to."
