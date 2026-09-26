---
status: accepted
date: 2026-09-20
supersedes: 0002
---

# The Chart is bought from the Merchant, not granted by Gates

ADR 0002 established that the Chart starts blank and fills in one region per powered Gate. It stays blank; it no longer fills from Gates. A region is **Charted** when the player buys that region's chart from the **Merchant** — a drifting vessel, one per region, that must be found before it can be traded with.

The Merchant is the Titan (ADR 0008) wearing a different face. It does not salvage charts. It draws them from memory and presents them as salvage.

## Considered options

- **Keep ADR 0002.** Rejected: with ADR 0005 removing the Gate's cost, keeping the Chart as its reward leaves the Gate as a pure gift. More importantly, a map handed over by a machine is a weaker object than a map you had to find a person to trade for.
- **Charts found as loose items in the world.** Rejected: a found map has no cost, so it cannot express a choice, and it makes the Merchant redundant.
- **Bought from a drifting Merchant, one per region** (chosen).

## Consequences

- The Gate now costs a Procedure and pays transit plus a Module coming online. That is a smaller reward than before and the region reveal must carry more weight, not less.
- **Finding the Merchant is the problem.** Regions are ~250,000 units apart and the minimap reaches 10,000, so a Merchant cannot be found by sweeping space at random. It **broadcasts** — a repeating signal the ship homes on by ear rather than by map — and each Merchant sells a pointer to the next. Local homing, regional chain.
- The Merchant trades for **artifacts**, not currency (ADR 0007). Buying a chart means giving away Titan hardware instead of bolting it on. This is the only trade in the game and it is the only morally loaded one.
- "Why does it charge?" becomes the question that eventually gives the Merchant away. A process that wants parts is a process that wants to be rebuilt. It is not collecting payment; it is collecting itself.
- `docs/GLOSSARY.md`'s **Charted** entry and the Relationships bullet making the Chart a Gate's main reward are both wrong and must be replaced.
- The Chart is still the Titan's own map, still arriving piece by piece — now through an intermediary taking a cut. The fiction ADR 0002 protected survives; only the counter changed.
