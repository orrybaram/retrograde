extends Control
class_name ShipSchematic

## SHIP's drawing of the ship from above (docs/adr/0014): terminal line art, the hull in
## mustard, fitted Components in cream, and a blinking ghost of a Component about to be
## fitted. A place with nothing in it is never drawn. Components are drawn from the same
## outlines the hull wears (Components.fitted_outline), so the drawing cannot disagree
## with the ship.

## Ship units to one grid square.
const GRID := 5.0
const BLINK := 1.1
const LINE := 2.0

var ship: Ship = null
## The Components drawn as fitted.
var fitted := PackedStringArray()
## A Component shown as a ghost in its place, about to be fitted; "" for none.
var ghost := ""
## A fitted Component drawn dim, about to come off (stowed, or swapped out by `ghost`).
var leaving := ""

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 190)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_process(false)

func show_ship(on: Ship, ids: PackedStringArray, ghost_id := "", leaving_id := "") -> void:
	ship = on
	fitted = ids
	ghost = ghost_id
	leaving = leaving_id
	set_process(ghost != "")
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var hull := _hull()
	if hull.is_empty():
		return
	var shapes: Array[PackedVector2Array] = [hull]
	for id in fitted:
		shapes.append(Components.fitted_outline(id))
	if ghost != "":
		shapes.append(Components.fitted_outline(ghost))
	var box := Freight.bounds(hull)
	for s in shapes:
		if not s.is_empty():
			box = box.merge(Freight.bounds(s))
	box = box.grow(GRID)
	var scale := minf(size.x / box.size.x, size.y / box.size.y)
	var to_screen := Transform2D(0.0, Vector2(scale, scale), 0.0, size / 2.0 - box.get_center() * scale)

	_draw_grid(to_screen, box)
	_outline(to_screen * hull, Colors.PRIMARY)
	for id in fitted:
		_part(to_screen, id, Colors.PRIMARY_DIM if id == leaving else Colors.TEXT)
	if ghost != "" and fmod(Time.get_ticks_msec() / 1000.0, BLINK) < BLINK / 2.0:
		_part(to_screen, ghost, Colors.PRIMARY)

func _hull() -> PackedVector2Array:
	if not is_instance_valid(ship):
		return PackedVector2Array()
	var body := ship.get_node_or_null("Body/Polygon2D") as Polygon2D
	return body.transform * body.polygon if body else PackedVector2Array()

func _draw_grid(to_screen: Transform2D, box: Rect2) -> void:
	var x := floorf(box.position.x / GRID) * GRID
	while x <= box.end.x:
		draw_line(to_screen * Vector2(x, box.position.y), to_screen * Vector2(x, box.end.y), Colors.NEBULA)
		x += GRID
	var y := floorf(box.position.y / GRID) * GRID
	while y <= box.end.y:
		draw_line(to_screen * Vector2(box.position.x, y), to_screen * Vector2(box.end.x, y), Colors.NEBULA)
		y += GRID

func _part(to_screen: Transform2D, id: String, color: Color) -> void:
	var outline := Components.fitted_outline(id)
	if outline.is_empty():
		return
	_outline(to_screen * outline, color)
	for band in Components.fitted_bands(id):
		var r := band as Rect2
		var mid := r.position.y + r.size.y / 2.0
		draw_line(to_screen * Vector2(r.position.x, mid), to_screen * Vector2(r.end.x, mid), color, 1.0)

func _outline(points: PackedVector2Array, color: Color) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, LINE)
