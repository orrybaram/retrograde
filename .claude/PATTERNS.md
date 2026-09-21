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

## Sonar Resonance (hold `action`)

```
Ship._drive_sonar -> Ship.wants_sonar() -> SonarPulse.charging (held) -> fire() on release / cancel() if the key is taken
  -> one ring + SonarPulse.pulsed / EventBus.sonar_pulsed(origin)
```

- A tap of `action` (SPACE) sends one ring from the ship wherever it is free to act: flying, over a
  scrap, or sitting on a seam. Holding charges that single ring (`SonarPulse.strength_for`: +1x reach
  per `CHARGE_TIME`, uncapped) and it fires on release; there is no continuous emission. It is not gated on a harvest target; harvesting is what a ping does
  when a scrap or seam is in the rings. Puzzles that answer a ping listen on `EventBus.sonar_pulsed`.
- A state opts out by overriding `ShipState.allows_sonar()` (docked at a port or Gate, stranded,
  destroyed, consumed and carrying Freight all say no). A menu over the game (`FlyingState._is_ui_blocking_input`)
  also takes the key; a charge the key is taken from mid-hold is cancelled, not fired. Nothing else
  touches `SonarPulse.charging`.
- Playtest state reports it as `ship.sonar`.
- Rings run to `SonarPulse.END_RADIUS` (280). Things that **answer** a Sweep join group
  `sonar_listeners` with `sonar_point()` and `on_sonar_touched()`; SonarPulse calls the latter when
  a ring's edge actually reaches that point (`SonarPulse.time_to_reach`). An answer is drawn in
  `Colors.TITAN`, the one sanctioned non-Titan-body use of purple: whatever answers a Sweep is part
  of the Titan. Freight lights its Lug purple and sends a `SonarEcho` (small purple rings) back out.
  Scrap deliberately does not *answer* (docs/adr/0007) - no purple, no echo - but it listens too:
  it passes for debris (tinted `ScrapNode.DORMANT_COLOR`, no sparkles, off the minimap, takes no
  cut) until a ring reaches it, then `ScrapNode.reveal()` lights it up for the rest of its spawn and sends one cream `SonarEcho` ring back.
  Containers and derelicts opt out via `_hides_until_pinged()`. Playtest `stage_harvest` reveals.

## Freight (clamped to the nose, docs/adr/0012)

```
FlyingState._update_magnet: Lug within Freight.MAGNET_RANGE (no prompt text)
  -> hold action -> Freight.magnet_step each tick (pulled + turned into its pose) -> seated
  -> CarryingState.enter -> Ship.clamp_freight
CarryingState: hold action RELEASE_HOLD (0.8s; the action message is only a filling bar) -> FlyingState; exit() always calls Ship.release_freight
```

- `Freight` (`entities/freight/Freight.gd`) is a RigidBody2D in group `freight` with no gravity and no
  damping: released, it coasts with the ship's velocity and heading plus `Ship.RELEASE_DRIFT` off the nose (`Ship.release_freight`). Planet
  gravity only pulls `Ship` bodies anyway (`PlanetGravityField`). One Lug: `lug_position` + `lug_facing`.
- Clamped, the piece is reparented under the ship with `PROCESS_MODE_DISABLED` (out of the physics
  space), its outline is added to the ship as `FreightCollision`, and `Ship._apply_mass` sets mass,
  `center_of_mass` and `inertia` explicitly. Unladen it resets to the ship's own mass, centre (0,0)
  and engine-computed inertia.
- Turning reads `Ship.turn_ratio()` in `FlyingState.turned_spin`: 1.0 unladen (identical to before),
  softened inertia ratio loaded (`Ship.FREIGHT_TURN_EXPONENT`, wind-up `FlyingState.TURN_LAG`).
- Contacts on `FreightCollision` do no hull damage (`Ship.is_freight_shape`); bumping loose Freight
  only hurts above `Freight.KNOCK_DAMAGE_SPEED` (`FlyingState.knock_threshold`). Scrap and debris
  (`OrbitalNode`) handle hits per shape via `body_shape_entered`, bouncing loose Freight too. A carrying ship can't
  harvest (`ScrapInRangeState`) or touch down (`CarryingState._ground_contact`).
- Clamp and release both `Ship._clunk`: `ClampFX.burst` (smoke puff + sparks, own randomness),
  `Freight.punch()` and a camera bump.
- Spawn a test piece: dev panel SPAWN FREIGHT, or `pt.stage_freight()` in a playtest (`playtests/freight.play`).

## Terminal UI Patterns

Panel: `StyleBoxFlat: draw_center=false, border_width=2, border_color=Colors.UI_BORDER`

Title format: `/ S P A C E D  T I T L E /` - top-right corner, Colors.UI_BACKGROUND_SOLID behind text

Action rows:
```
>  ACTION NAME                    COST/VALUE    (selected: Colors.PRIMARY #E8C170)
   ACTION NAME                    COST/VALUE    (unselected)
   ACTION NAME                    COST/VALUE    (unavailable/owned: Colors.PRIMARY_DIM #6B5A34)
```

Full-screen terminal menus (the Log, the store) are built in code from shared parts:
- `TerminalWindow` (`ui/TerminalWindow.gd`): dimmed backdrop, centered bordered window, title/hint notches, `add_tabs()` for a row of tab notches in the top-left border, `animate_in()`, plus static builders (`label`, `header`, `rule`, `spacer`, `filler`, `box`).
- `RobotCard` (`ui/RobotCard.gd`): left column with the robot portrait, status tag, `say(text, expression)` typed dialogue and credits. The store uses it; the Log does not. No Automaton speaks from inside the Log -- it is the player's own instrument, read alone.
- `SegmentGauge` (`ui/SegmentGauge.gd`): segmented bar / tier pips.
- `LogUI` + `LogTab` (`ui/log/`): the Log's tabbed shell. Adding a tab is one `LogTab` subclass plus one entry in `LogUI.TABS`. The shell owns the notches, `TAB` / `Shift+TAB` cycling and the bottom-border hint; a tab owns its title, hint, contents and keys. UP / DOWN route into the active tab (Records moves its cursor with them). The Map tab (`MapTab`) wraps the `SystemMap` star chart and takes all four arrows for its mark; `M` opens the Log straight onto it (`LogUI.open_map()`).

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
FlyingState._ground_contact -> Touchdown rules -> PlanetLandedState (owns zoom and prompt; rings are the ship's sonar)
OreDeposit.tick_harvest (HarvestTiming per hit, GemData.ore_drops) -> ore.spend() -> GameState.spent_ore (refill timers)
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
- A seam is harvested with the *same* loop as a scrap node (`HarvestTiming` hold-and-release,
  `OreDeposit.HITS` / `RICH_HITS` hits, the last one the break). The seam owns the timing and its
  hits; `PlanetLandedState` feeds it the key and throws the gems. There is no separate drill.
- A seam is the payday: `GemData.ORE_ROLL_WEIGHTS` / `RICH_ROLL_WEIGHTS` skew to crystals and
  artifacts and every hit drops more than a scrap hit, so a seam is worth several scrap nodes
  (see OreHarvestTest).
- Tuning knobs: `PlanetScan.SCAN_TIME`, `Touchdown.*`, `OreDeposit.HITS` / `RICH_HITS`, `GemData.ORE_*`,
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

## Titan Influence (what it leaks into)

```
GameState.titan_influence() (0-5)
  -> TitanInfluence (all the tuning, pure + static)
    -> HudGlitch.baseline()      the dashboard never reads clean again
    -> RadioPanel._maybe_titan_flash -> RobotView.titan_flash()  the guide's face, for a moment
```

- Every knob lives in `scripts/TitanInfluence.gd`; nothing here touches gameplay.
- The baseline is capped under `HudGlitch.ROT_THRESHOLD`, so the Titan dims and blinks the
  readouts but never rots the characters — five Modules in, the HUD is still flyable.
- The Titan never moves the dashboard. Wander, rot and dropouts belong to the Void and to
  hull hits, which pass; the baseline doesn't, and a HUD that never stopped shaking couldn't
  be lived with. Each Module shows through `TitanInfluence.blink_gap()`, not through the
  Void's `_advance_cuts` curve, which barely moves down at baseline severities.
- From `FACE_MIN_INFLUENCE` (3) Modules on, roughly every second guide line flashes
  `Colors.TITAN` in `RobotView._face_color()`. Other speakers are left alone.

## Dev Panel (setting game state by hand)

```
F1 / ` -> DevPanel (ui/DevPanel.gd, CanvasLayer, group `dev_panel`)
  -> SHIP / UPGRADES / PROGRESS / WARP / SAVE sections of rows
    -> GameState, Ship, InventoryManager, Playtest's warp helpers
```

- Debug builds only: `_ready` frees the node when `OS.is_debug_build()` is false, and
  nothing else in the game refers to it.
- Only opens while `Main.is_playing()`, and pauses the tree. `Main._input` and
  `PauseMenu._input` both step aside while it is visible, so it owns I / M / ESC.
- TAB cycles sections, UP/DOWN picks a row, LEFT/RIGHT nudges a value, ENTER runs it
  (on a value row: jumps it to the top), ESC closes.
- Every row is absolute, not a flip: LEFT bottoms a value out, ENTER tops it out. That
  keeps a repeated key press harmless, which is also what lets `playtests/devpanel.play`
  drive it without racing the window's focus bounce.
- Warps close the panel before they move the ship: the physics server has to be running
  to take the new transform. They reuse `Playtest`'s helpers (`park_at_gate`,
  `park_near_planet`, `redock`, `warp_to`), so a warp lands where a scenario's would.
- `Ship.dev_invulnerable` / `Ship.dev_infinite_fuel` are the only gameplay hooks the panel
  adds; nothing but the panel writes them.
- Don't let the panel name a class that names it back (it reaches the pause menu through
  `CanvasItem`, not `PauseMenu`): a `class_name` cycle breaks the script class cache and
  takes the whole project's resource loading down with it.
