extends Node2D

enum MainGameState {
	MENU,
	PLAYING,
	GAME_OVER
}

@onready var ship := $Ship
@onready var start_menu: StartMenu = $"CanvasLayer/StartMenu"
@onready var game_over_menu: GameOverMenu = $"CanvasLayer/GameOverMenu"
@onready var loading_screen: LoadingScreen = $"CanvasLayer/LoadingScreen"
@onready var inventory_ui: InventoryUI = $"CanvasLayer/InventoryUI"
@onready var ship_spawner: ShipSpawner = $ShipSpawner
@onready var system_map: SystemMap = $"CanvasLayer/SystemMap"
@onready var pause_menu: PauseMenu = $"CanvasLayer/PauseMenu"
@onready var hud: Control = $"CanvasLayer/HUD"

var current_game_state: MainGameState = MainGameState.MENU
var last_game_over_reason: String = ""

func _ready() -> void:
	add_to_group("main")
	# Connect menu signals
	if start_menu:
		start_menu.start_game.connect(_on_start_game)
		start_menu.load_game.connect(_on_load_game)
	if game_over_menu:
		game_over_menu.relaunch_game.connect(_on_relaunch_game)
	if pause_menu:
		pause_menu.quit_to_menu.connect(_on_quit_to_menu)
	
	# Connect ship signals
	if ship:
		ship.fuel_depleted.connect(_on_fuel_depleted)

	# Connect rescue beacon signal
	EventBus.rescue_beacon_deployed.connect(_on_rescue_beacon_deployed)
	
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
	if game_over_menu and game_over_menu.visible:
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
	if game_over_menu and game_over_menu.visible:
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

func _on_relaunch_game() -> void:
	reset_game()

func _on_fuel_depleted() -> void:
	if current_game_state == MainGameState.PLAYING and not game_over_pending:
		# Transition ship to stranded state (player must deploy rescue beacon)
		if ship and ship.state_machine and ship.state_machine.has_state("StrandedState"):
			ship.state_machine.change_state("StrandedState")

func _is_within_tractor_beam() -> bool:
	var stations = get_tree().get_nodes_in_group("space_stations")
	for station in stations:
		var tractor_beam = station.get_node_or_null("TractorBeamArea/TractorBeamCollision")
		if tractor_beam and tractor_beam.shape is CircleShape2D:
			var radius = tractor_beam.shape.radius
			var distance = ship.global_position.distance_to(station.global_position)
			if distance <= radius:
				return true
	return false

func _on_rescue_beacon_deployed() -> void:
	if current_game_state == MainGameState.PLAYING and not game_over_pending:
		game_over_pending = true
		# If within tractor beam range, rescue instead of death
		if ship and _is_within_tractor_beam():
			_show_game_over_delayed("Tractor Beam")
		else:
			_show_game_over_delayed("Out of Fuel")

func _on_quit_to_menu() -> void:
	current_game_state = MainGameState.MENU
	if start_menu:
		start_menu.show_menu()
	get_tree().paused = true

func start_game() -> void:
	if start_menu:
		start_menu.visible = false

	# Reset all game state for new game
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.reset_all_state()

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
	# Wait 2 seconds before showing game over menu
	await get_tree().create_timer(2.0).timeout
	show_game_over(reason)

func show_game_over(reason: String) -> void:
	# Store reason for cost calculation on relaunch
	last_game_over_reason = reason

	# Increment death counter (skip for tractor beam rescue)
	if reason != "Tractor Beam":
		var gs = get_tree().get_first_node_in_group("game_state") as GameState
		if gs:
			gs.death_count += 1

	# Don't pause - physics should continue during game over
	if game_over_menu:
		game_over_menu.show_menu(reason)
	current_game_state = MainGameState.GAME_OVER
	game_over_pending = false

func reset_game() -> void:
	game_over_pending = false
	
	# Calculate relaunch costs before resetting ship
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	var penalty_cost: int = 0

	var is_tractor_beam_rescue = last_game_over_reason == "Tractor Beam"

	if ship and gs:
		# Calculate penalty based on game over reason (no penalty for tractor beam)
		if last_game_over_reason == "Ship Destroyed":
			penalty_cost = 20
		elif last_game_over_reason == "Out of Fuel":
			penalty_cost = 10

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
	
	# Hide game over menu and unpause
	if game_over_menu:
		game_over_menu.hide_menu()
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING

	# Save game after respawn (penalty already applied, ship reset at dock)
	var save_gs = get_tree().get_first_node_in_group("game_state") as GameState
	if save_gs and ship:
		Save.save(save_gs, ship)

	EventBus.ship_respawned.emit()
