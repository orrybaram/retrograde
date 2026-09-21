---
status: accepted
date: 2026-09-20
---

# The game opens alone, and the player wakes UNIT-7

The player does not start with a Guide. They start alone at a dark, broken SR-7, and **UNIT-7 is something they switch on**, about fifteen minutes in, after reassembling enough of the station to give it power.

Act 1 is the repair of SR-7 from its own debris, which is already scattered in Rook's orbit (`OrbitalRingSpawner` is parented to Rook alongside `SpaceStation`). The station is already built as a kit of named `Polygon2D` parts, so a restored component is a polygon appearing: **the silhouette of the player's house is the progress bar.**

Full treatment in `docs/OPENING.md`.

## Considered options

- **Keep the current opening**: wake docked, UNIT-7 already live, it tutorials the player. Rejected: a live cheerful robot at minute one quietly contradicts a premise in which the system is dead and everything is switched off. It also spends the game's best structural opportunity on a tutorial.
- **Start alone, find the robot in the debris and carry it home.** Rejected: that makes UNIT-7 a collectible and the moment "I found the robot." Leaving it inert *inside* the station the whole time makes the moment "the lights came on and there was someone in here" — and means the player docked at it, in the dark, on every trip of the opening.
- **Start alone; UNIT-7 is dark in the station and is woken** (chosen).

## Consequences

- **The tutorial is the ending.** The game is: you switch things on, one at a time, and each one is glad. If the first thing is your only friend, every Gate afterward rhymes with it, and so does the Core.
- **The first Procedure is a person, not a door.** It is printed on the core housing as a maintenance placard: `⟨seat⟩·1 ⟨cycle⟩·1`. The same two operations as the Veld Gate, different arguments — so hours later the player reads a Gate's face and *recognises it*.
- **The Sweep teaches itself as a search tool** before it is ever a language: the station's missing components are found by pinging a debris field and listening for what answers. That establishes the rule the whole game runs on — things that answer a Sweep are part of something (ADR 0007).
- **Operational teaching must be diegetic and must exist.** Cosmological illegibility is the point; operational illegibility is a bug. The ship's cold-start boot text carries the controls, which promotes the Boot Terminal from `docs/IDEAS.md` out of the late game — the first thing the player reads is the ship talking to itself.
- **The store cannot exist yet.** Docking a dead station gives the damage-report terminal, not `SpacePortDialogue`. Combined with ADR 0007 there is no store at all, but the repair bay still gates on UNIT-7 being awake.
- **ADR 0003's "never blank" argument changes.** The Log genuinely starts empty and the first Record the player earns is the thing they woke. The conclusion (Visited marked at `scan_radius()`) is unaffected.
- **The opening has no clock.** Fuel is the only pressure and a player who cannot find the last component will wander. The Sweep makes searching active rather than passive, which helps, but this is the first thing to put in front of a real playtester.
- Time alone should be about ten to fifteen minutes: long enough for the silence to land, short enough that the wake is a relief rather than an ordeal.
