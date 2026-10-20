extends Control
class_name ReadoutLock

## What ties a read to the thing it read (docs/SWEEP.md §10). When the ship reads something
## up close, a dotted tether draws straight out of its entry's heading in the ContactLog to
## the thing, and lock brackets close around it where the tether lands. Both hold until the
## entry fades. Something of the Titan's locks in its purple.
##
## It draws in the HUD's canvas from the thing's world bounds (Readout.world_bounds), so it
## follows the thing as the camera moves. A lock lives as long as its entry, or while its
## owner holds it (`hold`): found scrap the ship is in range to cut keeps its brackets, so the
## player sees which piece a harvest press will cut.

## Seconds the tether takes to reach the thing, and the brackets to close after it lands.
const DRAW_OUT := 0.25
const CLOSE_TIME := 0.18
## How much larger the brackets start before they close, as a share of the thing's size.
const SNAP_GROW := 0.6
## Brackets' gap from the thing and the length of their arms, in screen px; smaller for small
## things (a piece of scrap) so the lock does not swallow the debris around it.
const PAD := 7.0
const ARM := 7.0
const SMALL_PAD := 4.0
const SMALL_ARM := 4.0
const SMALL_SIZE := 40.0
const WIDTH := 1.5
const DASH := 3.0
## Where the tether leaves the heading: this far left of it, with a port drawn there.
const PORT_GAP := 6.0
const PORT_SIZE := 4.0

var contact_log: ContactLog = null
## By the readout's instance id: {readout, age}.
var _locks := {}
## Instance ids of the readouts held locked whatever their entry.
var _held := {}


func _ready() -> void:
	add_to_group("readout_lock")
	# Main.clear_screen_effects: a new game, a load or a quit to the menu clears it
	add_to_group("screen_effects")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.readout_read.connect(show_read)


## Lock onto what `readout` is part of. A read of something already locked draws again.
func show_read(readout: Node, _rows: Array) -> void:
	var r := readout as Readout
	if r == null:
		return
	_locks[r.get_instance_id()] = {"readout": r, "age": 0.0}
	queue_redraw()


## Keep `readout` locked while `on`, entry or not. A lock with no entry has no tether to draw,
## so its brackets close at once.
func hold(readout: Node, on: bool) -> void:
	var r := readout as Readout
	if r == null:
		return
	var id := r.get_instance_id()
	if not on:
		_held.erase(id)
		return
	_held[id] = true
	if not _locks.has(id):
		_locks[id] = {"readout": r, "age": DRAW_OUT}
	queue_redraw()


## Whether `readout` is locked onto right now.
func is_locked(readout: Node) -> bool:
	return _locks.has(readout.get_instance_id())


func clear_now() -> void:
	_locks.clear()
	_held.clear()
	queue_redraw()


func _process(dt: float) -> void:
	if _locks.is_empty():
		return
	for id in _locks.keys():
		var lock: Dictionary = _locks[id]
		var r := instance_from_id(id) as Readout
		if r == null or not is_instance_valid(r):
			_locks.erase(id)
			_held.erase(id)
			continue
		if _entry(r).is_empty() and not _held.has(id):
			_locks.erase(id)
			continue
		lock.age += dt
	queue_redraw()


func _entry(r: Readout) -> Dictionary:
	return contact_log.entry_state(r) if contact_log else {}


## How far the tether is out (0-1) and how closed the brackets are (0-1), `age` seconds into
## a lock.
static func timing(age: float) -> Vector2:
	var out := minf(1.0, age / DRAW_OUT)
	var close := clampf((age - DRAW_OUT) / CLOSE_TIME, 0.0, 1.0)
	return Vector2(out, close)


## The brackets' box around `rect` (screen space) as they close: 0 wide open, 1 shut.
static func bracket_box(rect: Rect2, close: float) -> Rect2:
	var pad := SMALL_PAD if rect.size.length() < SMALL_SIZE else PAD
	var grow := rect.size * SNAP_GROW * (1.0 - close) * 0.5
	return rect.grow_individual(grow.x + pad, grow.y + pad, grow.x + pad, grow.y + pad)


## The tether from the heading at `anchor`, straight to the corner of `box` nearest it.
static func tether_path(anchor: Vector2, box: Rect2) -> PackedVector2Array:
	var start := anchor - Vector2(PORT_GAP, 0.0)
	var end := box.position
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		if start.distance_to(corner) < start.distance_to(end):
			end = corner
	return PackedVector2Array([start, end])


func _draw() -> void:
	var world_to_me := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_canvas_transform()
	var canvas_to_me := get_global_transform().affine_inverse()
	for id in _locks:
		var lock: Dictionary = _locks[id]
		var r: Readout = lock.readout
		if not is_instance_valid(r):
			continue
		var entry := _entry(r)
		var t := timing(lock.age)
		var rect := _screen_rect(world_to_me, r.world_bounds())
		var color: Color = Colors.TITAN if r.undecipherable else Colors.PRIMARY
		var alpha: float = 1.0 if _held.has(id) else entry.get("alpha", 0.0)
		if not entry.is_empty() and t.x > 0.0:
			_draw_tether(tether_path(canvas_to_me * entry.point, bracket_box(rect, 1.0)), t.x, Color(color, alpha * 0.8))
		if t.y > 0.0:
			_draw_brackets(bracket_box(rect, t.y), rect.size.length() < SMALL_SIZE, Color(color, alpha * (0.45 + 0.55 * t.y)))


static func _screen_rect(xform: Transform2D, world: Rect2) -> Rect2:
	var out := Rect2(xform * world.position, Vector2.ZERO)
	for corner in [Vector2(world.end.x, world.position.y), world.end, Vector2(world.position.x, world.end.y)]:
		out = out.expand(xform * corner)
	return out


func _draw_brackets(box: Rect2, small: bool, color: Color) -> void:
	var arm := SMALL_ARM if small else ARM
	var a := box.position
	var b := box.end
	for corner: Array in [[a, Vector2(1, 1)], [Vector2(b.x, a.y), Vector2(-1, 1)], [b, Vector2(-1, -1)], [Vector2(a.x, b.y), Vector2(1, -1)]]:
		var at: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		draw_polyline(PackedVector2Array([at + Vector2(0, dir.y * arm), at, at + Vector2(dir.x * arm, 0)]), color, WIDTH)


## The first `frac` of `path`, dashed, with a port at its start and a tip where it has got to.
func _draw_tether(path: PackedVector2Array, frac: float, color: Color) -> void:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	var left := total * frac
	var tip := path[0]
	for i in range(1, path.size()):
		if left <= 0.0:
			break
		var seg := path[i - 1].distance_to(path[i])
		var to := path[i] if left >= seg else path[i - 1].lerp(path[i], left / seg)
		draw_dashed_line(path[i - 1], to, color, 1.0, DASH)
		tip = to
		left -= seg
	var port := Vector2(PORT_SIZE, PORT_SIZE)
	draw_rect(Rect2(path[0] - port * 0.5, port), color)
	draw_rect(Rect2(tip - port * 0.375, port * 0.75), color)
