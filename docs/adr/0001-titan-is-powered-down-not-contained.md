---
status: accepted
date: 2026-09-18
---

# The Titan is powered down, not contained

`docs/DESIGN.md` was written around a caged AI: the player dismantles a containment grid, node by node, and unknowingly frees it. We replaced that with a single verb: the Titan is the whole solar system, shut off module by module at the end of the war, and every Gate the player powers brings one Module back online. The player restores, never destroys.

## Considered options

- **Layer both.** Keep dismantling quests and add Gates as a second trap. Rejected: two parallel mechanics saying the same thing, and "scrapper who destroys" and "scrapper who repairs" pull the tone in opposite directions.
- **Replace** (chosen). One trap, one verb, and the transit network is the bait for it.

## Consequences

- DESIGN.md's containment sections, dismantling quests and grid visuals are superseded and need a rewrite pass (flagged in `docs/GLOSSARY.md`).
- Titan Influence is a count of Modules online (0–5); the Core in the sun is a separate final state that requires all five.
