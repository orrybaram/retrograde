# Retrograde - Development Guidelines

2D space exploration/trading game built in Godot 4.6. Retro terminal / CRT monitor aesthetic.

## Critical Rules

1. **Use the "Violet Signal" palette via `Colors`** - Every color comes from the `Colors` autoload (`Colors.PRIMARY`, `Colors.SPACE_BG`, `Colors.NAV`, etc.) in `scripts/Colors.gd`. Never hardcode color values; in BBCode use `Colors.hex(Colors.PRIMARY)`. Faded mustard `#E8C170` is the single UI color. Blue (`Colors.NAV`) is navigation only. Purple (`Colors.TITAN`) is reserved for the Titan and Artifacts, never decoration. In `.tscn` files (which can't reference autoloads) copy the exact values from `Colors.gd`.
2. **Monospace everything** - Font: Andale Mono. All text should feel like terminal output.
3. **Dark backgrounds** - Space and UI panels use olive-black `Colors.SPACE_BG` (`#14130F`), solid or 80-90% opacity. Not pure black.
4. **Arrow key navigation** - All terminal UIs use UP/DOWN + ENTER. No mouse-based UI.
5. **State machines for complex entities** - Use `StateMachine` + `State` subclasses pattern (see `scripts/StateMachine.gd`). States own their camera zoom, particles, and cleanup.

## Architecture Quick Reference

- State machine pattern: `scripts/StateMachine.gd` -> entity-specific base state -> concrete states
- UI: `Control` nodes with anchors, `CanvasLayer` for HUD
- Terminal UI panels: bordered `StyleBoxFlat` (draw_center=false), mustard (`Colors.UI_BORDER`) border, spaced letter headers (`S T A T U S`)
- Action rows: `>` prefix for selected, dimmed `Colors.PRIMARY_DIM` (`#6B5A34`) for unavailable

For detailed patterns and examples, see `@.claude/PATTERNS.md`.

## Running & Testing

Godot 4.6 CLI is `godot` (symlink to `/Applications/Godot.app/Contents/MacOS/Godot`).

- `tools/test.sh` — run all gdUnit4 suites in `test/` headless (exit 0 = pass). Single suite: `tools/test.sh -a res://test/GemDataTest.gd`
- `tools/smoke.sh [frames]` — boot main scene headless, fails on any ERROR or path case mismatch
- `tools/play.sh playtests/launch.play` — play the real game from a scenario (key input, asserts, screenshots in `.playtest/`). `tools/play.sh serve` + `tools/playctl <cmd>` to drive it live. See `.claude/skills/playtest/SKILL.md`.
- `godot --headless --path . --import` — reimport after adding files / `class_name`s
- New tests: `test/<Name>Test.gd`, `extends GdUnitTestSuite`, `func test_*()`. Use `auto_free()` for nodes.
- `F1` (or `` ` ``) in a running debug build opens the dev panel (`ui/DevPanel.gd`): set fuel, hull, hold, credits, upgrades, Modules online, scans, and warp to any Gate or orbit.
- `res://` paths are case-sensitive on export — the folder is `entities/`, never `Entities/`.

## Scene Inspection

Prefer grepping `.tscn` files for specific lines over reading them whole — they are large and token-heavy.
