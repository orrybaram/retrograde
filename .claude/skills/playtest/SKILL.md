---
name: playtest
description: Launch and play Retrograde to verify a change in the running game — inject real key presses, read game state and on-screen text as JSON, take screenshots, and assert outcomes. Use when asked to run/play/screenshot the game, or to confirm a gameplay/UI change actually works (not just unit tests).
---

# Playtesting Retrograde

Driver: `scripts/Playtest.gd` (autoload, inert unless launched with `--playtest`).
Everything goes through real `InputEventKey`s, so the game sees what a player would do.
Runs use `user://playtest_save.cfg`, so the player's real save is never touched.

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
| `wait_until <expr> [timeout]` | poll expression |
| `assert <expr> ["message"]` | record failure if falsy |
| `eval <expr>` / `state` / `screen` / `screenshot <name>` / `log <text>` / `quit` | observe |

Expressions are Godot `Expression`s with `ship`, `main`, `gs` (GameState), `inv` (InventoryManager), `bus`
(EventBus), `pt` (driver: `pt.state_name()`, `pt.visible_ui()`, `pt.screen_text()`, `pt.nearest(group)`,
`pt.node(group)`), and `self` = driver so `get_tree()` works.
`main.current_game_state`: 0 MENU, 1 PLAYING, 2 GAME_OVER.

## Game flow cheatsheet
- Boot → StartMenu (paused). `press enter` = NEW GAME. Ship spawns docked (`LandedState`).
- Docked: `press action` opens SpacePortDialogue; `down` + `enter` = DEPART. `thrust` undocks when no UI is open.
- In flight: `i` inventory, `m` system map, `esc` pause. Ship nose = +X; positive `bearing_deg` = target is to the right.
- `esc` closes the dock dialogue without pausing.

## Tips
- Screenshots need a window (not `--headless`). Read the PNG to actually look at it.
- If a session wedges: `kill $(cat .playtest/godot.pid)`. Log: `.playtest/godot.log`.
- Scenario runs have a 300s real-time watchdog (`--timeout S` to change).
- After adding driver commands, update the doc comment at the top of `scripts/Playtest.gd` and this file.
