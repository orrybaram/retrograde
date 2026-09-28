---
status: accepted
date: 2026-09-27
---

# Fitted Components are on the hull

A fitted Component is part of the ship you fly: drawn on the hull, added to its mass, and solid. Each Component has one place on the hull, which the player never picks and never sees empty, and it is fitted in a form cut down from the one it was carried home in. The dock's `FIT <X>` rows become one **SHIP** row that opens a line drawing of the ship, where Components are fitted and taken off. This is ADR 0007's claim ("the ship becomes a record of where the player has been") made literal, and DESIGN §4.9's patchwork ship made mechanical instead of cosmetic.

Worked out in the concept page claude.ai/artifact/QqdiSR4BPo8w5ANv1GGrcx and a grilling session.

## Considered options

- **Drawn only, or drawn and heavy but not solid.** Rejected: the ship would lie about its size. A wider ship that has to be flown more carefully is the point.
- **The player places parts**, either on a few shared mount points or on a free grid. Rejected: it makes ship-building a game of its own, against ADR 0007's small set of objects. The only choice is whether to fit a part, never where.
- **Empty places drawn on the schematic**, labeled or faint. Rejected: they name what the player has not found (ADR 0002). A place exists to the player only once they have found what goes there.
- **The part fitted at its Freight size.** The Cargo Bay is 116 × 60 as Freight against a hull of about 22 × 18; fitted whole, the ship becomes a cab pulling a box, and every dock, landing and gap changes. Rejected in favour of a fitted form: UNIT-7 cuts the hold out of the hauler's frame.
- **SR-7's claw fitting the part in the world.** Deferred, not rejected: the docking head and the turntable are at opposite ends of SR-7, and the fit happens on the SHIP screen for now.

## Consequences

- **Fitting a part where another sits sends the old one to the Cradle.** Taking a part off does the same, at any station with a Cradle, and is allowed even for the only hold: a ship with no hold is a state the game already has.
- **The fitted form has its own outline and mass** alongside the Freight ones. The Cargo Bay's is +0.35 on the ship's 3.0, before cargo: turning keeps about 93%, and SHIP's handling bar (turn × acceleration, in eighths) drops from 8 to 7.
- **The dock pad is 2 px behind the bare hull.** A fitted part must not reach further aft than the hull's tail (ship x ≈ −13), or the docked ship overlaps SR-7's port pad and reverse thrust undocks into it.
- **The schematic is terminal line art:** mustard hull, cream parts, a blinking ghost for a preview. Artifacts will draw in `Colors.TITAN`. Handling is shown as a segment bar, not MASS or TURN numbers.
- **The world changes when the screen does.** `Ship.refit` runs on FIT, so the docked ship gains the part behind the menu.
- **Fitted parts outlive the ship.** The cloning bay prints the spec (ADR 0011), so the new ship has them, and an abandoned hull keeps drawing its own: two copies, one a wreck. The wreck's parts are dead metal: they do not answer the Sweep and cannot be taken.
- **The save does not change.** Each Component names its place, so `Progress.FITTED_COMPONENTS` stays a set, and saves with the Cargo Bay fitted load as they are. The ledger never unmarks, so it reads "has been fitted"; what is on the hull is that, less anything waiting in the Cradle (`GameState.fitted`). Components are one of a kind, which is what makes that sound.
- **The row previews itself.** On SHIP, the cursor on `FIT <X>` blinks it in its place and shows the change in STATUS; on `STOW <X>` it dims it. ENTER does it. There is no separate pick-then-confirm step.
