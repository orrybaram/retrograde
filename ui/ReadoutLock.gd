extends Control
class_name ReadoutLock

## Lock brackets around something the ship is working on: found scrap the ship is in range to
## cut holds its lock (`hold`, ScrapNode), so the player sees which piece a harvest press will
## cut. The brackets start wide and close around the thing, and stay while it is held.
## Something of the Titan's locks in its purple. Reading something up close shows nothing on
## screen: there is no readout panel any more (the ship's log, ShipLog, says what matters).
##
## It draws in the HUD's canvas from the thing's world bounds (Readout.world_bounds), so it
## follows the thing as the camera moves.

## Seconds the brackets take to close.
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

## By the readout's instance id: {readout, age}.
var _locks := {}


func _ready() -> void:
	add_to_group("readout_lock")
	# Main.clear_screen_effects: a new game, a load or a quit to the menu clears it
	add_to_group("screen_effects")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Keep `readout` locked while `on`.
func hold(readout: Node, on: bool) -> void:
	var r := readout as Readout
	if r == null:
		return
	var id := r.get_instance_id()
	if not on:
		_locks.erase(id)
		queue_redraw()
		return
	if not _locks.has(id):
		_locks[id] = {"readout": r, "age": 0.0}
	queue_redraw()


## Whether `readout` is locked onto right now.
func is_locked(readout: Node) -> bool:
	return _locks.has(readout.get_instance_id())


func clear_now() -> void:
	_locks.clear()
	queue_redraw()


func _process(dt: float) -> void:
	if _locks.is_empty():
		return
	for id in _locks.keys():
		var r := instance_from_id(id) as Readout
		if r == null or not is_instance_valid(r):
			_locks.erase(id)
			continue
		_locks[id].age += dt
	queue_redraw()


## How closed the brackets are (0-1), `age` seconds into a lock.
static func closing(age: float) -> float:
	return clampf(age / CLOSE_TIME, 0.0, 1.0)


## The brackets' box around `rect` (screen space) as they close: 0 wide open, 1 shut.
static func bracket_box(rect: Rect2, close: float) -> Rect2:
	var pad := SMALL_PAD if rect.size.length() < SMALL_SIZE else PAD
	var grow := rect.size * SNAP_GROW * (1.0 - close) * 0.5
	return rect.grow_individual(grow.x + pad, grow.y + pad, grow.x + pad, grow.y + pad)


func _draw() -> void:
	var world_to_me := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_canvas_transform()
	for id in _locks:
		var lock: Dictionary = _locks[id]
		var r: Readout = lock.readout
		if not is_instance_valid(r):
			continue
		var close := closing(lock.age)
		var rect := _screen_rect(world_to_me, r.world_bounds())
		var color: Color = Colors.TITAN if r.undecipherable else Colors.PRIMARY
		_draw_brackets(bracket_box(rect, close), rect.size.length() < SMALL_SIZE, Color(color, 0.45 + 0.55 * close))


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
