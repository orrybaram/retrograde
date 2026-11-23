extends Control
class_name SeekBeacon

## Where to go after the manual diagnostic hands back the stick. From when PROPULSION
## clears until SONAR does (BootLog.seek_target), the loose Section the pilot should fly to
## blinks a running light. While that Section is off screen, a caret on the screen's edge
## points to it. Before this, nothing on screen said where to go in that stretch.

const BLINK_HZ := 1.6
## Fraction of each blink the light is on.
const BLINK_ON := 0.75
## Half the light's side, and the radius of the soft glow around it (screen px).
const LIGHT := 4.0
const HALO := 18.0
const HALO_ALPHA := 0.25
const CARET_SIZE := 14.0
const EDGE_MARGIN := 40.0

var boot_log: BootLog = null
## HUD panels the caret must not cover (the boot log in the corner).
var blockers: Array[Control] = []

var _target: Freight = null
var _screen_pos := Vector2.ZERO
var _origin := Vector2.ZERO
var _on_screen := false
var _clock := 0.0


func _ready() -> void:
	name = "SeekBeacon"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE


## The Section being pointed to, or null when there is none (for scenarios).
func target() -> Freight:
	return _target


## Whether the target is on screen, so it shows the light rather than the caret.
func on_screen() -> bool:
	return _on_screen


## Whether the light or caret is lit at this point in the blink.
func lit() -> bool:
	return fmod(_clock * BLINK_HZ, 1.0) < BLINK_ON


func _process(delta: float) -> void:
	_clock += delta
	_target = boot_log.seek_target() if boot_log else null
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if _target and ship:
		var to_local := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_canvas_transform()
		var rect := _edge_rect()
		_screen_pos = to_local * _target.global_position
		_origin = (to_local * ship.global_position).clamp(rect.position, rect.end)
		_on_screen = Rect2(Vector2.ZERO, size).has_point(_screen_pos)
	else:
		_target = null
	queue_redraw()


func _draw() -> void:
	if _target == null or not lit():
		return
	if _on_screen:
		draw_circle(_screen_pos, HALO, Color(Colors.PRIMARY, HALO_ALPHA))
		draw_rect(Rect2(_screen_pos - Vector2.ONE * LIGHT, Vector2.ONE * LIGHT * 2.0), Colors.PRIMARY)
		return
	var d := _screen_pos - _origin
	var dir := d.normalized() if not d.is_zero_approx() else Vector2.RIGHT
	var base := TrackingIndicator.push_out_of(
		TrackingIndicator.edge_point(_edge_rect(), _origin, dir), _blocked_rects())
	var perp := dir.orthogonal()
	var tip := base + dir * CARET_SIZE
	var caret := PackedVector2Array([
		tip,
		base - dir * CARET_SIZE * 0.7 + perp * CARET_SIZE * 0.8,
		base - dir * CARET_SIZE * 0.2,
		base - dir * CARET_SIZE * 0.7 - perp * CARET_SIZE * 0.8,
	])
	draw_colored_polygon(caret, Colors.PRIMARY)
	caret.append(tip)
	draw_polyline(caret, Colors.SPACE_BG, 1.5)


func _edge_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN)


func _blocked_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var to_local := get_global_transform_with_canvas().affine_inverse()
	for b in blockers:
		if is_instance_valid(b) and b.is_visible_in_tree():
			var r := b.get_global_rect()
			rects.append(Rect2(to_local * r.position, r.size).grow(CARET_SIZE))
	return rects
