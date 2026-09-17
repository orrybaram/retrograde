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

## Robot Radio (guide robot help messages)

```
EventBus.radio_message_requested(conv) -> RobotRadio (autoload: RadioQueue + show-once flags) -> RadioPanel (HUD)
```

- Data: `RadioConversation` (id, priority, once, lines) of `RadioLine` (speaker, text, expression, glitch).
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
