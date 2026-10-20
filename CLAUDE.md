# Retrograde

2D space exploration game in Godot 4.6 with a retro terminal / CRT look.


## Running and testing

- `tools/test.sh` runs every gdUnit4 suite headless (exit 0 = pass); one suite with
  `tools/test.sh -a res://test/GemDataTest.gd`.
- `tools/smoke.sh [frames]` boots the main scene headless and fails on any ERROR or path-case
  mismatch. Run it after changing an autoload or an `EventBus` signature: some load-order
  breaks only show at boot.
- `godot --headless --path . --import` after adding files or `class_name`s.
- Playing the real game (`tools/play.sh`, `tools/playctl`) is the `playtest` skill.
- `F1` (or `` ` ``) in a debug build opens the dev panel (`ui/DevPanel.gd`): fuel, hull, hold,
  Stores, progress, warps.
- `res://` paths are case-sensitive on export: the folder is `entities/`.

## Engine traps

- One GDScript parse error anywhere makes the radio's `.tres` conversations fail to load, and
  gdUnit then reports dozens of unrelated failures. Find the real error with
  `godot --headless --path . --import 2>&1 | grep -A1 "SCRIPT ERROR"`. Rebuild the cache with
  `rm -rf .godot`; deleting only the class cache leaves a half-built one that invents errors.
- At least one `EventBus` signal before `radio_message_requested` has to keep naming a gameplay
  `class_name` (`ScrapNode`, ...). Retyping them all to `Node` closes a load-order cycle
  through `RobotRadio` and the radio dies at boot.
- Don't let two classes name each other through `class_name` types (the dev panel reaches the
  pause menu through `CanvasItem` for this reason): the cycle breaks the script class cache
  for the whole project.
- Visual effects get their own `RandomNumberGenerator`. Gameplay rolls (gem scatter, drops)
  come off the shared `RNG.rng`, so an effect drawing from it changes what the game rolls.
- All UI sits under the `CanvasLayer/Glow/UI` canvas group. `clip_children` inside it draws as
  a solid white shape; mask with a shader (`ui/minimap/ScopeDisc.gdshader`). Reach panels by
  unique name (`%HUD`), never by path.

## Working in this checkout

Several agent sessions work in this checkout and its worktrees at once, and the Godot editor
is often open on it. Files you didn't touch can change under you.

- Don't `git stash`: it sweeps up another session's uncommitted work. To test against a clean
  tree, `git worktree add <scratch>/head-check HEAD` and work there.
- Cut new branches and worktrees from `main` by name. The checkout may be sitting on another
  session's branch, and branching from `HEAD` would carry its commits.
- If tests fail with parse errors in files you never edited, it is probably someone else's
  half-finished edit; check before chasing it.
- `.tscn` files are large: grep them for the lines you need instead of reading them whole.
