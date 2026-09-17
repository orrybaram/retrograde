@tool
extends GPUParticles2D
class_name SparkleParticles

## GPU particle effect for the harvesting beam. Switches between IDLE (ambient sparkle)
## and HARVESTING (directed arc toward ship) states. Trophy nodes emit yellow arcs.

const TROPHY_COLOR = Colors.YELLOW

enum State { IDLE, HARVESTING }

@export var is_trophy: bool = false:
	set(value):
		is_trophy = value
		if is_node_ready():
			_apply_state()

var _state := State.IDLE
var _harvest_target: Node2D = null
var _harvest_color: Color = Colors.PRIMARY
var _health_component: Node = null
var _hp_ratio: float = 1.0

var _original_mat: ParticleProcessMaterial = null
var _original_amount: int = 0

var _arc_root: Node2D = null
var _arc_emit_timer: float = 0.0

func _ready() -> void:
	_original_mat = process_material as ParticleProcessMaterial
	_original_amount = amount
	_apply_state()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _state == State.HARVESTING:
		if _health_component and is_instance_valid(_health_component):
			_hp_ratio = _health_component.get_hp_ratio()
		_arc_emit_timer -= delta
		if _arc_emit_timer <= 0.0:
			_arc_emit_timer = lerp(0.12, 0.35, _hp_ratio)
			_spawn_arc_particle()

func set_harvesting(target: Node2D, scrap_color: Color = Colors.PRIMARY, health_comp: Node = null) -> void:
	_state = State.HARVESTING
	_harvest_target = target
	_harvest_color = scrap_color
	_health_component = health_comp
	_hp_ratio = 1.0
	_arc_emit_timer = 0.0
	if not _arc_root:
		_arc_root = Node2D.new()
		_arc_root.name = "ArcParticles"
		add_child(_arc_root)
	_apply_state()

func set_idle() -> void:
	_state = State.IDLE
	_harvest_target = null
	_health_component = null
	if _arc_root:
		var root = _arc_root
		_arc_root = null
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(root):
				root.queue_free()
		)
	_apply_state()

func pop(tier_item_id: String = "", intensity: float = 1.0) -> void:
	var burst := GPUParticles2D.new()
	burst.amount = maxi(int(30 * intensity), 8)
	burst.lifetime = 0.6
	burst.one_shot = true
	burst.emitting = false
	burst.position = Vector2.ZERO

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 360.0
	mat.initial_velocity_min = 20.0 * intensity
	mat.initial_velocity_max = 60.0 * intensity
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.0
	mat.scale_max = 3.0
	mat.color = tier_color(tier_item_id)
	mat.damping_min = 20.0
	mat.damping_max = 40.0

	burst.process_material = mat
	add_child(burst)
	burst.emitting = true

	get_tree().create_timer(burst.lifetime + 0.5).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)

static func tier_color(tier_item_id: String) -> Color:
	match tier_item_id:
		"slag":      return Colors.TIER_SLAG
		"scrap":     return Colors.TIER_SCRAP
		"salvage":   return Colors.TIER_SALVAGE
		"component": return Colors.TIER_COMPONENT
		"mil_spec":  return Colors.TIER_MIL_SPEC
		"artifact":  return Colors.TIER_ARTIFACT
	return Colors.PRIMARY

func _spawn_arc_particle() -> void:
	if not _arc_root or not _harvest_target or not is_instance_valid(_harvest_target):
		return

	var ship = _harvest_target
	var p0 = Vector2.ZERO

	var to_ship_local = to_local(ship.global_position)
	var perp = Vector2(-to_ship_local.y, to_ship_local.x).normalized()
	var arc_strength = randf_range(35.0, 90.0) * (1.0 if randf() > 0.5 else -1.0)
	var p1 = to_ship_local * randf_range(0.15, 0.4) + perp * arc_strength

	var size = randf_range(2.0, 4.5)
	var fragment = Polygon2D.new()
	fragment.polygon = PackedVector2Array([
		Vector2(0, -size), Vector2(size * 0.6, 0),
		Vector2(0, size), Vector2(-size * 0.6, 0)
	])
	fragment.color = _harvest_color
	fragment.position = p0
	_arc_root.add_child(fragment)

	var duration = randf_range(0.5, 1.0)
	var tween = create_tween()
	var update_fn = func(t: float):
		if not is_instance_valid(fragment):
			return
		var p2 = to_local(ship.global_position) if is_instance_valid(ship) else p1
		var pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
		fragment.position = pos
		var s = lerp(1.0, 0.1, t * t)
		fragment.scale = Vector2(s, s)
		fragment.modulate.a = 1.0 - (t * t * t)
	tween.tween_method(update_fn, 0.0, 1.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(fragment):
			fragment.queue_free()
	)

func _apply_state() -> void:
	if _original_mat == null:
		return

	match _state:
		State.IDLE:
			emitting = true
			if is_trophy:
				var mat = _original_mat.duplicate() as ParticleProcessMaterial
				mat.color = TROPHY_COLOR
				mat.scale_max = 15
				mat.scale_min = 10
				process_material = mat
			else:
				process_material = _original_mat
				amount = _original_amount

		State.HARVESTING:
			emitting = false
