---
status: accepted
date: 2026-09-27
---

# SR-7's Cradle is a drop bay worked by the DORSAL ARM

SR-7's Cradle moves from under the refuel boom to the top of the station. The DORSAL ARM becomes a knuckle boom on a turntable in the middle of the container strip, with a claw on a free wrist. A Component is brought to a **drop point** off the right mast; anywhere within 110 px of it, at any angle, the arm reaches out and closes on the load's free end (the one away from the ship). The player lets go the way they always do (the 0.8 s hold of ADR 0012). The claw swings the load round over a **bay** in the strip beside the turntable and sets it on a pad, and the pad takes it below deck, where it waits to be fitted from the dock menu. The container strip is solid deck with the bay as a hatch in it; the stacked crates on it are art only.

Worked out in the concept lab (claude.ai/artifact/KcpRPMQGYDqv9hn8kWgbvU, three rounds) and tuned in engine in `dev/claw_lab` (`tools/clawlab.sh`).

## Considered options

- **The Cradle under the boom** (the 2026-09-26 design). Rejected: a laden ship was sent toward the dock it cannot use while carrying (ADR 0012), and the arm, once seated, had no job.
- **A hammerhead crane** taking the load under a jib end. Rejected: the biggest change to the silhouette, and the flying becomes hovering in a box.
- **A catch berth**: a funnel between the masts, pushed into from above. Rejected: the claw barely shows.
- **Stacked yard**: delivered Components kept on show in racks. Rejected: the bay taking them below is simpler, and the stacks can be art.
- **A fixed, level claw.** Built first; in the lab a load that did not arrive level and Lug outboard could not be taken. The wrist turns freely.
- **Knuckle boom, free wrist, drop bay** (chosen).

## Consequences

- **The DORSAL ARM Section is the folded arm**, not a module: 236 × 65, held by the elbow end and lowered shoulder-first onto the turntable. Long and thin, it is by far the worst of the three Sections to turn (Freight.box_inertia), so the Act 1 carry is harder than it was. The Mount's part is the stowed arm's footprint and draws nothing: the claw draws the arm itself. Until the arm is seated there is no arm, the turntable shows the cut, and nothing is taken.
- **The claw works only with SR-7's core running.** Components come after Act 1 anyway.
- **The catch is the claw's, not a Mount's pull.** `DorsalClaw.fits` replaces Mount.SEAT_RANGE / SEAT_ANGLE for Components: 110 px of the drop point, any angle, and the load's free end inside the arm's 400 px reach. The claw closes while the ship still holds the load; if the load leaves the radius before release, the arm folds again.
- **The Cradle is always open.** `GameState.cradled` is a list; the dock offers one `FIT` row per Component waiting. A save from the one-Component Cradle (a String) loads as a list of one.
- **What the player sees instead of a prompt:** nothing on the strip lights until a laden ship is within 450 px of the drop point. Then two glide slope lamps on the right mast (both green level; the top one red when too high, the bottom one red when too low) and a faint beam of light up out of the bay, which stays on until the claw sets the load down; and the arm reaching. The tracker points at the drop point (`CRADLE`).
- **Nothing collides** but the strip: the arm, the crates and the turntable are art. The fin is gone from the hull's collision.
- A flat arm can only change sides by straightening as it passes over the turntable (`DorsalClaw.elbow_for`); every path through that point does.
