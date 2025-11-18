extends Area2D
class_name ResourceNode

signal harvest_started
signal harvest_stopped
signal resource_depleted

@export var kind: String = "Scrap"
@export var amount: int = 10
@export var max_amount: int = 10
@export var harvest_rate: float = 5.0
@export var color: Color = Color(0.5, 0.5, 0.4)  # Default gray/brown for scrap

var _harvesting: bool = false
var _accum: float = 0.0
var _ship_in_range: Ship = null
var _orbital_planet: Planet = null
var _offset_from_planet: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("resource_nodes")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Initialize max_amount if not set
	if max_amount == 0:
		max_amount = amount
	
	# Initialize visual
	_update_visual()

func _on_body_entered(body: Node2D) -> void:
	if body is Ship:
		_ship_in_range = body as Ship

func _on_body_exited(body: Node2D) -> void:
	if body is Ship and _ship_in_range == body:
		_ship_in_range = null
		if _harvesting:
			stop_harvest()

func _process(delta: float) -> void:
	# Update position to orbit with planet if assigned
	if _orbital_planet and is_instance_valid(_orbital_planet):
		global_position = _orbital_planet.global_position + _offset_from_planet
	
	# Check if we should harvest: ship in range AND button pressed AND has resources
	if _ship_in_range and amount > 0:
		# Use "scan" action for harvesting (or create "harvest" action)
		if Input.is_action_pressed("scan"):
			if not _harvesting:
				start_harvest()
		else:
			if _harvesting:
				stop_harvest()
	
	# Process harvesting
	if not _harvesting or amount <= 0:
		return
	
	_accum += harvest_rate * delta
	if _accum >= 1.0:
		var chunk = int(_accum)
		_accum -= float(chunk)
		var take = min(chunk, amount)
		amount -= take
		
		var gs := get_tree().get_first_node_in_group("game_state") as GameState
		if gs:
			gs.add_cargo(kind, take)
		
		# Update visual based on depletion
		_update_visual()
		
		if amount <= 0:
			resource_depleted.emit()
			queue_free()

func start_harvest() -> void:
	if _harvesting:
		return
	_harvesting = true
	harvest_started.emit()

func stop_harvest() -> void:
	if not _harvesting:
		return
	_harvesting = false
	_accum = 0.0
	harvest_stopped.emit()

func _update_visual() -> void:
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
		polygon.scale = original_scale * depletion_ratio
		
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
