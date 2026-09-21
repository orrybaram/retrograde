---
status: accepted
date: 2026-09-20
---

# There is no currency; upgrades are found objects

Credits, gems and selling are removed. The player is a scrapper, and a scrapper does not shop — they find a thing and bolt it on. An upgrade is not a purchase and not a recipe: it is **a physical object recovered from the world and fitted at a station**.

This makes `docs/DESIGN.md` §4.9's description of the ship literally true rather than cosmetic: every bolted-on lump is a specific object from a specific place, and the ship becomes a record of where the player has been. The visual-upgrade system and the upgrade system are now one system.

## Three resource streams, none fungible

| Stream | Source | Refreshes | Buys |
|---|---|---|---|
| Fuel, hull patch | Planet rings, ore seams | Yes | The trip |
| Components | Void encounters, derelicts | **No** | The ship |
| Procedures | Documentation | n/a | Gates |

**The ring pays for the trip. The void pays for the ship.** Only the first is farmable, and it buys nothing permanent.

## Considered options

- **Keep credits.** Rejected: collecting an abstract number to spend on a menu is the least compelling thing in the current build, and it was only there to give the player something to do.
- **Replace credits with crafting parts.** Rejected: if Hull II costs eight plates and plates drop from every node, plates *are* credits with inventory friction on top. The test for any resource is whether it can be farmed; if it can, it is currency wearing a hat.
- **Upgrades are found objects, placed unfarmably** (chosen).

## Consequences

- **Most upgrades are a single found object.** You find a fuel tank, you bolt it on. Only the handful `docs/DESIGN.md` §4.9 already marks as game-changing (the Tractor Beam above all) are multi-piece assemblies from three different places. Three or four such hunts in the whole game.
- **`min_radius` replaces price as the pacing dial.** `EncounterDef` already bands encounters by distance from the sun, so late-tier parts simply do not exist in the outer system. Placement paces progression; nothing is priced.
- **`budget` and slot-claiming are exactly right for unique parts.** Per `docs/ENCOUNTERS.md` §3.2, a budgeted encounter is claimed by the first slots the player flies near and keeps it forever. Guaranteed findable, impossible to farm, and its location is genuinely theirs rather than a wiki coordinate. Built for clone wrecks; it turns out to be the upgrade system.
- **How the player knows a lump of junk is a part: it answers a Sweep.** Generic scrap does not answer; it only harvests. One rule, taught in the opening on the station's own missing components (`docs/OPENING.md`), governing the whole game.
- **The cargo hold is the model case.** A hold section is too big to fit in the hold you have, so it is clamped to the outside and flown home handling badly. The first hold upgrade is experienced as a burden before it is a benefit.
- **There is no store.** `Store.gd`, `StoreData.gd`, `SR7Store.tres` go. The station is a **repair bay**: UNIT-7 fits what the player brings, which is its permanent job rather than a shopkeeper role it loses after Act 1.
- **Artifacts are the only fungible thing in the game, and the only buyer is the Titan** (ADR 0006). This gives artifacts a second use they currently lack.
- **Keep the deposit moment.** `HoldCashIn.gd`'s arc-and-count is the punctuation of a trip and must survive, re-aimed: the hold empties into the station's stores and the *station's* inventory ticks up. Better than credits, because the number is attached to a specific thing the player wants.
- **Keep the part-type count under about six.** This is the discipline that separates a small legible set of objects from a crafting game.
- Deleted: `Gem`, `GemMagnet`, `Economy`, credits in `GameState` and `Save`, the tow fee, `playtests/magnet.play`, the cash-in half of `playtests/dock.play`.
- Kept, repurposed: `HarvestTiming` → the Sweep. `ScrapNode` and its states → yields fuel and hull. `InventoryManager` → holds components. `GemData` → the item registry for parts. Cargo capacity stays a real constraint.
- **Resolved: `OreDeposit`.** Seams were the first payday and the pull for the Planetary Scanner, but the scanner is a learned Sweep now (`docs/SWEEP.md`), so ADR 0003's stated reason for that upgrade was gone. **ADR 0010 gives seams their job back: they are where fuel comes from.** Ice worlds and moons, volatiles under the crust, worked with the same Sweep as everything else. The ring pays for the trip, the void pays for the ship, the seams pay for speed.
