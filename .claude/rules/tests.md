---
paths:
  - "test/**"
---

# Unit tests

- A suite is `test/<Name>Test.gd`, `extends GdUnitTestSuite`, with `func test_*()`. Wrap nodes
  in `auto_free()`.
- Keep file IO out of code a test reaches: the default save path in tests is the player's real
  save. A bare `GameState.new()` keeps its Progress ledger in memory; to test the file itself use
  `Progress.new(Progress.FileStore.new(path))`. `Session.resume` and the Save loaders take a path.
- Log tabs take `handle_action(&"menu_down")` and the like, not key events.
- A test that instances `SpaceStation.tscn` leaves Freight behind: end it with
  `Freight.clear_all(get_tree())`.
