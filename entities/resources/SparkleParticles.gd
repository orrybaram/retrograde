@tool
extends GPUParticles2D
class_name SparkleParticles

## GPU particle effect for the harvesting beam. Switches between IDLE (ambient sparkle)
## and HARVESTING (directed arc toward ship) states. Trophy nodes emit yellow arcs.

const TROPHY_COLOR = Colors.YELLOW
## How long the arc root sticks around after a harvest ends, so the fragments still in
## flight finish their arc before it is reaped.
const ARC_ROOT_LINGER := 1.2

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
		# The arc root lingers long enough for the fragments still in flight. The wait is
		# the root's own tween, so freeing the root kills the wait with it - a scene-tree
		# timer would fire later still holding a freed node.
		var root := _arc_root
		_arc_root = null
		var reap := root.create_tween()
		reap.tween_interval(ARC_ROOT_LINGER)
		reap.tween_callback(root.queue_free)
	_apply_state()

func pop(burst_color: Color = Colors.PRIMARY, intensity: float = 1.0) -> void:
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
	mat.color = burst_color
	mat.damping_min = 20.0
	mat.damping_max = 40.0

	burst.process_material = mat
	add_child(burst)
	burst.emitting = true

	# Same rule as the arc fragments: the burst cleans itself up, so it can never be
	# freed out from under a pending timer.
	var reap := burst.create_tween()
	reap.tween_interval(burst.lifetime + 0.5)
	reap.tween_callback(burst.queue_free)

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

	# The fragment owns its own tween, so freeing the fragment - or the whole arc root
	# when the harvest ends, or the scene at teardown - kills the animation with it.
	# A tween made here would outlive the fragment and keep calling back holding it.
	var duration = randf_range(0.5, 1.0)
	var tween = fragment.create_tween()
	# _harvest_target is read off the node each frame rather than captured: the ship can
	# be freed (or the harvest end) mid-arc, and a captured node would be a freed capture.
	var update_fn = func(t: float):
		var target := _harvest_target
		var p2 = to_local(target.global_position) if is_instance_valid(target) else p1
		var pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
		fragment.position = pos
		var s = lerp(1.0, 0.1, t * t)
		fragment.scale = Vector2(s, s)
		fragment.modulate.a = 1.0 - (t * t * t)
	tween.tween_method(update_fn, 0.0, 1.0, duration)
	tween.tween_callback(fragment.queue_free)

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
