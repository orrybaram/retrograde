extends Area2D
class_name OrbitalNode

const OrbitalMotionClass = preload("res://scripts/OrbitalMotion.gd")

signal returned_to_pool

@export var color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var min_scale: float = 0.8

# Performance: Multi-tier distance-based processing
const ACTIVE_DISTANCE_SQ: float = 2500.0 * 2500.0
const MEDIUM_DISTANCE_SQ: float = 5000.0 * 5000.0
const SLEEP_DISTANCE_SQ: float = 8000.0 * 8000.0
const DISTANT_UPDATE_INTERVAL: int = 60
const SLEEP_CHECK_INTERVAL: int = 180
static var _cached_ship: Ship = null
var _update_offset: int = 0
var _cached_in_range: bool = false
var _is_sleeping: bool = false
var _last_range_check_frame: int = -1

# Collision damage/slowdown constants
const DAMAGE_SPEED_THRESHOLD: float = 150.0
const DAMAGE_PER_SPEED: float = 0.50
const COLLISION_SLOWDOWN: float = 0.3

var _orbital_motion = null
var _rotation_speed: float = 0.0
var _collision_area_cached: Area2D = null
var minimap_target: ResourceMinimapTarget = null
var spawner_key: String = ""
var skip_minimap_registration: bool = false

## Whether this node type uses harvest detection via root Area2D monitoring.
## ScrapNode sets true, DebrisNode sets false.
var _uses_harvest_detection: bool = false

func _ready() -> void:
	_update_offset = randi() % DISTANT_UPDATE_INTERVAL

	_setup_orbital_motion()

	# Collision Area2D (polygon) - for damage/slowdown
	_collision_area_cached = get_node_or_null("CollisionArea")
	if not _collision_area_cached:
		# Check one level deeper (Node2D/CollisionArea structure)
		for child in get_children():
			if child is Node2D:
				var ca = child.get_node_or_null("CollisionArea")
				if ca:
					_collision_area_cached = ca
					break

	if _collision_area_cached:
		_collision_area_cached.body_entered.connect(_on_collision_area_entered)
		_collision_area_cached.body_exited.connect(_on_collision_area_exited)

	# Clear cached ship when ship respawns
	if not EventBus.ship_respawned.is_connected(_on_ship_respawned):
		EventBus.ship_respawned.connect(_on_ship_respawned)

	# Initialize visual
	_update_visual()

	# Register with minimap
	_register_with_minimap.call_deferred()

func _setup_orbital_motion() -> void:
	_orbital_motion = OrbitalMotionClass.new()
	_orbital_motion.auto_initialize = false
	_orbital_motion.position_mode = OrbitalMotionClass.PositionMode.GLOBAL
	_orbital_motion.update_velocity = false
	_orbital_motion.enable_orbiting = false
	add_child(_orbital_motion)
	_orbital_motion.set_physics_process(false)

# Collision area (polygon) - for damage and slowdown when hitting precise shape
func _on_collision_area_entered(body: Node2D) -> void:
	if body is Ship:
		var relative_velocity = body.linear_velocity - get_orbital_velocity()
		var relative_speed = relative_velocity.length()

		if relative_speed > 50.0:
			body.linear_velocity = lerp(
				body.linear_velocity,
				get_orbital_velocity(),
				1.0 - COLLISION_SLOWDOWN
			)

		if relative_speed > DAMAGE_SPEED_THRESHOLD:
			var damage = int((relative_speed - DAMAGE_SPEED_THRESHOLD) * DAMAGE_PER_SPEED)
			if damage > 0:
				body.take_damage(damage)

func _on_collision_area_exited(_body: Node2D) -> void:
	pass

func _physics_process(delta: float) -> void:
	var frame = Engine.get_physics_frames()

	# === SLEEPING RESOURCE CHECK ===
	if _is_sleeping:
		if (frame + _update_offset) % SLEEP_CHECK_INTERVAL != 0:
			return
		var dist_sq = _get_distance_squared_to_ship()
		if dist_sq < SLEEP_DISTANCE_SQ:
			_wake_up()
		return

	# === DISTANCE TIER CHECK ===
	var should_check_distance = _cached_in_range or ((frame + _update_offset) % DISTANT_UPDATE_INTERVAL == 0)

	var dist_sq: float = -1.0
	if should_check_distance:
		dist_sq = _get_distance_squared_to_ship()
		_cached_in_range = dist_sq <= ACTIVE_DISTANCE_SQ
		_last_range_check_frame = frame

		if dist_sq > SLEEP_DISTANCE_SQ:
			_go_to_sleep()
			return

	var in_range = _cached_in_range

	# === ORBITAL UPDATE ===
	var should_update_orbit: bool
	if in_range:
		should_update_orbit = true
	elif dist_sq > 0 and dist_sq <= MEDIUM_DISTANCE_SQ:
		should_update_orbit = (frame + _update_offset) % DISTANT_UPDATE_INTERVAL == 0
	else:
		should_update_orbit = (frame + _update_offset) % (DISTANT_UPDATE_INTERVAL * 2) == 0

	if should_update_orbit and _orbital_motion and _orbital_motion.initialized:
		if _orbital_motion.orbital_body and is_instance_valid(_orbital_motion.orbital_body):
			_orbital_motion.enable_orbiting = true
			_orbital_motion.update_orbit()
			_orbital_motion.enable_orbiting = false

	# === COLLISION TOGGLE ===
	if _collision_area_cached:
		if _collision_area_cached.monitoring != in_range:
			_collision_area_cached.monitoring = in_range
			_collision_area_cached.monitorable = in_range

	if not in_range:
		return

	# Apply rotation speed if set (only when in range)
	if _rotation_speed != 0.0:
		rotation += _rotation_speed * delta

func _get_distance_squared_to_ship() -> float:
	if not _cached_ship or not is_instance_valid(_cached_ship):
		_cached_ship = get_tree().get_first_node_in_group("ship") as Ship
	if not _cached_ship:
		return 0.0
	return global_position.distance_squared_to(_cached_ship.global_position)

func _is_within_active_range() -> bool:
	if not _cached_ship or not is_instance_valid(_cached_ship):
		_cached_ship = get_tree().get_first_node_in_group("ship") as Ship
	if not _cached_ship:
		return true
	return global_position.distance_squared_to(_cached_ship.global_position) <= ACTIVE_DISTANCE_SQ

func _go_to_sleep() -> void:
	_is_sleeping = true
	_cached_in_range = false
	if _uses_harvest_detection:
		monitoring = false
		monitorable = false
	if _collision_area_cached:
		_collision_area_cached.monitoring = false
		_collision_area_cached.monitorable = false
	visible = false

func _wake_up() -> void:
	_is_sleeping = false
	if _uses_harvest_detection:
		monitoring = true
		monitorable = true
	visible = true

func get_orbital_velocity() -> Vector2:
	if not _orbital_motion or not _orbital_motion.initialized:
		return Vector2.ZERO
	return _orbital_motion.get_full_velocity()

## Called when retrieved from pool. Re-register with systems.
func on_spawn() -> void:
	_is_sleeping = false
	_cached_in_range = false

	if _uses_harvest_detection:
		monitoring = true
		monitorable = true

	# Recache collision area
	_collision_area_cached = get_node_or_null("CollisionArea")
	if not _collision_area_cached:
		for child in get_children():
			if child is Node2D:
				var ca = child.get_node_or_null("CollisionArea")
				if ca:
					_collision_area_cached = ca
					break
	if _collision_area_cached:
		_collision_area_cached.monitoring = false
		_collision_area_cached.monitorable = false

	if not _orbital_motion:
		_setup_orbital_motion()

	_register_with_minimap.call_deferred()

	_update_offset = randi() % DISTANT_UPDATE_INTERVAL

## Called when returning to pool. Unregister and reset all state.
func on_despawn() -> void:
	# Unregister from minimap
	if minimap_target:
		var minimap = Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

	# Reset state variables
	_cached_in_range = false
	_last_range_check_frame = -1
	_is_sleeping = false
	spawner_key = ""
	skip_minimap_registration = false

	# Reset orbital motion
	if _orbital_motion:
		_orbital_motion.initialized = false
		_orbital_motion.orbital_body = null
		_orbital_motion.orbital_angle = 0.0
		_orbital_motion.enable_orbiting = false

	_reset_visual_state()

	rotation = 0.0
	scale = Vector2.ONE

func _update_visual() -> void:
	# Base implementation - subclasses can override
	pass

func _find_visual_node() -> Node2D:
	for child in get_children():
		if child is ColorRect or child is Sprite2D or child is Polygon2D:
			return child as Node2D
		if child.name.contains("Visual") or child.name.contains("Sprite") or child.name.contains("Color"):
			return child as Node2D

	for child in get_children():
		if child is Node2D:
			if not child.visible:
				child.visible = true
			for grandchild in child.get_children():
				if grandchild is ColorRect or grandchild is Sprite2D or grandchild is Polygon2D:
					return grandchild as Node2D
				if grandchild.name.contains("Visual") or grandchild.name.contains("Sprite") or grandchild.name.contains("Color"):
					return grandchild as Node2D

	return null

func _reset_visual_state() -> void:
	var visual = _find_visual_node()
	if not visual:
		return

	if visual is Polygon2D:
		var polygon = visual as Polygon2D
		if polygon.has_meta("original_scale"):
			polygon.scale = polygon.get_meta("original_scale") as Vector2
			polygon.remove_meta("original_scale")
		var c = polygon.color
		polygon.color = Color(c.r, c.g, c.b, 1.0)
	elif visual is ColorRect:
		var color_rect = visual as ColorRect
		color_rect.modulate = Color(1, 1, 1, 1)
		color_rect.scale = Vector2.ONE
	elif "scale" in visual:
		if visual.has_meta("original_scale"):
			visual.scale = visual.get_meta("original_scale") as Vector2
			visual.remove_meta("original_scale")
		if "modulate" in visual:
			visual.modulate = Color(1, 1, 1, 1)

	if "visible" in visual:
		visual.visible = true

func _register_with_minimap() -> void:
	# Virtual - subclasses override
	pass

static func _on_ship_respawned() -> void:
	_cached_ship = null
