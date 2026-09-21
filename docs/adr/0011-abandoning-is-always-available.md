---
status: accepted
date: 2026-09-20
---

# Abandoning the ship is always available

With the Aux drive never running out (ADR 0010), the ship can no longer be stranded, and the fuel-depletion death in `docs/DESIGN.md` §4.7 has nothing left to trigger it. It is replaced by **abandon ship: a deliberate hold-to-confirm, available anywhere, at any time**, whatever the fuel state.

The player is never forced to fly home. They can always choose to stop being out here.

## What it costs

- The hull stays where it was left, permanently, as a salvageable `DerelictShip`.
- **The haul stays with it** — cargo, and any Component found but not yet fitted.
- **Fitted upgrades persist.** The cloning bay holds the ship's spec and prints the ship along with the occupant.
- The new ship wakes with an **empty tank**, so abandoning is never free fast travel.

That cost is legible — a light hold is abandoned without thinking, a heavy one is agonised over — and it cannot death-spiral, because the player never respawns less capable than they were.

## Considered options

- **Keep fuel death as the only way out.** Rejected: impossible under ADR 0010, and it was a failure state rather than a decision.
- **Abandon, and lose fitted upgrades too.** Rejected: a player who abandons far from home would respawn *less* able to reach their own wreck than they were when they left it. That is the soulslike death spiral, in a game with no combat to make the recovery interesting.
- **Abandon freely; the haul stays with the hull; upgrades persist** (chosen).

## Consequences

- **Most of this is already built.** `playtests/abandon.play` already covers it: the abandoned ship is a `DerelictShip` in group `derelicts`, it keeps the hold, it survives respawn and reload, and five PERFECT salvage hits recover it. `StrandedState`, `ConsumedState`, `abandoned_ship()` and `warp_to()` all exist. The work is decoupling the trigger from running dry and making it a deliberate action.
- **Abandoning is dying, and the player chooses it casually.** To save a dull trip home, over and over, and the game never comments. `docs/DESIGN.md` §4.7's distress-beacon beat survives intact — press the button, fade, wake at the station, nobody towed you and nothing came — but promoted from something that happens *to* the player into something they do on purpose. That is worse, which is the point.
- **The wreck the player salvages later is the one they died in.**
- **Some stranded clone ships become real.** §3.2 currently specifies them as "procedurally placed (not tied to actual death locations)." Mix the player's own abandoned hulls in with the placed ones so they cannot tell which is which. The Predecessor Trail then teaches itself: the player learns to read a derelict as **their own** — because some of them are — hours before the game mentions clones.
- The tow fee is gone with the currency (ADR 0007); the empty tank replaces it as friction.
- Needs a confirm that cannot be hit by accident: a hold, not a press, and not bound to `action` (which is the Sweep).
