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

**Unidentified**:
A thing the minimap shows as `???` until an Automaton names it on close approach; a Gate is Unidentified until first reached.
_Avoid_: unknown contact, structure, anomaly

**Charted**:
A region the star chart draws: a planet, its orbit, its moons, its station and its Gate, named and live; a region is Charted only once its Gate is powered.
_Avoid_: discovered, explored, revealed

**Chart**:
The full-screen star chart (`SystemMap`), which starts holding only Rook, its station and the void, and fills in one Charted region per powered Gate.
_Avoid_: system map, star map

## Relationships

- The **Titan** is five **Modules**, one per planet, plus the **Core** in the sun.
- A **Module** is powered by exactly one **Gate**; the **Core** has its own **Gate** at the **Sun Station**.
- The **Core**'s **Gate** refuses power until all five **Modules** are online.
- **Titan Influence** equals the number of **Modules** online; the **Core** coming online is a separate, final state, not step 6.
- Powering a **Gate** brings its **Module** online; there is no way to power a **Module** down again.
- **Automatons** encourage the player to power **Gates**; they never ask the player to destroy anything.
- A **Gate** is **Unidentified** until the player reaches it; the Guide names it, never points at it beforehand. The **Unidentified** pattern is shared with future finds.
- The **Chart** draws nothing for a region until it is **Charted**; the minimap still shows whatever is in scanner range, so the world stays open to fly.
- Powering a **Gate** charts its region. The **Chart** is the Titan's map, handed over piece by piece, and is the main reward for powering a **Gate** besides transit.

## Example dialogue

> **Dev:** "So the player dismantles containment infrastructure to free the Titan?"
> **Domain expert:** "No. Nothing is imprisoned. The Titan was *switched off*. The player only ever restores: each **Gate** they power wakes one **Module**, and the transit it gives them is the bait."
> **Dev:** "Can I skip a planet and go straight for the sun?"
> **Domain expert:** "You can fly there. The **Core**'s **Gate** won't take power until all five **Modules** are online. It tells you so."
> **Dev:** "I flew to Crom before powering anything. Is Crom on the **Chart**?"
> **Domain expert:** "No. The minimap showed it while you were there. The **Chart** only knows what the Titan has handed over. Power Crom's **Gate** and the whole region appears."
> **Dev:** "Does a **Gate** work on its own?"
> **Domain expert:** "It powers its **Module** on its own. Transit needs a second powered **Gate** to go to."

## Flagged ambiguities

- `docs/DESIGN.md` still describes containment, dismantling quests and a caged Titan. Superseded: the Titan is powered down, not contained; the player restores, never destroys. DESIGN.md needs a rewrite pass.
