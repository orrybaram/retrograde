extends Node2D

enum MainGameState {
	MENU,
	PLAYING,
	GAME_OVER
}

@onready var ship := $Ship
@onready var start_menu: StartMenu = $"CanvasLayer/StartMenu"
@onready var game_over_menu: GameOverMenu = $"CanvasLayer/GameOverMenu"
@onready var inventory_ui: InventoryUI = $"CanvasLayer/InventoryUI"
@onready var solar_system_generator: SolarSystemGenerator = $"SolarSystemGenerator"
@onready var system_map: SystemMap = $"CanvasLayer/SystemMap"

var current_game_state: MainGameState = MainGameState.MENU
var solar_system_generated: bool = false

func _ready() -> void:
	# Connect menu signals
	if start_menu:
		start_menu.start_game.connect(_on_start_game)
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

func _on_start_game() -> void:
	await start_game()

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
	
	# Generate solar system if not already generated
	if not solar_system_generated and solar_system_generator:
		get_tree().paused = false
		solar_system_generator.generate()
		solar_system_generated = true
		await get_tree().process_frame
	
	# Spawn ship at generated position
	await _spawn_ship_at_position(solar_system_generator.get_ship_spawn_position())
	
	# Show ship after spawning
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
	# Don't pause - physics should continue during game over
	if game_over_menu:
		game_over_menu.show_menu(reason)
	current_game_state = MainGameState.GAME_OVER
	game_over_pending = false

func reset_game() -> void:
	game_over_pending = false
	
	# Reset ship state
	if ship:
		ship.hull_strength = ship.max_hull
		ship.fuel = ship.max_fuel
		ship.linear_velocity = Vector2.ZERO
		ship.angular_velocity = 0.0
		ship.rotation = 0.0  # Reset rotation
		
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
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.clear_cargo()
	
	# Respawn ship at generated position
	if solar_system_generator:
		await _spawn_ship_at_position(solar_system_generator.get_ship_spawn_position())
	
	# Hide game over menu and unpause
	if game_over_menu:
		game_over_menu.hide_menu()
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING

func _spawn_ship_at_position(spawn_position: Vector2) -> void:
	if not ship:
		return
	
	# Wait for a frame to ensure everything is initialized
	await get_tree().process_frame
	
	# Temporarily unpause for physics if needed
	var was_paused = get_tree().paused
	if was_paused:
		get_tree().paused = false
		await get_tree().physics_frame
		get_tree().paused = true
	
	if not is_instance_valid(ship):
		return
	
	# Position ship at spawn location
	ship.global_position = spawn_position
	ship.rotation = 0  # Point right
	ship.linear_velocity = Vector2.ZERO
	ship.angular_velocity = 0.0
	
	print("Ship spawned at: ", ship.global_position)
