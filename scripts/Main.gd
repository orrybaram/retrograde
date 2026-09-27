extends Node2D

## Root scene controller. Owns the MainGameState enum (MENU / PLAYING / GAME_OVER)
## and orchestrates transitions between StartMenu, active gameplay, PauseMenu,
## and the relaunch after a game over. Connects ship signals (fuel_depleted)
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
@onready var encounter_field: EncounterField = $EncounterField

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
## Black sheet above every layer, used for the wake-up fade. Built in code so it
## sits outside CanvasLayer (Playtest.visible_ui() only scans that one).
var _fade_rect: ColorRect = null
## Whether the last spawn ran the boot terminal (only a powered station boots).
var booted_last_spawn := false

func _ready() -> void:
	add_to_group("main")
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
		ship.fuel_depleted.connect(_on_fuel_depleted)

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
	if ship and ship.state_machine and ship.state_machine.has_state("ConsumedState"):
		ship.state_machine.change_state("ConsumedState")
	await get_tree().create_timer(CONSUMED_SILENCE).timeout
	show_game_over("Consumed")

## Put the ship at `dock` - unless it is a dock whose arm is still in (SR-7 before every
## piece is home, DockArm), which no ship can sit on: then adrift outside the station, the
## way a new game opens.
func _spawn_home(dock: Node2D) -> void:
	var port := dock as SpacePort
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if port and port.needs_core and not DockArm.should_be_out(gs):
		var station := await ship_spawner.find_home_station()
		if station:
			await ship_spawner.spawn_adrift(station, false)
			return
	await ship_spawner.spawn_at_dock(dock)

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

## Whether SR-7's core is running - the station is powered, Act 1 is behind the player.
func _station_powered() -> bool:
	return StationPower.is_powered(get_tree().get_first_node_in_group("game_state") as GameState)

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

static func _depth(n: Node) -> int:
	var d := 0
	while n.get_parent():
		n = n.get_parent()
		d += 1
	return d

func start_game() -> void:
	clear_screen_effects()
	if start_menu:
		start_menu.visible = false
	Gem.clear_all()
	DerelictShip.clear_all(get_tree())
	Freight.clear_all(get_tree())

	# Reset all game state for new game
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.reset_all_state()
	RobotRadio.reset()
	RobotRadio.guide_awake = false
	if encounter_field:
		encounter_field.reset()

	# Every orbit back to where the scene starts it, parents first so each body is placed
	# off its parent's new position
	var bodies := get_tree().get_nodes_in_group("orbiting_bodies")
	bodies.sort_custom(func(a: Node, b: Node) -> bool: return _depth(a) < _depth(b))
	for body in bodies:
		body.reset_orbit()

	# Reset ship to initial state
	if ship:
		ship.reset_to_initial_state()

	# Hide ship while respawning to prevent showing at wrong location
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = false

	# The boot terminal only runs on a powered station; before that the dark covers the spawn
	var booting := _cover_spawn(_station_powered())

	# Unpause so spawner can work
	get_tree().paused = false

	# Wait a frame for scene to initialize
	await get_tree().process_frame

	# A new game opens adrift outside SR-7, its dock's arm still in (docs/OPENING.md §3)
	if ship_spawner:
		var station := await ship_spawner.find_home_station()
		if station:
			await ship_spawner.spawn_adrift(station)
		else:
			push_warning("No home station found for new game")

	# Notify that planets are in position (for new game, they're already at initial angles)
	# This triggers spawners to start
	EventBus.planets_restored.emit()

	var wake := _wake_enabled()
	await _uncover_spawn(booting, wake)

	# Show ship after spawning is complete
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = true

	# Now unpause and start playing
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING
	EventBus.ship_respawned.emit()
	# The ship no longer starts on a dock, so nothing autosaves: save the fresh game now,
	# so CONTINUE never resumes the last one.
	if gs and ship:
		Save.save(gs, ship)

	# A beat of silence in the dark, then the lights come up on a dead station. Nobody is
	# on the comms: UNIT-7 is off until the core's cold start (RobotRadio.guide_awake).
	if wake:
		await _wake_from_black()

func load_game() -> void:
	clear_screen_effects()
	if start_menu:
		start_menu.visible = false

	# Hide ship while respawning to prevent showing at wrong location
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = false

	# The boot terminal only runs on a powered station; before that the dark covers the spawn
	var booting := _cover_spawn(Save.load_core_started())

	# Unpause so spawner can work
	get_tree().paused = false

	# Wait a frame for scene to initialize
	await get_tree().process_frame

	# Load game state (Stores, ship stats, inventory)
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	var clamped: Freight = null
	if gs and ship:
		Save.load_into(gs, ship)
		# Swap in the saved wrecks in one step, so no save in between can drop them
		Gem.clear_all()
		DerelictShip.clear_all(get_tree())
		Freight.clear_all(get_tree())
		Save.restore_wreck_gems(ship.get_parent())
		Save.restore_derelicts(ship.get_parent(), ship.ship_polygon)
		clamped = Save.restore_freight(ship.get_parent())

	if encounter_field:
		encounter_field.restore(Save.load_encounters())

	# Restore planet orbital angles
	Save.restore_planet_angles(get_tree())

	# Notify that planets have been restored (allows spawners to spawn at correct positions)
	EventBus.planets_restored.emit()

	await get_tree().physics_frame

	# Saved with a load clamped: back in flight where it was, with the load on the nose.
	# Otherwise, spawn ship at saved dock, or default if not found
	if ship_spawner and clamped:
		await ship_spawner.spawn_in_flight(Save.load_spawn_position(), Save.load_spawn_rotation(), Save.load_spawn_velocity())
		if is_instance_valid(clamped):
			ship.clamp_freight(clamped, true)
			ship.state_machine.change_state("CarryingState")
	elif ship_spawner:
		var dock = await ship_spawner.find_saved_dock()
		if not dock:
			dock = await ship_spawner.find_default_dock()
		if dock:
			await _spawn_home(dock)
		else:
			push_warning("No dock found for load game")

	var wake := _wake_enabled()
	await _uncover_spawn(booting, wake)

	# Show ship after spawning is complete
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = true

	# Now unpause and start playing
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING
	EventBus.ship_respawned.emit()
	# The ship no longer starts on a dock, so nothing autosaves: save the fresh game now,
	# so CONTINUE never resumes the last one.
	if gs and ship:
		Save.save(gs, ship)

	# Every waking starts the same way, continue or not
	if wake:
		await _wake_from_black()

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

func reset_game() -> void:
	game_over_pending = false
	clear_screen_effects()
	# Lost with a load still on the nose: it stays out here, where the ship was
	if ship and ship.is_carrying():
		ship.release_freight()
	Gem.clear_all(true)  # wreck gems stay where the ship blew up

	# A relaunch is another clone coming up, so it boots the same way a new game does
	var wake := _wake_enabled()
	var booting := _cover_spawn(_station_powered())
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = false

	# A relaunch costs no Stores, whatever the reason
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	last_game_over_reason = ""

	# Reset ship state
	if ship:
		ship.hull_strength = ship.max_hull
		ship.top_up_to_free_floor(gs)
		ship.linear_velocity = Vector2.ZERO
		ship.angular_velocity = 0.0
		ship.rotation = 0.0  # Reset rotation
		
		# Reset camera shake values (prevents shake from persisting after explosion)
		ship.camera_shake_time = 0.0
		ship.damage_shake_time = 0.0
		ship.damage_shake_current_intensity = 0.0
		
		# Reset ship state machine to FlyingState
		if ship.state_machine and ship.state_machine.has_state("FlyingState"):
			ship.state_machine.change_state("FlyingState")
		
		# Re-enable ship controls
		ship.set_process(true)
		ship.set_physics_process(true)
		
		# The ship stays hidden until it has been placed back on its dock, below

		# Reset boost particles material to original state
		ship.reset_boost_particles()
	
	# Reset GameState (cargo only, preserve Stores)
	if gs:
		gs.clear_cargo()
	
	# The next clone comes back at the saved dock, or the default if that one is gone.
	if ship_spawner:
		var dock: Node2D = await ship_spawner.find_saved_dock()
		if not dock:
			dock = await ship_spawner.find_default_dock()
		if dock:
			await _spawn_home(dock)
		else:
			push_warning("No dock found for respawn")

	await _uncover_spawn(booting, wake)
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = true

	get_tree().paused = false
	current_game_state = MainGameState.PLAYING

	# Save game after respawn (ship reset at dock)
	var save_gs = get_tree().get_first_node_in_group("game_state") as GameState
	if save_gs and ship:
		Save.save(save_gs, ship)

	EventBus.ship_respawned.emit()
	EventBus.resources_refresh_requested.emit()

	# Come up out of the dark the same way a new game does
	if wake:
		await _wake_from_black()
