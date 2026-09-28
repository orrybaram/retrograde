extends Node2D

## Root scene controller. Owns the MainGameState enum (MENU / PLAYING / GAME_OVER)
## and orchestrates transitions between StartMenu, active gameplay, PauseMenu,
## and the relaunch after a game over. Connects ship signals (drive.depleted)
## and EventBus events.

enum MainGameState {
	MENU,
	PLAYING,
	GAME_OVER
}

@onready var ship := $Ship
@onready var start_menu: StartMenu = $"CanvasLayer/StartMenu"
@onready var loading_screen: LoadingScreen = $"CanvasLayer/LoadingScreen"
@onready var intro_screen: IntroScreen = $"CanvasLayer/IntroScreen"
@onready var log_ui: LogUI = $"CanvasLayer/LogUI"
@onready var ship_spawner: ShipSpawner = $ShipSpawner
@onready var pause_menu: PauseMenu = $"CanvasLayer/PauseMenu"
@onready var hud: Control = $"CanvasLayer/HUD"

## What UNIT-7 radios once the next clone is up, per game-over reason. Nothing to
## confirm: the relaunch has already happened (and RobotRadio drops it before Act 1 ends).
const GAME_OVER_MESSAGES := {
	"Ship Destroyed": RobotRadio.MSG_SHIP_DESTROYED,
	"Consumed": RobotRadio.MSG_VOID_CONSUMED,
}
## The dark takes a moment to finish closing before the next clone comes up.
const CONSUMED_SILENCE := 2.4
## Waking up (docs/DESIGN.md "Minute 1-2"): the screen holds dark for a beat before
## the world comes up, so a run opens on silence instead of a cut.
const WAKE_BLACK_HOLD := 0.8
const WAKE_FADE_TIME := 1.8

var current_game_state: MainGameState = MainGameState.MENU
var last_game_over_reason: String = ""
## Waking up runs on a real playthrough, but not under the playtest driver: it would
## darken every scenario's opening frames and push back its first key press.
## playtests/intro.play sets this to cover the sequence itself.
var force_wake_sequence := false
## The manual diagnostic (BootLog) locks the controls, so scenarios run without it unless
## they ask: playtests/boot_log.play sets this.
var force_boot_log := false
## Black sheet above every layer, used for the wake-up fade. Built in code so it
## sits outside CanvasLayer (Playtest.visible_ui() only scans that one).
var _fade_rect: ColorRect = null
## Whether the last spawn ran the boot terminal (only a powered station boots).
var booted_last_spawn := false

func _ready() -> void:
	add_to_group("main")
	# The game's Progress ledger and radio tips write through to the save file; every other
	# GameState and radio (tests, labs) keeps them in memory.
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.progress = Progress.new(Progress.FileStore.new(Playtest.save_path()))
	RobotRadio.save_path = Playtest.save_path()
	_build_fade_overlay()
	# Connect menu signals
	if start_menu:
		start_menu.start_game.connect(_on_start_game)
		start_menu.load_game.connect(_on_load_game)
	RobotRadio.line_started.connect(_on_radio_line_started)
	if pause_menu:
		pause_menu.quit_to_menu.connect(_on_quit_to_menu)
	
	# Connect ship signals
	if ship:
		ship.drive.depleted.connect(_on_fuel_depleted)

	# The Void ran its clock out
	VoidZone.consumed.connect(_on_void_consumed)
	
	# Start with menu visible and game paused
	if start_menu:
		start_menu.show_menu()
	get_tree().paused = true
	
	# Hide ship initially - it will be spawned when game starts
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = false

var game_over_pending: bool = false

func _process(_delta: float) -> void:
	# Check if ship is destroyed
	if current_game_state == MainGameState.PLAYING and ship and not game_over_pending:
		if ship.is_destroyed():
			game_over_pending = true
			_show_game_over_delayed("Ship Destroyed")

func _input(event: InputEvent) -> void:
	if current_game_state != MainGameState.PLAYING:
		return
	# The dev panel owns every key while it is up, the Log and chart shortcuts included.
	var dev_panel := get_tree().get_first_node_in_group("dev_panel") as DevPanel
	if dev_panel and dev_panel.visible:
		return

	if event.is_action_pressed(&"open_log"):
		_toggle_log()
	# Straight to the Log's star chart tab
	elif event.is_action_pressed(&"open_map"):
		_toggle_system_map()
	# BACK closes the Log (the chart included)
	elif event.is_action_pressed(&"menu_back") and log_ui and log_ui.visible:
		log_ui.close_log()
		get_viewport().set_input_as_handled()

## A transmission that pauses the game has to be answered, and the radio panel
## steps aside for any open menu. So the menus go instead: otherwise the pause
## holds with nothing on screen able to clear it.
func _on_radio_line_started(_line: RadioLine, conversation: RadioConversation) -> void:
	if conversation == null or not conversation.pause_game:
		return
	if log_ui and log_ui.visible:
		log_ui.close_log()

func _toggle_log() -> void:
	if not log_ui:
		return

	# Don't toggle if other menus are open
	if start_menu and start_menu.visible:
		return
	if pause_menu and pause_menu.visible:
		return

	if log_ui.visible:
		log_ui.close_log()
	else:
		log_ui.open_log()

## M opens the Log on its star chart, jumps to the chart from another tab, and closes
## the Log when the chart is already up.
func _toggle_system_map() -> void:
	if not log_ui:
		return

	# Don't toggle if other menus are open
	if start_menu and start_menu.visible:
		return
	if pause_menu and pause_menu.visible:
		return

	if log_ui.is_on_map():
		log_ui.close_log()
	else:
		log_ui.open_map()

func _on_start_game() -> void:
	# Only New Game opens on the intro: a continue or a relaunch skips straight past it.
	if intro_screen and _wake_enabled():
		if start_menu:
			start_menu.visible = false
		await intro_screen.play()
	await start_game()

func _on_load_game() -> void:
	await load_game()

func is_game_over() -> bool:
	return current_game_state == MainGameState.GAME_OVER

## Flying, with no game-over call up: the only time the dev panel will open.
func is_playing() -> bool:
	return current_game_state == MainGameState.PLAYING

## Running the tank dry no longer takes the ship away. Fuel is only ever spent on the
## boost, so an empty tank costs the boost and nothing else - ordinary thrust still flies.
func _on_fuel_depleted() -> void:
	pass

## Thirty seconds past the last orbit and the dark has the ship. Nothing explodes
## and nothing is left behind, so there's no wreck to salvage — just a beat of
## silence before the next clone comes up and the robot works out what happened.
func _on_void_consumed() -> void:
	if current_game_state != MainGameState.PLAYING or game_over_pending:
		return
	game_over_pending = true
	if ship:
		ship.surrender_to_void()
	await get_tree().create_timer(CONSUMED_SILENCE).timeout
	show_game_over("Consumed")

## Checked when a game starts, not at init: Playtest.active is still false while the
## main scene is being built, so reading it any earlier is a race.
func _wake_enabled() -> bool:
	return force_wake_sequence or not Playtest.active

## A full-screen sheet on its own layer, above the HUD and every UI panel.
func _build_fade_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = 45  # above VoidShroud (40), which mustn't show through the dark
	add_child(layer)
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.color = Color(Colors.SPACE_BG, 0.0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.process_mode = Node.PROCESS_MODE_ALWAYS  # so it tweens while paused
	_fade_rect.visible = false
	layer.add_child(_fade_rect)

## Hide the ship being placed. The boot terminal is the ship's computer coming up on a
## powered station (docs/DESIGN.md "Minute 0-1"), so it only runs once the core has been
## cold-started; until then the screen just goes dark. Returns whether it booted.
func _cover_spawn(powered: bool) -> bool:
	booted_last_spawn = powered and loading_screen != null
	if booted_last_spawn:
		loading_screen.show_loading()
		return true
	_black_out()
	return false

## Take the cover away again. Waking up goes dark either way, so hiding the boot terminal
## reveals black rather than the world: order matters, since the terminal holds for a few
## seconds and blacking out before that would hide it behind the fade sheet. With no
## waking up (the playtest driver), the dark comes straight off.
func _uncover_spawn(booting: bool, wake: bool) -> void:
	if booting:
		await loading_screen.hide_loading(wake)
	if wake:
		_black_out()
	elif _fade_rect:
		_fade_rect.visible = false

## Goes dark immediately.
func _black_out() -> void:
	if _fade_rect == null:
		return
	_fade_rect.color.a = 1.0
	_fade_rect.visible = true

## Holds the dark for a beat, then brings the world up. Deliberately does not pause:
## the ship latches onto its dock over the frames right after spawning, and freezing
## the tree here leaves it adrift in FlyingState instead of docked.
func _wake_from_black() -> void:
	if _fade_rect == null:
		return
	_black_out()
	await get_tree().create_timer(WAKE_BLACK_HOLD, true, false, true).timeout
	var tween := _fade_rect.create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, WAKE_FADE_TIME)
	await tween.finished
	_fade_rect.visible = false

func _on_quit_to_menu() -> void:
	current_game_state = MainGameState.MENU
	clear_screen_effects()
	RobotRadio.silence()
	if start_menu:
		start_menu.show_menu()
	get_tree().paused = true

## Every full-screen effect off at once - the Void's dark and static, the stars it put
## out, the hull alarm, the dashboard glitch - so a relaunch, a load or a new game boots
## onto a clean screen instead of easing out of the last one.
func clear_screen_effects() -> void:
	VoidZone.clear_now()
	get_tree().call_group("screen_effects", "clear_now")

## A new game, through the Session pipeline (Session.new_game). Main only wraps it: the
## menu goes, and the ship's manual diagnostic (BootLog) locks the controls from the first
## frame, through the wake, and hands them back once the clone is up.
func start_game() -> void:
	clear_screen_effects()
	var diagnostic := force_boot_log or not Playtest.active
	if diagnostic:
		get_tree().call_group("boot_log", "prepare")
	if start_menu:
		start_menu.visible = false
	var session := _session()
	await session.run(session.new_game())
	# The ship checks its own controls, once, on a new game (docs/OPENING.md §6)
	if diagnostic:
		get_tree().call_group("boot_log", "begin")

## Continue the save, through the Session pipeline (Session.resume).
func load_game() -> void:
	clear_screen_effects()
	get_tree().call_group("boot_log", "forget")  # a continue never owes the diagnostic
	if start_menu:
		start_menu.visible = false
	var session := _session()
	await session.run(session.resume())

func _show_game_over_delayed(reason: String) -> void:
	# Let the explosion play out before the next clone comes up
	await get_tree().create_timer(3.2).timeout
	show_game_over(reason)

## The ship is lost: count it and relaunch straight away, with nothing to confirm. Once
## the next clone is up, UNIT-7 has its say about what happened.
func show_game_over(reason: String) -> void:
	last_game_over_reason = reason
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.death_count += 1

	current_game_state = MainGameState.GAME_OVER
	game_over_pending = false
	RobotRadio.silence()
	await reset_game()
	RobotRadio.request(GAME_OVER_MESSAGES.get(reason, RobotRadio.MSG_SHIP_DESTROYED))

## The next clone comes up at home, through the Session pipeline (Session.relaunch).
func reset_game() -> void:
	game_over_pending = false
	last_game_over_reason = ""  # a relaunch costs no Stores, whatever the reason
	clear_screen_effects()
	# A clone lost mid-diagnostic comes up locked where it left off (BootLog)
	get_tree().call_group("boot_log", "arm")
	var session := _session()
	await session.run(session.relaunch())
	get_tree().call_group("boot_log", "begin")

## The pipeline that brings a clone up, around this scene's ship, spawner and screen.
func _session() -> Session:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	var session := Session.new(get_tree(), ship, ship_spawner, gs, MainScreen.new(self))
	session.live.connect(func() -> void: current_game_state = MainGameState.PLAYING)
	return session

## The spawn's cover as the player sees it: the boot terminal or the dark, then waking up.
class MainScreen extends Session.Screen:
	var _main: Node

	func _init(main: Node) -> void:
		_main = main

	func cover(boots: bool) -> bool:
		return _main._cover_spawn(boots)

	func uncover(booting: bool, wake: bool) -> void:
		await _main._uncover_spawn(booting, wake)

	func wakes() -> bool:
		return _main._wake_enabled()

	func wake_up() -> void:
		await _main._wake_from_black()
