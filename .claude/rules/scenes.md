---
paths:
  - "**/*.tscn"
  - "**/*.tres"
---

# Scene and resource files

- `.tscn` files can't reference autoloads, so colors in them are copied from `scripts/Colors.gd`
  exactly. Change the value there first and copy it, never pick a new one here.
- SR-7's features go in `entities/structures/SpaceStation.tscn`. The Sun Station
  (`SunStation.tscn`) is its own scene and must not inherit SR-7's: it did once, and SR-7-only
  Mounts showed up on it. Sharing code through `SunStation.gd extends SpaceStation` is fine.
- Don't park a scene's parts on its instance in `HomeSystem.tscn`; they belong in the scene.
- Renaming a script or scene: move it with `git mv` together with its `.uid` file, so the uid
  keeps resolving.
