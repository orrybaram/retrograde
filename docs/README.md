# Retrograde docs

**The game is the source of truth.** The system docs describe what is built, as it behaves,
with the reasoning that still applies. When a doc and the code disagree, the code wins and the
doc is wrong: fix it in the same change. Anything designed but not built does not belong in a
system doc - it goes in `STORY.md` if it is the committed direction, `IDEAS.md` if it is not.

Start with `CONTEXT.md` at the repo root (the rules that never break) and `GLOSSARY.md` (the
words). Code and engine conventions are `CLAUDE.md` and `.claude/PATTERNS.md`.

## The game as built

| Doc | Covers |
|---|---|
| `OPENING.md` | Act 1 in play order: the dead SR-7, the manual diagnostic, the three Sections, the wake, UNIT-7, the Cargo Bay |
| `FLIGHT.md` | The ship: controls, the Aux and the Burn, fuel, gravity, hull, docking, landing, losing the ship, saves |
| `SWEEP.md` | The Sweep, what answers it, scrap, harvesting, gems, the hold, seams, Procedures (dormant), tracking |
| `FREIGHT.md` | Freight, the clamp and the pull, Sections and Mounts, the Cradle, Components, SHIP, Stores and the dock |
| `WORLD.md` | The system: Bodies and orbits, stations, Gates and transit, Titan Influence, the minimap, the Chart, the Log, the Void |
| `ENCOUNTERS.md` | The deep-space encounter field: cells, tables, wrecks, persistence |

Each ends with **Known gaps**: verified bugs, dormant code and inconsistencies in that area.

## Direction and ideas

| Doc | Covers |
|---|---|
| `STORY.md` | The premise, the Titan, the Automatons, the clone, the planets, the arc and the ending. Committed, mostly unbuilt. |
| `IDEAS.md` | Ideas, not plans: the Sweep as a language, the survey marker, anomalies, upgrades, hazards, audio. |
| `GLOSSARY.md` | Every term, what to avoid calling it, and how the terms relate. |

## Decisions and research

- `adr/` - decision records. Each is kept as written; its `status` and an **In the game** note
  say whether the game follows it (`accepted`, `accepted, in part`, `not built`, `reversed`).
  ADRs cite `docs/DESIGN.md`, the old design document this set replaced; read it from history
  with `git show f36c055:docs/DESIGN.md`.
- `research/NOTATION-PRIOR-ART.md` - prior art for printed rhythm notation, behind the
  Procedure idea.
