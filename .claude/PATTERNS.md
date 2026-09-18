# Retrograde - Patterns Reference

## State Machine Pattern

```
StateMachine (scripts/StateMachine.gd)
  -> Entity base state (e.g. entities/Ship/states/ShipState.gd)
    -> Concrete states (FlyingState, LandedState, HarvestingState, DestroyedState)
```

Each state implements: `enter()`, `exit()`, `physics_process(delta)`, `integrate_forces(state)`

- **Camera Zoom**: States control zoom. UI should NOT control zoom.
- **UI Blocking**: States check for blocking UI before transitions.
- **Resources**: Each state manages its own particles/sounds, cleans up in `exit()`.

Don't use state machines for: simple booleans, linear sequences (use await), pure data.

## Terminal UI Patterns

Panel: `StyleBoxFlat: draw_center=false, border_width=2, border_color=Colors.UI_BORDER`

Title format: `/ S P A C E D  T I T L E /` - top-right corner, Colors.UI_BACKGROUND_SOLID behind text

Action rows:
```
>  ACTION NAME                    COST/VALUE    (selected: Colors.PRIMARY #E8C170)
   ACTION NAME                    COST/VALUE    (unselected)
   ACTION NAME                    COST/VALUE    (unavailable/owned: Colors.PRIMARY_DIM #6B5A34)
```

Full-screen menus with UNIT-7 (inventory, store) are built in code from shared parts:
- `TerminalWindow` (`ui/TerminalWindow.gd`): dimmed backdrop, centered bordered window, title/hint tabs, `animate_in()`, plus static builders (`label`, `header`, `rule`, `spacer`, `filler`, `box`).
- `RobotCard` (`ui/RobotCard.gd`): left column with the robot portrait, status tag, `say(text, expression)` typed dialogue and credits.
- `SegmentGauge` (`ui/SegmentGauge.gd`): segmented bar / tier pips.

`Typewriter` lays text out after shaping (`VC_CHARS_AFTER_SHAPING`) so wrapped words don't jump lines while typing.

## The Void (hazard past the last orbit)

```
VoidZone (autoload: depth / dread / shroud, the 30s clock)
  -> StarField (star_fade uniform)     the sky drains
  -> VoidShroud (CanvasLayer 40)       the dark closes in, static, tears
  -> VoidGlitch (child of HUD)         readouts rot, panel jitters and cuts out
  -> SystemMap._draw_void              diagonal hazard hatching + boundary arcs
  -> Main._on_void_consumed            ConsumedState, then the game-over radio
```

`depth` is distance past `EDGE_RADIUS`; `dread` is the survival clock; `shroud = max(depth, dread)` is what every visual reads. `EDGE_RADIUS` must stay clear of the home station's apoapsis (~295000) — `VoidZoneTest` guards that.

## Robot Radio (guide robot help messages)

```
EventBus.radio_message_requested(conv) -> RobotRadio (autoload: RadioQueue + show-once flags) -> RadioPanel (HUD)
```

- Data: `RadioConversation` (id, priority, once, lines) of `RadioLine` (speaker, text, expression, glitch, garbled).
- `garbled` renders the line as line noise of the same shape (and keeps re-scrambling after it types), while `text` still holds what was meant. `expression` picks the face color in `RobotView._face_color()`: `titan` purple, `dead`/`lost` red, everything else mustard.
  Bundled messages live in `entities/Robot/radio/messages/*.tres`. `{key:<action>}` in text becomes the bound key.
- Higher priority interrupts (the interrupted one replays after); otherwise queued by priority, FIFO.
- `once` flags persist in the save's `[radio]` section (`Save.save_radio_seen`); new game resets them.
- Built-in triggers in `scripts/RobotRadio.gd`: undock, low fuel, hold full, scrap in range.
- Continue: SPACE (TAB/ENTER aliases) finishes the speech, then moves on (next / confirm / close).
  SPACE is also the flight action key, so it only drives conversations that pause the game or
  contain a confirm; other tips take TAB/ENTER and auto-dismiss after `RadioLine.read_time()`.
- `pause_game` conversations (every `once` tutorial: controls, scrap, low fuel, hold full; game-over calls) pause the tree and never
  time out. The unpause waits two physics frames so the closing SPACE isn't read as dock/harvest.
  A pausing conversation requested while a flight key (action/thrust/turn/boost) is down is held
  back until the keys have been up for `RobotRadio.PAUSE_GRACE_SEC` (1s), so mashing SPACE mid-harvest
  can't dismiss it unread.
- RadioPanel hides while a menu is open in the HUD's CanvasLayer. Transient overlays there (gem
  pickup popups) join the `hud_overlay` group so they don't count as menus.
- Confirm lines (`RadioLine.confirm`) show `> ACTION` and can't time out.
  `RobotRadio.confirm()` clears the radio, then emits `confirmed(id)`. Used for the out-of-fuel offer
  (StrandedState: abandon ship, or a tractor-beam tow inside a station's beam) and the game-over relaunch call (Main.GAME_OVER_MESSAGES, which replaced GameOverMenu).
- Only a powered ship (Flying/Harvesting) can harvest, so a stranded ship's SPACE stays with the radio.
- `{name}` placeholders come from `conv.with_vars({...})`.

## Planetary Scanner & Landing (DESIGN.md 4.10)

```
PlanetScanner (on Ship) -> PlanetScan (meter) + ScanSweep (on Planet) -> GameState.scanned_planets -> EventBus.planet_scanned
OreDeposit (child of Planet, grown by Planet._spawn_ore) -> surfaced on scan; minimap + OreTrackingTarget
FlyingState._ground_contact -> Touchdown rules -> PlanetLandedState (owns zoom, prompt, OreDrill)
OreDrill (HarvestTiming per layer, GemData.drill_drops) -> ore.spend() -> GameState.spent_ore (refill timers)
```

- `LandedState` is docking at a port; landing on a planet is `PlanetLandedState`;
  docking at a Gate is `GateDockedState`.
- Ore seams are hexagons just under the surface, seeded from the planet's save key, so they are
  the same every session and need no authoring in `HomeSystem.tscn`. There is no landing pad:
  land on plain ground within `OreDeposit.REACH` of a seam.
- Unlocks: upgrade path `planet_scanner`, flag `GameState.has_planet_scanner` (separate from Scanner PULSE).
- Save: `[scan] planets` and `[ore] regrow` (ore_id -> seconds left, never shown to the player).
  `Save.save_scanned_planets` / `Save.save_ore_regrowth` write only their section mid-flight; keep file IO
  out of code unit tests reach (the default save path in tests is the player's real save).
- Scanning only reaches **inner orbit** (`Planet.scan_radius()`, the first gravity ring clear of
  the surface), not the whole gravity field: you fly in close and hold there against the pull.
- Drilling is the payday: `GemData.DRILL_DEPTH_WEIGHTS` skews to crystals/artifacts and drops
  more per layer than a scrap hit, so a seam is worth several scrap nodes (see DrillTest).
- Tuning knobs: `PlanetScan.SCAN_TIME`, `Touchdown.*`, `OreDrill.*`, `GemData.DRILL_*`,
  `Planet.ORE_COUNT` / `MOON_ORE_COUNT`, `OreDeposit.REACH` / `DEPTH_*` / `*REGROW_TIME`.

## Gates (CONTEXT.md, docs/adr/0001)

```
Gate (child of Planet, drawn in _draw, group `gates` + `dockable`)
  -> FlyingState._attempt_dock -> GateDockedState (clamps to the cradle, owns zoom)
    -> GateTerminal (CanvasLayer) -> Gate.power(gs) -> GameState.powered_gates -> Save `[gates] powered`
```

- One dormant Gate per planet, placed in `HomeSystem.tscn` at `field_radius() x 1.5`. Its
  `save_key()` is the planet's, so the Module and its planet share one key.
- `GameState.titan_influence()` is how many Modules are online (0-5); the Core in the sun is a
  separate final state, not step 6. A Module never goes back offline.
- The dock surface is the cradle at the bottom of the ring, not the node origin:
  `Gate.get_dock_transform()`. Approach rules are the port's (distance 60, same alignment).
- The Gate is deliberately not pinned to the minimap rim - the minimap shows scanner range and
  nothing more, so a Gate has to be flown to (docs/adr/0002).
- Save: `[gates] powered`, written on power-up (a full autosave, which also banks the credits
  it cost) and on the normal save path. `Save.save_powered_gates` writes only that section.
- Unidentified (CONTEXT.md): a Gate reads `? ? ?` on the minimap until the ship comes within
  `Identifiable.RANGE` of it, at which point `Gate.identify()` records it in
  `GameState.identified_gates` (saved as `[gates] identified`) and the label flips to `GATE`.
  The guide's line (`gate_identified.tres`) is `once`, so only the first Gate the player ever
  reaches is spoken for; the rest flip silently. Flying to it is the only trigger — nothing
  points at a Gate beforehand. `scripts/Identifiable.gd` holds the range and the label drawing
  so later finds read the same way.
