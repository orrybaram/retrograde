extends Node2D

enum MainGameState {
	MENU,
	PLAYING,
	GAME_OVER
}

@onready var ship := $Ship
@onready var start_menu: StartMenu = $"CanvasLayer/StartMenu"
@onready var game_over_menu: GameOverMenu = $"CanvasLayer/GameOverMenu"

var current_game_state: MainGameState = MainGameState.MENU

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
	
	# Ensure ship is spawned on Earth when starting (before unpausing)
	await _spawn_ship_on_earth()
	
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
	
	# Reset GameState (cargo, credits)
	var gs = get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.credits = 0
		gs.clear_cargo()
	
	# Respawn ship on Earth
	await _spawn_ship_on_earth()
	
	# Hide game over menu and unpause
	if game_over_menu:
		game_over_menu.hide_menu()
	get_tree().paused = false
	current_game_state = MainGameState.PLAYING

func _spawn_ship_on_earth() -> void:
	var earth = get_node_or_null("Sun/Earth") as Planet
	if not earth or not ship:
		return
	
	# Wait for a frame to ensure Earth is initialized
	await get_tree().process_frame
	
	# If game is paused, temporarily unpause to let Earth calculate its orbital position
	var was_paused = get_tree().paused
	if was_paused:
		get_tree().paused = false
		# Wait for multiple physics frames to ensure Earth's position is calculated
		await get_tree().physics_frame
		await get_tree().physics_frame  # Extra frame to ensure position is stable
		get_tree().paused = true
	else:
		await get_tree().physics_frame
		await get_tree().physics_frame
	
	# Double-check Earth is still valid after physics frames
	if not is_instance_valid(earth) or not is_instance_valid(ship):
		return
	
	# Get Earth's global position (should now be correctly calculated)
	var earth_global_pos = earth.global_position
	var earth_radius = earth.radius
	
	# Debug: Print Earth position to verify
	print("Spawning ship on Earth at position: ", earth_global_pos, " radius: ", earth_radius)
		
	# Position ship on Earth's surface (above the center)
	var spawn_offset = Vector2(0, -earth_radius - 10)  # 10 pixels above surface
	ship.global_position = earth_global_pos + spawn_offset
	
	# Calculate rotation to face away from planet center
	# Direction vector from planet center to ship position
	var direction_from_center = (ship.global_position - earth_global_pos).normalized()
	# Calculate angle using atan2 (ship points RIGHT at 0°, so this makes it point away from center)
	ship.rotation = atan2(direction_from_center.y, direction_from_center.x)
	
	# Set ship's velocity to match Earth's orbital velocity (stationary relative to Earth)
	if is_instance_valid(earth):
		ship.linear_velocity = earth.linear_velocity
		print("Ship velocity set to: ", ship.linear_velocity)
	else:
		ship.linear_velocity = Vector2.ZERO
	
	print("Ship spawned at: ", ship.global_position)
