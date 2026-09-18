extends Node2D

## Root scene controller. Owns the MainGameState enum (MENU / PLAYING / GAME_OVER)
## and orchestrates transitions between StartMenu, active gameplay, PauseMenu,
## and the game-over radio call (RobotRadio). Connects ship signals (fuel_depleted)
## and EventBus events.

enum MainGameState {
	MENU,
	PLAYING,
	GAME_OVER
}

@onready var ship := $Ship
@onready var start_menu: StartMenu = $"CanvasLayer/StartMenu"
@onready var loading_screen: LoadingScreen = $"CanvasLayer/LoadingScreen"
@onready var inventory_ui: InventoryUI = $"CanvasLayer/InventoryUI"
@onready var ship_spawner: ShipSpawner = $ShipSpawner
@onready var system_map: SystemMap = $"CanvasLayer/SystemMap"
@onready var pause_menu: PauseMenu = $"CanvasLayer/PauseMenu"
@onready var hud: Control = $"CanvasLayer/HUD"

## Relaunch fee per game-over reason (a tractor-beam rescue is free).
const RELAUNCH_PENALTY := {"Ship Destroyed": 20, "Ship Abandoned": 10, "Consumed": 30}
## What the robot radios after each game-over reason. Its confirm line relaunches.
const GAME_OVER_MESSAGES := {
	"Ship Destroyed": RobotRadio.MSG_SHIP_DESTROYED,
	"Ship Abandoned": RobotRadio.MSG_SHIP_ABANDONED,
	"Tractor Beam": RobotRadio.MSG_TRACTOR_RESCUE,
	"Consumed": RobotRadio.MSG_VOID_CONSUMED,
}
## The dark takes a moment to finish closing before the robot tries the radio.
const CONSUMED_SILENCE := 2.4

var current_game_state: MainGameState = MainGameState.MENU
var last_game_over_reason: String = ""

func _ready() -> void:
	add_to_group("main")
	# Connect menu signals
	if start_menu:
		start_menu.start_game.connect(_on_start_game)
		start_menu.load_game.connect(_on_load_game)
	RobotRadio.confirmed.connect(_on_radio_confirmed)
	if pause_menu:
		pause_menu.quit_to_menu.connect(_on_quit_to_menu)
	
	# Connect ship signals
	if ship:
		ship.fuel_depleted.connect(_on_fuel_depleted)

	# Stranded ship: abandon it (or get towed inside a tractor beam)
	EventBus.abandon_ship_requested.connect(_on_abandon_ship_requested)

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

	if event is InputEventKey and event.pressed and not event.echo:
		# Handle inventory toggle with "i" key
		if event.keycode == KEY_I:
			_toggle_inventory()
		# Handle system map toggle with "m" key
		elif event.keycode == KEY_M:
			_toggle_system_map()
		# Handle ESC to close inventory or map
		elif event.keycode == KEY_ESCAPE:
			print("Escape key pressed")
			if inventory_ui and inventory_ui.visible:
				inventory_ui.close_inventory()
				get_viewport().set_input_as_handled()
			elif system_map and system_map.visible:
				system_map.close_map()
				get_viewport().set_input_as_handled()

func _toggle_inventory() -> void:
	if not inventory_ui:
		return

	# Don't toggle if other menus are open
	if start_menu and start_menu.visible:
		return
	if system_map and system_map.visible:
		return
	if pause_menu and pause_menu.visible:
		return

	if inventory_ui.visible:
		inventory_ui.close_inventory()
	else:
		inventory_ui.open_inventory()

func _toggle_system_map() -> void:
	if not system_map:
		return

	# Don't toggle if other menus are open
	if start_menu and start_menu.visible:
		return
	if inventory_ui and inventory_ui.visible:
		return
	if pause_menu and pause_menu.visible:
		return

	if system_map.visible:
		system_map.close_map()
	else:
		system_map.open_map()

func _on_start_game() -> void:
	await start_game()

func _on_load_game() -> void:
	await load_game()

func is_game_over() -> bool:
	return current_game_state == MainGameState.GAME_OVER

func _on_radio_confirmed(id: StringName) -> void:
	if not is_game_over():
		return
	for conv: RadioConversation in GAME_OVER_MESSAGES.values():
		if conv.id == id:
			reset_game()
			return

func _on_fuel_depleted() -> void:
	if current_game_state == MainGameState.PLAYING and not game_over_pending:
		# Transition ship to stranded state (player must abandon ship)
		if ship and ship.state_machine and ship.state_machine.has_state("StrandedState"):
			ship.state_machine.change_state("StrandedState")

func is_within_tractor_beam() -> bool:
	var stations = get_tree().get_nodes_in_group("space_stations")
	for station in stations:
		var tractor_beam = station.get_node_or_null("TractorBeamArea/TractorBeamCollision")
		if tractor_beam and tractor_beam.shape is CircleShape2D:
			var radius = tractor_beam.shape.radius
			var distance = ship.global_position.distance_to(station.global_position)
			if distance <= radius:
				return true
	return false

func _on_abandon_ship_requested() -> void:
	if current_game_state == MainGameState.PLAYING and not game_over_pending:
		game_over_pending = true
		# If within tractor beam range, rescue instead of death
		if ship and is_within_tractor_beam():
			_show_game_over_delayed("Tractor Beam")
			return
		# The ship stays adrift with its hold aboard, to be salvaged later
		var derelict := DerelictShip.abandon(ship) if ship else null
		var stranded := ship.state_machine.current_state as StrandedState if ship else null
		if derelict and stranded:
			stranded.abandon_to(derelict)
		_show_game_over_delayed("Ship Abandoned")

## Thirty seconds past the last orbit and the dark has the ship. Nothing explodes
## and nothing is left behind, so there's no wreck to salvage — just the silence
## before the robot works out what happened.
func _on_void_consumed() -> void:
	if current_game_state != MainGameState.PLAYING or game_over_pending:
		return
	game_over_pending = true
	if ship and ship.state_machine and ship.state_machine.has_state("ConsumedState"):
		ship.state_machine.change_state("ConsumedState")
	await get_tree().create_timer(CONSUMED_SILENCE).timeout
	show_game_over("Consumed")

func _on_quit_to_menu() -> void:
	current_game_state = MainGameState.MENU
	RobotRadio.silence()
	if start_menu:
		start_menu.show_menu()
	get_tree().paused = true

func start_game() -> void:
	if start_menu:
		start_menu.visible = false
	Gem.clear_all()
	DerelictShip.clear_all(get_tree())

	# Reset all game state for new game
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.reset_all_state()
	RobotRadio.reset()

	# Reset ship to initial state
	if ship:
		ship.reset_to_initial_state()

	# Hide ship while respawning to prevent showing at wrong location
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = false

	# Show loading screen animation
	if loading_screen:
		loading_screen.show_loading()

	# Unpause so spawner can work
	get_tree().paused = false

	# Wait a frame for scene to initialize
	await get_tree().process_frame

	# Spawn ship at default dock (new game)
	if ship_spawner:
		var dock = await ship_spawner.find_default_dock()
		if dock:
			await ship_spawner.spawn_at_dock(dock)
		else:
			push_warning("No default dock found for new game")

	# Notify that planets are in position (for new game, they're already at initial angles)
	# This triggers spawners to start
	EventBus.planets_restored.emit()

	# Hide loading screen
	if loading_screen:
		loading_screen.hide_loading()

	# Show ship after spawning is complete
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = true

	# Now unpause and start playing
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING
	EventBus.ship_respawned.emit()

func load_game() -> void:
	if start_menu:
		start_menu.visible = false

	# Hide ship while respawning to prevent showing at wrong location
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = false

	# Show loading screen animation
	if loading_screen:
		loading_screen.show_loading()

	# Unpause so spawner can work
	get_tree().paused = false

	# Wait a frame for scene to initialize
	await get_tree().process_frame

	# Load game state (credits, ship stats, inventory, upgrades)
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs and ship:
		Save.load_into(gs, ship)
		# Swap in the saved wrecks in one step, so no save in between can drop them
		Gem.clear_all()
		DerelictShip.clear_all(get_tree())
		Save.restore_wreck_gems(ship.get_parent())
		Save.restore_derelicts(ship.get_parent(), ship.ship_polygon)

	# Restore planet orbital angles
	Save.restore_planet_angles(get_tree())

	# Notify that planets have been restored (allows spawners to spawn at correct positions)
	EventBus.planets_restored.emit()

	await get_tree().physics_frame

	# Spawn ship at saved dock, or default if not found
	if ship_spawner:
		var dock = await ship_spawner.find_saved_dock()
		if not dock:
			dock = await ship_spawner.find_default_dock()
		if dock:
			await ship_spawner.spawn_at_dock(dock)
		else:
			push_warning("No dock found for load game")

	# Hide loading screen
	if loading_screen:
		loading_screen.hide_loading()

	# Show ship after spawning is complete
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = true

	# Now unpause and start playing
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING
	EventBus.ship_respawned.emit()

func _show_game_over_delayed(reason: String) -> void:
	# Let the explosion play out before the robot calls in
	await get_tree().create_timer(3.2).timeout
	show_game_over(reason)

func show_game_over(reason: String) -> void:
	# Store reason for cost calculation on relaunch
	last_game_over_reason = reason

	# Increment death counter (skip for tractor beam rescue)
	if reason != "Tractor Beam":
		var gs = get_tree().get_first_node_in_group("game_state") as GameState
		if gs:
			gs.death_count += 1

	current_game_state = MainGameState.GAME_OVER
	game_over_pending = false
	RobotRadio.silence()
	var message: RadioConversation = GAME_OVER_MESSAGES.get(reason, RobotRadio.MSG_SHIP_DESTROYED)
	# The hold isn't cleared until relaunch, so it still says what an abandoned hull carries
	var salvage := "Your cargo's still aboard, so salvage the wreck to get it back." \
			if InventoryManager.get_total_value() > 0 else "Salvage the empty hull for scrap sometime."
	RobotRadio.request(message.with_vars({"penalty": RELAUNCH_PENALTY.get(reason, 0), "salvage": salvage}))

func reset_game() -> void:
	game_over_pending = false
	Gem.clear_all(true)  # wreck gems stay where the ship blew up
	
	# Calculate relaunch costs before resetting ship
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	var penalty_cost: int = 0

	var is_tractor_beam_rescue = last_game_over_reason == "Tractor Beam"

	if ship and gs:
		# Penalty based on game over reason (no penalty for tractor beam)
		penalty_cost = RELAUNCH_PENALTY.get(last_game_over_reason, 0)

		# Deduct penalty from credits
		gs.credits = max(0, gs.credits - penalty_cost)

		# Clear the reason after using it
		last_game_over_reason = ""
	
	# Reset ship state
	if ship:
		# Reapply upgrades first to ensure max values are correct
		if gs:
			ship.reapply_all_upgrades(gs)
		
		ship.hull_strength = ship.max_hull
		ship.fuel = ship.max_fuel
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
		
		# Show ship visual again
		if ship.ship_polygon:
			ship.ship_polygon.visible = true
		
		# Reset boost particles material to original state
		ship.reset_boost_particles()
	
	# Reset GameState (cargo only, preserve credits) - skip for tractor beam rescue
	# Note: gs was already retrieved above for cost calculation
	if gs and not is_tractor_beam_rescue:
		gs.clear_cargo()
	
	# Spawn ship at saved dock, or default if not found
	if ship_spawner:
		var dock = await ship_spawner.find_saved_dock()
		if not dock:
			dock = await ship_spawner.find_default_dock()
		if dock:
			await ship_spawner.spawn_at_dock(dock)
		else:
			push_warning("No dock found for respawn")
	
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING

	# Save game after respawn (penalty already applied, ship reset at dock)
	var save_gs = get_tree().get_first_node_in_group("game_state") as GameState
	if save_gs and ship:
		Save.save(save_gs, ship)

	EventBus.ship_respawned.emit()
	EventBus.resources_refresh_requested.emit()
