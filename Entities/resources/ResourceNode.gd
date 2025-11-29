extends Area2D
class_name ResourceNode

signal harvest_started
signal harvest_stopped
signal resource_depleted
signal resource_harvested(amount: int, kind: String, position: Vector2)
signal can_harvest_changed(can_harvest: bool)

@export var kind: String = "Scrap"
@export var amount: int = 10
@export var max_amount: int = 10
@export var harvest_rate: float = 5.0
@export var color: Color = Color(0.5, 0.5, 0.4)  # Default gray/brown for scrap
@export var min_scale: float = 0.8  # Minimum scale to prevent visual from getting too small

var _harvesting: bool = false
var _accum: float = 0.0
var _ship_in_range: Ship = null
var _orbital_planet: Planet = null
var _offset_from_planet: Vector2 = Vector2.ZERO
var _orbital_angle: float = 0.0
var _orbital_distance: float = 0.0
var _orbital_speed: float = 0.0
var _is_depleted: bool = false
var _trail_particles: GPUParticles2D = null
var _indicator_target = null  # ResourceIndicatorTarget
var _indicator_manager = null  # IndicatorManager
var _can_harvest: bool = false  # Track if harvesting is currently possible

# Mini-game integration
var _mini_game: HarvestMiniGame = null
var _mini_game_ui: HarvestMiniGameUI = null
var _mini_game_ui_scene: PackedScene = preload("res://minigames/harvest/HarvestMiniGameUI.tscn")

func _ready() -> void:
	add_to_group("resource_nodes")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Register with EventBus
	EventBus.register_resource_node(self)
	
	# Find trail particles
	_trail_particles = get_node_or_null("TrailParticles") as GPUParticles2D
	
	# Find IndicatorManager
	_indicator_manager = get_tree().get_first_node_in_group("indicator_manager")
	if not _indicator_manager:
		# Try to find it in the scene tree
		var main = get_tree().get_first_node_in_group("main")
		if main:
			_indicator_manager = main.get_node_or_null("CanvasLayer/IndicatorManager")
	
	# Initialize max_amount if not set
	if max_amount == 0:
		max_amount = amount
	
	# Initialize visual
	_update_visual()

func _on_body_entered(body: Node2D) -> void:
	if body is Ship:
		_ship_in_range = body as Ship
		_register_indicator()

func _on_body_exited(body: Node2D) -> void:
	if body is Ship and _ship_in_range == body:
		_ship_in_range = null
		if _harvesting:
			stop_harvest()
		# Update can_harvest state when ship leaves
		if _can_harvest:
			_can_harvest = false
			can_harvest_changed.emit(false)
		_unregister_indicator()
		
func _physics_process(delta: float) -> void:
	# Update position to orbit around planet if assigned
	if _orbital_planet and is_instance_valid(_orbital_planet):
		_update_orbital_position(delta)

func _process(_delta: float) -> void:
	# If mini-game UI is open, don't process input here (mini-game handles it)
	if _mini_game and not _mini_game.is_idle():
		return
	
	# Check if harvesting is possible (ship in range, has resources, and moving slowly)
	var new_can_harvest = false
	if _ship_in_range and amount > 0 and not _is_depleted and not _harvesting:
		var ship_velocity = _ship_in_range.linear_velocity
		var resource_velocity = get_orbital_velocity()
		var relative_velocity = ship_velocity - resource_velocity
		
		# Can harvest if moving slowly relative to resource (under 100 speed)
		if relative_velocity.length() < 100.0:
			new_can_harvest = true
	
	# Emit signal if state changed
	if new_can_harvest != _can_harvest:
		_can_harvest = new_can_harvest
		can_harvest_changed.emit(_can_harvest)
	
	# Check if we should open/close harvest UI: ship in range AND button pressed AND has resources
	if _ship_in_range and amount > 0 and not _is_depleted:
		# Use "scan" action for harvesting
		if Input.is_action_just_pressed("scan"):
			if not _harvesting:
				# First press: open UI
				start_harvest()
	else:
		# Ship moved away - close UI if open
		if _harvesting:
			stop_harvest()

func start_harvest() -> void:
	if _harvesting or amount <= 0 or _is_depleted:
		return
	
	# Check if ship is moving slowly relative to resource node (under 50 speed)
	if _ship_in_range and is_instance_valid(_ship_in_range):
		var ship_velocity = _ship_in_range.linear_velocity
		var resource_velocity = get_orbital_velocity()
		var relative_velocity = ship_velocity - resource_velocity
		
		if relative_velocity.length() >= 100.0:
			# Ship moving too fast relative to resource, don't start harvesting
			return
	
	_harvesting = true
	harvest_started.emit()
	
	# Transition ship to HarvestingState if ship is in range
	if _ship_in_range and is_instance_valid(_ship_in_range):
		var state_machine = _ship_in_range.get_node_or_null("StateMachine") as StateMachine
		if state_machine and state_machine.has_state("HarvestingState"):
			state_machine.change_state("HarvestingState")
	
	# Open mini-game UI
	_start_mini_game()

func stop_harvest() -> void:
	if not _harvesting:
		return
	
	# Stop mini-game if active
	if _mini_game:
		_stop_mini_game()
	
	_harvesting = false
	_accum = 0.0
	harvest_stopped.emit()
	
	# Transition ship back to FlyingState if ship is in range
	if _ship_in_range and is_instance_valid(_ship_in_range):
		var state_machine = _ship_in_range.get_node_or_null("StateMachine") as StateMachine
		if state_machine and state_machine.has_state("FlyingState"):
			state_machine.change_state("FlyingState")

## Check if this resource node is currently being harvested
func is_harvesting() -> bool:
	return _harvesting

## Get the orbital velocity of this resource node
func get_orbital_velocity() -> Vector2:
	if not _orbital_planet or not is_instance_valid(_orbital_planet):
		return Vector2.ZERO
	
	# Calculate tangential velocity from orbital motion
	# Velocity is perpendicular to radius: v = r * omega * (-sin(angle), cos(angle))
	var tangential_velocity = Vector2(-sin(_orbital_angle), cos(_orbital_angle)) * _orbital_distance * _orbital_speed
	
	# Add planet's velocity (if planet is moving)
	var planet_velocity = Vector2.ZERO
	if _orbital_planet is RigidBody2D:
		planet_velocity = (_orbital_planet as RigidBody2D).linear_velocity
	
	return tangential_velocity + planet_velocity

func _deplete_resource() -> void:
	if _is_depleted:
		return
	
	_is_depleted = true
	resource_depleted.emit()
	_unregister_indicator()
	
	# Unregister from EventBus
	EventBus.unregister_resource_node(self)
	
	# Stop mini-game if active
	if _mini_game:
		_stop_mini_game()
	
	# Stop harvesting
	if _harvesting:
		_harvesting = false
		harvest_stopped.emit()
	
	# Stop emitting new particles
	if _trail_particles:
		_trail_particles.emitting = false
	
	# Fade out the visual
	_start_fade_out()
	
	# Wait for particles to decay (5 seconds) then remove
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _start_fade_out() -> void:
	# Fade out visual over time, starting from current alpha
	var fade_duration = 2.0  # Fade out over 2 seconds
	var elapsed = 0.0
	
	# Get starting alpha from current visual state
	var visual = _find_visual_node()
	if not visual:
		return
	
	var start_alpha: float = 1.0
	if visual is Polygon2D:
		start_alpha = (visual as Polygon2D).color.a
	elif visual is ColorRect:
		start_alpha = (visual as ColorRect).modulate.a
	elif "modulate" in visual:
		start_alpha = visual.modulate.a
	
	# Fade from current alpha to 0
	while elapsed < fade_duration:
		elapsed += get_process_delta_time()
		var fade_progress = elapsed / fade_duration
		var current_alpha = lerp(start_alpha, 0.0, fade_progress)
		current_alpha = clamp(current_alpha, 0.0, 1.0)
		
		if visual:
			if visual is Polygon2D:
				var polygon = visual as Polygon2D
				var original_color = polygon.color
				polygon.color = Color(original_color.r, original_color.g, original_color.b, current_alpha)
			elif visual is ColorRect:
				var color_rect = visual as ColorRect
				color_rect.modulate = Color(color_rect.modulate.r, color_rect.modulate.g, color_rect.modulate.b, current_alpha)
			elif "modulate" in visual:
				var current_modulate = visual.modulate
				visual.modulate = Color(current_modulate.r, current_modulate.g, current_modulate.b, current_alpha)
		
		await get_tree().process_frame

func _update_orbital_position(delta: float) -> void:
	if not _orbital_planet or not is_instance_valid(_orbital_planet):
		return
	
	var planet_pos = _orbital_planet.global_position
	
	# Update orbital angle based on speed (resources orbit around planet)
	_orbital_angle += _orbital_speed * delta
	
	# Calculate new position in circular orbit around planet
	# This creates orbital velocity - resources move tangentially around the planet
	var orbital_offset = Vector2(cos(_orbital_angle), sin(_orbital_angle)) * _orbital_distance
	global_position = planet_pos + orbital_offset
	
	# Update stored offset for reference
	_offset_from_planet = orbital_offset

func _update_visual() -> void:
	# Don't update visual if depleted (fade-out handles it)
	if _is_depleted:
		return
	
	# Find visual child and update based on depletion ratio
	var visual = _find_visual_node()
	if not visual:
		return
	
	var depletion_ratio = float(amount) / float(max_amount) if max_amount > 0 else 1.0
	
	# Handle ColorRect specially
	if visual is ColorRect:
		var color_rect = visual as ColorRect
		var base_size = color_rect.custom_minimum_size if color_rect.custom_minimum_size != Vector2.ZERO else Vector2(30, 30)
		var new_size = base_size * depletion_ratio
		color_rect.size = new_size
		# Keep centered by updating offset
		color_rect.offset_left = -new_size.x / 2.0
		color_rect.offset_top = -new_size.y / 2.0
		color_rect.offset_right = new_size.x / 2.0
		color_rect.offset_bottom = new_size.y / 2.0
		var alpha = lerp(0.3, 1.0, depletion_ratio)
		color_rect.modulate = Color(color.r, color.g, color.b, alpha)
		return
	
	# Handle Polygon2D specially - preserve original scale and use color alpha
	if visual is Polygon2D:
		var polygon = visual as Polygon2D
		# Store original scale if not already stored
		if not polygon.has_meta("original_scale"):
			polygon.set_meta("original_scale", polygon.scale)
		
		var original_scale = polygon.get_meta("original_scale") as Vector2
		# Clamp scale to prevent it from going too low
		var scale_factor = max(depletion_ratio, min_scale)
		polygon.scale = original_scale * scale_factor
		
		# Update color alpha (Polygon2D uses color property, not modulate)
		var original_color = polygon.color
		var alpha = lerp(0.3, 1.0, depletion_ratio)
		polygon.color = Color(original_color.r, original_color.g, original_color.b, alpha)
		return
	
	# Handle other visual types (Sprite2D, etc.)
	if "scale" in visual:
		# Store original scale if not already stored
		if not visual.has_meta("original_scale"):
			visual.set_meta("original_scale", visual.scale)
		
		var original_scale = visual.get_meta("original_scale") as Vector2
		visual.scale = original_scale * depletion_ratio
	
	if "modulate" in visual:
		var alpha = lerp(0.3, 1.0, depletion_ratio)
		visual.modulate = Color(color.r, color.g, color.b, alpha)

func _find_visual_node() -> Node2D:
	# Look for common visual node types
	for child in get_children():
		if child is ColorRect or child is Sprite2D or child is Polygon2D:
			return child as Node2D
		# Also check for Circle2D or other visual nodes
		if child.name.contains("Visual") or child.name.contains("Sprite") or child.name.contains("Color"):
			return child as Node2D
	return null

func _register_indicator() -> void:
	if _indicator_manager and not _indicator_target and not _is_depleted:
		# Create ResourceIndicatorTarget using class_name
		var target_class = load("res://ui/indicators/ResourceIndicatorTarget.gd")
		if target_class:
			_indicator_target = target_class.new(self)
			if _indicator_manager.has_method("register_target"):
				_indicator_manager.register_target(_indicator_target)

func _unregister_indicator() -> void:
	if _indicator_manager and _indicator_target:
		_indicator_manager.unregister_target(_indicator_target)
		_indicator_target = null

func _start_mini_game() -> void:
	# Create mini-game instance
	_mini_game = HarvestMiniGame.new()
	add_child(_mini_game)
	
	# Connect signals
	_mini_game.harvest_success.connect(_on_mini_game_harvest_success)
	_mini_game.harvest_failed.connect(_on_mini_game_harvest_failed)
	_mini_game.ui_closed.connect(_on_mini_game_ui_closed)
	
	# Create and setup UI
	_setup_mini_game_ui()
	
	# Open the UI
	_mini_game.open_ui(kind, amount)

func _setup_mini_game_ui() -> void:
	# Find CanvasLayer to add UI to
	var main = get_tree().get_first_node_in_group("main")
	var canvas_layer: CanvasLayer = null
	
	if main:
		canvas_layer = main.get_node_or_null("CanvasLayer")
	
	if not canvas_layer:
		# Fallback: try to find CanvasLayer in scene tree
		canvas_layer = get_tree().root.find_child("CanvasLayer", true, false) as CanvasLayer
	
	if not canvas_layer:
		push_error("Could not find CanvasLayer for mini-game UI")
		return
	
	# Instantiate UI scene
	if _mini_game_ui_scene:
		_mini_game_ui = _mini_game_ui_scene.instantiate() as HarvestMiniGameUI
		if _mini_game_ui:
			canvas_layer.add_child(_mini_game_ui)
			_mini_game_ui.setup(_mini_game)

func _stop_mini_game() -> void:
	if _mini_game:
		_mini_game.close_ui()
	
	if _mini_game_ui:
		_mini_game_ui.cleanup()
		_mini_game_ui.queue_free()
		_mini_game_ui = null
	
	if _mini_game:
		_mini_game.queue_free()
		_mini_game = null

func _on_mini_game_harvest_success(harvested_amount: int) -> void:
	# Harvest successful - add all resources
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.add_cargo(kind, harvested_amount)
	
	# Emit signal for ResourceManager to handle indicator display
	resource_harvested.emit(harvested_amount, kind, global_position)
	
	amount = 0
	
	# Update visual
	if not _is_depleted:
		_update_visual()
	
	# Deplete resource
	if not _is_depleted:
		_deplete_resource()
		_stop_mini_game()

func _on_mini_game_harvest_failed() -> void:
	# Harvest failed - no resources collected, just close UI
	_stop_mini_game()

func _on_mini_game_ui_closed() -> void:
	# UI closed - stop harvesting
	stop_harvest()
