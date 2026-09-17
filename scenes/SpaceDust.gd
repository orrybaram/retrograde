extends Node2D
class_name SpaceDust

## Foreground dust motes that streak past the camera to sell the ship's speed.
## Motes live in screen space and scroll opposite the ship's velocity faster than the
## world does (depth > 1 = in front of the playfield). They are invisible when the ship
## is slow, fade in as drifting specks at cruising speed, and only stretch into streaks
## when the ship is going really fast (boosting).

@export var mote_count: int = 70
@export var depth_range: Vector2 = Vector2(1.15, 1.8)  # parallax factor vs. the world
@export var fade_speed: Vector2 = Vector2(30.0, 200.0)  # speed where motes start / finish fading in
@export var max_alpha: float = 0.35
@export var streak_speed: Vector2 = Vector2(450.0, 900.0)  # speed where streaks start / reach max_streak
@export var max_streak: float = 40.0
@export var margin: float = 40.0  # px beyond the screen edge before a mote wraps

var _ship: RigidBody2D = null
var _motes: Array[Dictionary] = []  # {pos (screen px), depth, alpha, width}
var _visibility := 0.0
var _stretch := 0.0  # 0 = specks, 1 = full-length streaks


func _ready() -> void:
	top_level = true
	z_index = 10  # above ship and world; still under CanvasLayer UI
	var size := get_viewport_rect().size
	for i in mote_count:
		var depth := randf_range(depth_range.x, depth_range.y)
		var near := inverse_lerp(depth_range.x, depth_range.y, depth)
		_motes.append({
			"pos": Vector2(randf_range(-margin, size.x + margin), randf_range(-margin, size.y + margin)),
			"depth": depth,
			"alpha": randf_range(0.4, 1.0),
			"width": lerpf(1.0, 2.0, near),
		})


## 0 at rest, 1 at full speed.
static func visibility_for(speed: float, fade: Vector2) -> float:
	return smoothstep(fade.x, fade.y, speed)


func _process(delta: float) -> void:
	if not is_instance_valid(_ship):
		var ships := get_tree().get_nodes_in_group("ship")
		_ship = ships[0] as RigidBody2D if ships.size() > 0 else null
		if not _ship:
			return

	var velocity := _screen_velocity()
	# Docked ships ride their station's orbit; only show dust under the player's own power.
	var speed := _ship.linear_velocity.length() if _in_flight() else 0.0
	_visibility = move_toward(_visibility, visibility_for(speed, fade_speed), delta * 2.0)
	_stretch = visibility_for(speed, streak_speed)

	var size := get_viewport_rect().size
	var span := size + Vector2.ONE * margin * 2.0
	for m in _motes:
		var p: Vector2 = m.pos - velocity * m.depth * delta
		m.pos = Vector2(
			fposmod(p.x + margin, span.x) - margin,
			fposmod(p.y + margin, span.y) - margin)
	queue_redraw()


## Ship velocity in screen px/s (accounts for camera zoom and rotation).
func _screen_velocity() -> Vector2:
	return get_viewport().get_canvas_transform().basis_xform(_ship.linear_velocity)


func _draw() -> void:
	if _visibility <= 0.001:
		return
	# Draw in screen coordinates regardless of where the camera is.
	draw_set_transform_matrix(get_viewport().get_canvas_transform().affine_inverse())
	var direction := _screen_velocity().normalized()
	for m in _motes:
		var c := Colors.STAR
		c.a = max_alpha * _visibility * m.alpha
		# Tail trails back along the mote's motion (i.e. toward where the ship is heading).
		# Nearer motes (higher depth) streak longer.
		var tail: Vector2 = direction * max_streak * _stretch * m.depth / depth_range.y
		if tail.length() < 1.0:
			draw_rect(Rect2(m.pos, Vector2.ONE * m.width), c)
		else:
			draw_line(m.pos, m.pos + tail, c, m.width)


func _in_flight() -> bool:
	var sm: StateMachine = _ship.get("state_machine")
	return sm != null and (sm.current_state is FlyingState or sm.current_state is HarvestingState)
