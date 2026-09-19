---
status: accepted
date: 2026-09-18
---

# The Log lists only what the player reached

The Log's Records tab holds one Record per Body the player has Visited and per Automaton they have met. It shows nothing else: no `? ? ?` placeholder rows, no dimmed entries for somewhere unreached, no "3 of 9 surveyed" count. A Body the player has not flown to has no row at all. The Chart is the Titan's map, handed over piece by piece; the Log is the player's own, and it can only hold what they went and got.

A Body's Record appears the moment the ship enters its inner orbit (`Planet.scan_radius()`) and starts out carrying no survey. Scanning fills the survey in. Both states are permanent.

## Considered options

- **A row per Body in the scene, unreached ones shown as `? ? ?`.** Rejected twice over: the row count itself tells the player how many Bodies exist, which is exactly the spoiler ADR 0002 protects, and it withholds a name the player already has — the Guide names a find on close approach, so `? ? ?` would hide known information rather than unknown.
- **A row only once the Body is scanned.** Rejected: the Planetary Scanner is a purchase, so the Bodies section would sit empty for hours or a whole session, and the Log could not represent "I have stood in Veld's orbit and never surveyed it" — a thing the player plainly knows.
- **A row on Visited, in two states** (chosen).

## Consequences

- Visited is marked at `Planet.scan_radius()`, the same reach the Planetary Scanner needs to work, so a row appearing *is* the hint that this Body can be surveyed. This is the main pull on that upgrade, which otherwise has little advertising it.
- The marking cannot live in `PlanetScanner`: its `_active()` returns false without `GameState.has_planet_scanner`, and Visited has to work from the first minute. It needs its own node on the Ship.
- `GameState.visited_planets` is permanent and save-backed, alongside `scanned_planets` and `powered_gates`.
- An empty Bodies section is correct output for a player who has stayed home. The Automatons section still holds UNIT-7 from the first transmission, so the tab is never blank.
- The sun and moons are Bodies like any planet and follow the same rule; `PlanetScan.pick()` drops its `PlanetType.SUN` exclusion so the sun can be surveyed normally.
- Anyone "fixing" the sparse list by iterating the `planets` group should read this and ADR 0002 first.
