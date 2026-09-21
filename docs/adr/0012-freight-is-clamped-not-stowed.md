---
status: accepted
date: 2026-09-21
---

# Freight is clamped, not stowed, and delivered by flying it into place

Some things the player recovers are too big for the hold. They are **Freight**: clamped rigidly to the ship's **nose** with a docking-style approach (slow, aligned, press `action`), and pushed home ahead of the ship like a barge. While clamped, the Freight's mass and shape are the ship's — heavier and slower to turn — so every load handles differently. Freight never enters the hold and never counts against cargo capacity.

Freight is a physical category, not a purpose. It is handed over one way: pushed into its place at the station and released. A **Section** of SR-7 goes into its own **Mount**, the gap in the station's silhouette it came from; a **Component** (ship upgrade) goes into the station's **Cradle**, and is then fitted from the station's menus once the player docks.

## Considered options

- **Everything goes in the hold.** Rejected: a station mast in a cargo bay is an inventory row, and ADR 0007's hold section "clamped to the outside and flown home handling badly" is the best feeling the upgrade system has.
- **Towed on a tether** (joint, swinging load). Rejected for now: high tuning risk (joint jitter, a load that flings the ship), and it is the natural mechanic for the **Tractor Beam**, which lost its purpose with the vacuum field (`docs/SWEEP.md`). Rigid clamping leaves that upgrade something to be.
- **Sections delivered by docking.** Rejected: it makes the silhouette a bar the player watches rather than a hole they fill, and the Act 1 repair is the one place the game can teach precision flying under load with no downside.
- **Clamped at the tail, towed behind.** Rejected: docking with a load is natural, but seating a Section means reversing it into its gap.
- **Nose clamp, Components delivered by docking.** Rejected: the load reaches the station before the nose reaches the port, and it needs an exception to "Space while carrying releases."
- **Rigid nose clamp; every piece of Freight pushed into its place — Mount or Cradle — and released** (chosen).

## Consequences

- **Turning has to read mass.** Today `FlyingState` sets `angular_velocity` directly and snaps it to zero on release, so a clamped mast would not change how the ship turns. Instead: target spin is `input × turn_speed × (ship inertia / combined inertia)`, and spin eases toward it at a rate capped by the same ratio, so a heavy load turns sluggishly and overshoots a little. Unladen, both reduce to today's numbers exactly.
- **No nose drift.** Thrust acts through the combined centre of mass; a load hanging off one side makes the ship heavy, never lopsided. Considered and rejected: thrust at the ship's own position, torquing the nose toward the load. It made each load's shape matter more, but it fights the player on every burn. Shape still matters through inertia — a long mast turns far worse than a compact ring of the same mass.
- **Mass scale, starting point:** the heaviest Section roughly doubles combined mass, halving acceleration. Tune from playtests. The cruise cap is unchanged; a loaded ship just takes longer to reach it and to shed it, which makes the boost worth more under load (ADR 0010).
- **Seating is forgiving at the end, not the approach.** Within about 40 px and 30° of its Mount (or the Cradle) the prompt reads RELEASE and it pulls the Freight home. Released elsewhere, it floats free, still clampable; a bad approach bounces off the station and never damages it.
- **The Mount is drawn as a tear** — sheared brackets, broken stubs — never a ghost outline or socket (`docs/OPENING.md` §6 anti-patterns).
- **A carrying ship cannot Sweep, and cannot dock.** While Freight is clamped, `action` is release, anywhere, with no exceptions — one key, one meaning. There is never a reason to dock while carrying: delivery is by release. Considered and rejected: Space releasing only at a Mount with a separate hold-to-drop key elsewhere — it kept the Sweep available while carrying at the cost of a second release gesture.
- This narrows `docs/SWEEP.md`'s "the one thing the ship can always do": carrying joins docked, stranded and gone as states where `allows_sonar()` is false.
- Consequence for Act 1: the player cannot listen for the mast with a Section on the hull. Deliver first, then search. One thing at a time is fine for a tutorial.
- Clamping stays on `action` too; it is gated on slow + aligned + in range, so a Sweep near Freight only clamps when the player is already lined up to take it.
- **Freight damage is deferred.** For now a clamped load collides physically and nothing more: no hull damage through the Freight, no clamp shearing loose, and Freight cannot be destroyed. Revisit once hauling is playable — the candidate is "a hit on the Freight is a hit on the hull; a harder hit shears the clamp."
- **Freight is never lost.** A Section that cannot be recovered is a soft-lock, so:
  - **Unclamped Freight parks.** Momentum bleeds to exactly zero — not `DerelictShip`'s 6 px/s residual drift — and gravity does not act on it. Ramming nudges it; it parks again. It is saved where it is (position, rotation, clamped or not), alongside derelicts in `Save.gd`, and never respawns or despawns.
  - **Abandoning while carrying** (ADR 0011): the Freight stays clamped to the abandoned hull, and a derelict holding Freight damps to a full stop too. Salvaging the derelict frees it.
  - **The Void cannot take it.** `ConsumedState` leaves no wreck, so a clamp faults and releases at `EDGE_RADIUS` — the player feels the mass drop away as they cross — and free Freight is stopped just inside the edge. All Freight is always inside the system. Considered and dropped for now: a Section that drifts home after long neglect, as a catch-all. It would hide real bugs; add it only if a playtest finds a hole.
- **Handled Freight is marked and tracked.** Once the ship has clamped a piece of Freight and then let go of it — released it, or left it on an abandoned or destroyed hull — it is marked on the Chart and becomes the tracked target immediately (`NavSystem`, `NodeTrackingTarget`, the HUD chevron). Clamping it clears the mark and tracks its destination: the Section's Mount, or the Cradle for a Component. Delivering it falls back to tracking home, as `NavSystem` already does. These auto-tracks override a manual waypoint — each follows a deliberate press. Freight never touched gets no mark, so every first search is still a search. The marks are the ship's, not the Titan's: they draw over uncharted regions and do not contradict ADR 0002 or 0006. Derelicts without Freight stay unmarked (the Predecessor Trail, ADR 0011). This replaces a considered live `LAST VECTOR` line on the SR-7 manifest.
- **One Lug per piece.** The ship clamps only at a piece's single Lug, nose-in, with the dock's checks (±30°, under 50 px/s). The load therefore always sits the same way and handles the same way every carry, and the designer — not the grab angle — decides how hard seating is, by where the Lug is placed relative to the piece's Mount heading. Considered and rejected: clamp anywhere the nose touches, which made each carry a different, luck-dependent load. The Lug is drawn in the station's shape language; scrap has none, which is a second quiet tell alongside answering a Sweep.
