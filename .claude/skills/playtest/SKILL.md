---
name: playtest
description: Launch and play Retrograde to verify a change in the running game — inject real key presses, read game state and on-screen text as JSON, take screenshots, and assert outcomes. Use when asked to run/play/screenshot the game, or to confirm a gameplay/UI change actually works (not just unit tests).
---

# Playtesting Retrograde

Driver: `scripts/Playtest.gd` (autoload, inert unless launched with `--playtest`).
Everything goes through real `InputEventKey`s, so the game sees what a player would do.
Each run gets its own `user://playtest/save_<pid>.cfg` (deleted when it ends), so the player's real
save is never touched and parallel runs — including other worktrees, which share the user dir — can't
clobber each other's saved state.

## Two modes

**Explore live** (figure out what happens, step by step):
```bash
tools/play.sh serve                 # windowed; add --headless before `serve` for no window
tools/playctl state                 # JSON: main_state, paused, ui_open, ship{state,fuel,hull,speed,...}, nearest{planet,space_port,...}
tools/playctl screen                # all text visible on UI panels
tools/playctl press enter           # start menu -> NEW GAME
tools/playctl hold thrust 1.5
tools/playctl screenshot flying     # -> .playtest/flying.png, then Read it to look
tools/playctl quit                  # always quit when done
```
Each `playctl` call blocks until the command finishes and exits non-zero if `ok` is false.

**Verify with a scenario** (repeatable; exit 0 = pass):
```bash
tools/play.sh playtests/launch.play            # windowed, screenshots saved
tools/play.sh --headless playtests/launch.play # CI-style, screenshots skipped
```
Transcript: `.playtest/transcript.jsonl` (one JSON reply per command). Scenarios live in `playtests/*.play`; turn a
successful live exploration into one. A scenario stops at the first failing non-assert command; asserts all run.

## Commands

| command | effect |
|---|---|
| `press <key\|action> [n]` | tap n times. Keys: `enter up down left right esc space i m e …`; actions: `thrust turn_left turn_right reverse_thrust boost action` |
| `hold <key\|action> <sec>` / `down` / `up` / `release_all` | sustained input |
| `face <group> [tol]` | steer with turn keys toward nearest node in group (`planets`, `space_ports`, `space_stations`, `resource_nodes`) |
| `wait <sec>` / `frames <n>` / `timescale <n>` | advance time (wait is game time) |
| `seek <Kind> [hops]` | warp around deep space until a node of that kind (`Scrap`, `Container`, `Derelict`) is streaming nearby, and park there; fails if none turns up. Deep space is sparse, so scenarios can't assume a given spot holds one |
| `stage_harvest [dist] [trophy\|plain] [kind:<Kind>]` | park the flying ship `dist`px (default 40; harvest circle radius 60) behind the nearest scrap, velocity matched; sets `pt.staged` and logs `harvest_started`/`resource_depleted`/`harvest_stopped` events. `plain` forces an ordinary 3-hit node, `trophy` forces a 5-hit one, `kind:Container` picks only that sort (`Scrap`, `Container`, `Derelict`) |
| `land <planet> [descent] [sec]` | autopilot: taps `thrust` to fall onto the planet at ≤ `descent` px/s (default 15) until `PlanetLandedState`; start nose-up over a seam with `pt.hover_over_ore` |
| `burst <name> <n> <sec>` | n screenshots `sec` apart → `<name>_00.png…` (for judging motion/feel) |
| `wait_until <expr> [timeout]` | poll expression |
| `assert <expr> ["message"]` | record failure if falsy |
| `reload` | reload from the save (as CONTINUE does) and wait for the load to finish |
| `eval <expr>` / `state` / `screen` / `screenshot <name>` / `log <text>` / `quit` | observe |

Expressions are Godot `Expression`s with `ship`, `main`, `gs` (GameState), `inv` (InventoryManager), `bus`
(EventBus), `pt` (driver: `pt.state_name()`, `pt.visible_ui()`, `pt.screen_text()`, `pt.nearest(group)`,
`pt.node(group)`, `pt.count_kind(kind)`, `pt.nearest_kind(kind)`, `pt.remember(key, value)` / `pt.recall(key)`, `pt.save_now()`, `pt.item_count()` (gems in hold), `pt.gem_count()` (loose gems), `pt.spawn_gem(id, offset, [rel_vel])`, `pt.last_drops`, `pt.staged`), and `self` = driver so `get_tree()` works.
`main.current_game_state`: 0 MENU, 1 PLAYING, 2 GAME_OVER.

## Game flow cheatsheet
- Boot → StartMenu (paused). `press enter` = NEW GAME. Ship spawns docked (`LandedState`).
- Docked: `press action` opens SpacePortDialogue; `down` + `enter` = DEPART. `thrust` undocks when no UI is open.
- In flight: `i` inventory, `m` system map, `esc` pause. Ship nose = +X; positive `bearing_deg` = target is to the right.
- `esc` closes the dock dialogue without pausing.

## Harvest iteration
`tools/play.sh playtests/harvest.play` skips all flying: boot → depart → `stage_harvest`, then timed hits
(three PERFECT hits breaking a node, early release + re-hold on a trophy, OVERLOAD) and a dock cash-in.
Scrap takes 3 hits (trophy 5); each hit is a release and re-arms a fresh zone, and `pt.staged.hits_left` counts down.
The ship stays in `HarvestingState` (zoomed, velocity-locked) between hits; it returns to `FlyingState` ~0.8s after
the break or once it leaves harvest range (flight input releases the lock but keeps focus).
Release timing is driven with `wait_until pt.staged.timing.progress >= pt.staged.timing.perfect_start()`
(also `zone_start`, `zone_end`). Frames land in `.playtest/harvest_*.png`; the transcript logs
`harvest_hit {grade, gems, final}`, `gem_collected {gem}` and `hold_cashed_in {credits}` events.

`playtests/magnet.play` drops gems around the flying ship and checks the magnet pulls them in (range, fly-by, full hold).

`playtests/dock.play` redocks with a stocked hold and empty tank: gems arc into the port while HUD credits roll up, the dialogue waits for the cash-in, fuel fills in ~5s (`.playtest/dock_*.png`).

`playtests/wreck.play` blows the ship up with a stocked hold: 70% of it stays at the wreck through respawn, the loose-gem lifetime and a save reload, then gets collected (`pt.wreck_gem_count()`, `pt.warp_to_wreck()`).

`playtests/abandon.play` runs dry: the robot radios a tow offer inside a tractor beam and "abandon ship" outside it. The abandoned ship (`DerelictShip`, group `derelicts`) keeps the hold, survives respawn and reload, and five PERFECT salvage hits recover all of it (`pt.derelict_count()` and `pt.abandoned_ship()` — both ignore deep-space wrecks, which share the `derelicts` group — and `pt.warp_to(pos)`).

`playtests/void.play` flies past the last orbit into the Void: the robot's warning, the stars draining, the dashboard rotting and dropping out, turning back in time, then staying too long and being consumed (`ConsumedState`, no wreck and no derelict) and relaunching. State is under `state.void` (`inside`, `depth`, `dread`, `shroud`, `exposure`); the autoload is `get_node("/root/VoidZone")`.

`playtests/waypoint.play` sets tracking points on the star chart: the mark starts on the ship, the arrow keys drive it out into
empty space (`pt.node("system_map").cursor_world`), ENTER takes it as a `WAYPOINT`, ENTER over a body tracks the body instead so
the target rides its orbit, and DEL hands tracking back to home base (`.playtest/mark_*.png`).

`playtests/gate.play` flies in on Veld's dormant Gate, docks in its cradle, pays the 600 CR, and checks the
boot log brings the Module online (`gs.titan_influence()`), the ring lights purple, ESC leaves the terminal
without pausing, and the Module survives a reload (`.playtest/gate_*.png`). Helpers: `pt.gate("Veld")`,
`pt.park_at_gate(planet, dist)` (lined up on the cradle, matched to the Gate's orbit). FlyingState refuses to
dock for ~2s after an undock, so park, `wait 2.2`, park again, then `press action`.

`playtests/chart.play` checks the star chart starts blank and fills in: home and its station alone on a new
chart, powering Veld's Gate drawing the region in a piece at a time, the mark refusing an uncharted planet but
still taking a waypoint on it, a purple link between two powered Gates, and both regions surviving a reload
(`.playtest/chart_*.png`). Powering a Gate by hand (`eval pt.gate("Veld").power(gs)`) doesn't save on its own —
`eval pt.save_now()` before a `reload`.

`playtests/minimap.play` screenshots the minimap markers (ship arrow, station silhouette + beacon, shaded planets, scrap chunks, derelict pinned to the rim).

`playtests/alerts.play` forces low fuel / a full hold and screenshots the vapor trail, engine sputter, full-hold HUD and gems left floating (`.playtest/alert_*.png`).

`playtests/radio.play` departs the dock and checks the guide robot's transmission: typing, ENTER skip, TAB (`press radio_next`) advance/close, low-fuel auto-dismiss, the paused scrap tutorial, the out-of-fuel abandon-ship confirm, the abandon and explosion relaunch calls, and hiding behind menus (`.playtest/radio_*.png`). The controls (on undock) and scrap tutorials pause the game, so other scenarios first run `eval get_tree().root.get_node("RobotRadio").mark_seen("first_departure")` / `("first_scrap")`. `press space` (or `enter`/`radio_next`) finishes a line, then moves on. Game over is a radio call now: confirm it the same way (no GameOverMenu). The panel is `pt.node("radio_panel")`; the queue is `get_tree().root.get_node("RobotRadio")`. Expressions can't use `&"..."` literals — compare StringNames to plain strings.

`playtests/scanner.play` checks the Planetary Scanner: nothing scans without it, buying it at the home store (`gs.has_planet_scanner`), holding in Rook's gravity field fills the meter (leaving resets it), the typed survey readout (`pt.node("scan_panel").body_text()`), the sweep (`.playtest/scanner_4_sweep_*.png`) and the scan surviving a reload. Helpers: `pt.planet(name)`, `pt.park_near_planet(name, dist, [angle_deg])` (parks riding along with the planet, nose away), `pt.scanner()` (`.progress()`, `.target()`), `pt.redock()` (warp to the home port and dock).

`playtests/ores.play` scans Rook (scanner granted with `eval gs.set("has_planet_scanner", true)`) and checks its ore seam: buried before, surfaced with a ping, on the minimap, tracked as `ORE`, riding the orbit (`.playtest/ores_*.png`). Seams: `pt.ore("Rook")`, `pt.planet("Rook").get_ore_deposits()`.

`playtests/landing.play` lands on Rook's ground next to its seam (`PlanetLandedState`, not `LandedState`, which is docking): buried seams refuse, a fast drop bounces and hurts, sideways doesn't land, `land Rook` touches down, the landed ship rides the orbit with no fuel burn, thrust releases it to climb away on its own engines (no fee, no impulse), and too little fuel to make the climb runs the tank dry into `StrandedState` (`.playtest/landing_*.png`). Helpers: `pt.ore(planet)`, `pt.hover_over_ore(planet, height, [tilt_deg], [descent])`, `pt.altitude(planet)`, `pt.rel_speed(planet)`. Teleporting straight off the ground can re-use its contact for a frame: park away and wait a few frames first.

`playtests/drill.play` lands by Rook's rich seam and drills: four PERFECT layers to bedrock with the gems reaching the hold, banking (`press reverse_thrust`) after one layer, and an OVERLOAD kickback (`.playtest/drill_*.png`). Drive layers like harvest hits: `down action`, `wait_until pt.drill().timing.progress >= pt.drill().timing.perfect_start()`, `up action`. `pt.drill()` has `.layer`, `.layer_count()`, `.phase` (0 READY, 1 DIGGING, 2 DONE), `.end_reason`, `.dug`; the transcript logs `drill_struck` and `dig_ended`.

`playtests/regrow.play` spends Rook's seam with a banked dig (dim hexes, `SEAM SPENT` prompt, drill refuses), checks the refill timer survives a redock + reload, then fast-forwards it (`eval gs.tick_ore_regrowth(sec)`) and digs again (`.playtest/regrow_*.png`). `pt.ore("Rook").is_spent()`, `.regrow_left()`.

## Recording a video
```bash
godot --path . --write-movie .playtest/video/showcase.avi --fixed-fps 30 \
  -- --playtest=res://playtests/showcase.play --playtest-out="$PWD/.playtest/video" --playtest-fps=30
ffmpeg -i .playtest/video/showcase.avi -c:v libx264 -crf 22 -pix_fmt yuv420p out.mp4
```
`playtests/showcase.play` is a captioned tour of the scanner / ore / landing / drill loop (no asserts).
`--playtest-fps=<n>` holds each frame back to real time: Movie Maker renders faster than real time,
but orbits run on the wall clock, so without it the physics and the planets drift apart (landings fail).
`eval pt.caption("...")` puts a caption in the top-left corner; `pt.caption("")` clears it.

## Tips
- Godot releases held keys when the window loses focus; the driver re-presses anything held by `down`/`hold`.
- Screenshots need a window (not `--headless`). Read the PNG to actually look at it.
- If a session wedges: `kill $(cat .playtest/godot.pid)`. Log: `.playtest/godot.log`.
- Scenario runs have a 300s real-time watchdog (`--timeout S` to change).
- Reloading: use `reload`, not `eval main.call_deferred("load_game")` + a wait. Loads are async, and a docked ship autosaves while it refuels, so sentinel values can end up in the save.
- Flight keys are read in physics ticks: headless runs uncapped, so a `press thrust` tap can fall between ticks. Use `hold thrust 0.1`.
- Expressions can't assign: use `eval gs.set("credits", 100)`. Start coroutines with `eval main.call_deferred("load_game")`.
- After adding driver commands, update the doc comment at the top of `scripts/Playtest.gd` and this file.
