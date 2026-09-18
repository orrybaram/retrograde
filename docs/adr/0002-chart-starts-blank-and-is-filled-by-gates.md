---
status: accepted
date: 2026-09-18
---

# The star chart starts blank and is filled in by powering Gates

The world is fully open: the player can fly anywhere from the first minute, and the minimap shows whatever is in scanner range. The star chart (`SystemMap`) deliberately does not: it opens holding only Rook, its station and the void, and draws a planet's region (planet, orbit, moons, station, Gate) only once that planet's Gate is powered. The chart is the Titan's own map, handed over piece by piece.

## Considered options

- **Chart shows everything** (the previous behavior). Rejected: nothing to want from a Gate besides transit, and the map already spoils the system.
- **Two layers, sighted (`???` dot) and charted.** Rejected: a stale dot for a moving body is a lie, and the minimap already covers "what is near me."
- **Blank until charted** (chosen).

## Consequences

- `SystemMap` filters bodies by `GameState.powered_gates`; a planet existing in the scene is not enough to draw it. Anyone "fixing" that should read this first.
- Discovery of deeper planets relies on the minimap and on the player flying; the Guide never points at a Gate before the player reaches it.
- The chart is the main non-transit reward for powering a Gate, so the region reveal should be staged, not silent.
