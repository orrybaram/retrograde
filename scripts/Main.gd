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
@onready var hud: Control = $"CanvasLayer/HUD"

var current_game_state: MainGameState = MainGameState.MENU
var last_game_over_reason: String = ""

func _ready() -> void:
	# Connect menu signals
	if start_menu:
		start_menu.start_game.connect(_on_start_game)
		start_menu.load_game.connect(_on_load_game)
	if game_over_menu:
		game_over_menu.relaunch_game.connect(_on_relaunch_game)
	
	# Connect ship signals
	if ship:
		ship.fuel_depleted.connect(_on_fuel_depleted)
	
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
		# Handle manual save with "F5" key
		elif event.keycode == KEY_F5:
			_manual_save()

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
	
	if system_map.visible:
		system_map.close_map()
	else:
		system_map.open_map()

func _manual_save() -> void:
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs and ship:
		# Show saving indicator
		if hud and hud.has_method("show_saving_indicator"):
			hud.show_saving_indicator()
		
		Save.save(gs, ship)
		
		# Hide saving indicator after a brief delay
		if hud and hud.has_method("hide_saving_indicator"):
			await get_tree().create_timer(0.5).timeout
			hud.hide_saving_indicator()
		
		print("Game saved!")

func _on_start_game() -> void:
	await start_game()

func _on_load_game() -> void:
	await load_game()

func _on_relaunch_game() -> void:
	reset_game()

func _on_fuel_depleted() -> void:
	if current_game_state == MainGameState.PLAYING and not game_over_pending:
		game_over_pending = true
		_show_game_over_delayed("Out of Fuel")

func start_game() -> void:
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
	
	# Spawn ship at ShipSpawn location (new game - use default spawn)
	if ship_spawner:
		await ship_spawner.spawn_ship_at_spawn_location()
	
	# Wait for loading animation to complete
	if loading_screen:
		await get_tree().create_timer(loading_screen.duration + 0.5).timeout
		loading_screen.hide_loading()
	
	# Show ship after spawning is complete
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = true
	
	# Now unpause and start playing
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING

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
	
	# Spawn ship at saved position
	if ship_spawner:
		var saved_spawn_pos = Save.load_spawn_position()
		if saved_spawn_pos != Vector2.ZERO:
			await ship_spawner.spawn_at_position(saved_spawn_pos)
		else:
			# Fallback to default spawn if no saved position
			await ship_spawner.spawn_ship_at_spawn_location()
	
	# Wait for loading animation to complete
	if loading_screen:
		await get_tree().create_timer(loading_screen.duration + 0.5).timeout
		loading_screen.hide_loading()
	
	# Show ship after spawning is complete
	if ship and ship.ship_polygon:
		ship.ship_polygon.visible = true
	
	# Now unpause and start playing
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING

func _show_game_over_delayed(reason: String) -> void:
	# Wait 2 seconds before showing game over menu
	await get_tree().create_timer(2.0).timeout
	show_game_over(reason)

func show_game_over(reason: String) -> void:
	# Store reason for cost calculation on relaunch
	last_game_over_reason = reason
	
	# Increment death counter
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
	var refuel_cost: int = 0
	var penalty_cost: int = 0
	
	if ship and gs:
		# Calculate refueling cost (fuel needed to fill tank)
		var fuel_needed = ship.max_fuel - ship.fuel
		refuel_cost = int(fuel_needed * Economy.REFUEL_COST_PER_POINT)
		
		# Calculate penalty based on game over reason
		if last_game_over_reason == "Ship Destroyed":
			penalty_cost = 20
		elif last_game_over_reason == "Out of Fuel":
			penalty_cost = 10
		
		# Deduct total cost from credits
		var total_cost = refuel_cost + penalty_cost
		gs.credits = max(0, gs.credits - total_cost)
		
		# Clear the reason after using it
		last_game_over_reason = ""
	
	# Reset ship state
	if ship:
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
	
	# Reset GameState (cargo only, preserve credits)
	# Note: gs was already retrieved above for cost calculation
	if gs:
		gs.clear_cargo()
	
	# Clear spawn override to ensure we use default spawn location (not saved position)
	if ship_spawner:
		ship_spawner.clear_override()
	
	# Respawn ship using ShipSpawner
	if ship_spawner:
		await ship_spawner.spawn_ship_at_spawn_location()
	
	# Hide game over menu and unpause
	if game_over_menu:
		game_over_menu.hide_menu()
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING
