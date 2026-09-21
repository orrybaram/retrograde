---
status: accepted
date: 2026-09-20
---

# Gates are powered by procedure, not credits

A Gate was a price tag: fly to it, pay a large number of credits, the Module comes online. Instead, a Gate is powered by running the correct **Procedure** on it with the **Sweep** (`docs/SWEEP.md`). Credits are gone from the game entirely (ADR 0007), but even if they were not, the Gate would not want them.

Each Gate **prints its own Procedure**, in Notation, on its face. The Gate is not hidden information — it is untranslated information, and the difficulty of a Gate is purely how much Notation the player can read. Veld's is two words and can be copied off the face without understanding anything. TERRA-0's is printed in a dialect.

Each Gate's Procedure is **seeded from the save**, the way ore seams already are. The method of reading is universal and publishable; the answer is not transferable between players.

## Considered options

- **Keep credits as the Gate's price.** Rejected: `docs/DESIGN.md` §4.4 already flags Gate pricing as unbalanced, and it makes the game's chapter breaks a function of grinding. "Beat 3 lands hours after Beats 1 and 2" for reasons of cost is a worse chapter break than for reasons of literacy.
- **Procedure, but hidden — found elsewhere in the world.** Rejected: this puts a discovery gate on the critical path, where failing to find one document ends the run. The Gate printing its own Procedure keeps the information at the point of use and makes the gate literacy rather than search.
- **Procedure, printed on the Gate, seeded per save** (chosen).

## Consequences

- The Sweep stops being a side system and becomes the game's spine.
- Physical gating (thermal, radiation, hull, fuel) still paces *travel*; Procedures pace *Gates*. Money gets you there, knowledge gets you in. Both axes survive and neither is redundant.
- Sequence breaking is possible: a player with enough literacy could light a deeper Gate first. This is a feature; the thermal and radiation tiers keep it bounded.
- The Core's Gate becomes the one place in the game where a Procedure can be read perfectly, executed perfectly, and still refused. Preserve this exactly.
- The Original's inherited expertise becomes load-bearing at the highest level: the engineer who darkened the Gates is the template for the hands lighting them, running the same operations.
- Automatons stop selling Gates and start **translating** them. This is a more intimate kind of complicity and it improves all three (see ADR 0008).
- `docs/DESIGN.md` §4.4 ("each is paid for at the Gate itself, in credits, on the spot") is superseded. §4.9's progression ladder and three-beat tier transition need a rewrite pass.
