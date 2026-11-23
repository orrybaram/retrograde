extends MinimapTarget
class_name SpaceStationMinimapTarget

## MinimapTarget for a SpaceStation: charted, and drawn as its own outline - a schematic,
## not a tracing. Each major hull piece stands in as its bounding box at its seated place,
## and the boxes are closed up into one blocky silhouette. It is made once and never
## follows the station's state: a wing hanging off true, or pushed home, is the same
## station on the scope. Too small on the scope to read as a shape, it falls back to a
## diamond.

## Roughly a station's reach, world px.
const ECHO_RADIUS := 450.0
## Subtrees that sit on the hull rather than being it: damage marks and lights.
const NOT_HULL := [&"HullDamage", &"Lights"]
## Pieces smaller than this, px², are left off: crates, radiators, struts and masts are
## detail at scope scale, and only the modules make the silhouette.
const MIN_PIECE_AREA := 5000.0
## Gaps between modules narrower than twice this, world px, are closed: every box is grown
## this much, merged, then shrunk back, so the station reads as one shape.
const CLOSE_GAP := 40.0

var station: SpaceStation
## The silhouette in station space, made the first time it is asked for.
var _outline: Array[PackedVector2Array] = []

func _init(s: SpaceStation) -> void:
	station = s

func get_minimap_position() -> Vector2:
	if station and is_instance_valid(station):
		return station.global_position
	return Vector2.ZERO

func echo_world_radius() -> float:
	return ECHO_RADIUS

func echo_is_diamond() -> bool:
	return true

func is_minimap_visible() -> bool:
	return station != null and is_instance_valid(station)

func get_minimap_node() -> Node2D:
	return station

func is_charted() -> bool:
	return true

## The station's silhouette, world space: closed contours for the chart to trace.
func chart_outline() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if station == null or not is_instance_valid(station):
		return out
	if _outline.is_empty():
		var hull: Array[Polygon2D] = []
		_collect_hull(station, hull)
		_outline = _silhouette(hull)
	var xf := station.global_transform
	for contour in _outline:
		out.append(xf * contour)
	return out

## Every piece's bounding box at its seated place, station space, closed up into as few
## contours as will go: grown, unioned with every box it overlaps, shrunk back.
func _silhouette(pieces: Array[Polygon2D]) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	for poly in pieces:
		var xf := _seated_transform(poly)
		var box := Rect2()
		for k in poly.polygon.size():
			var p := xf * (poly.polygon[k] + poly.offset)
			box = Rect2(p, Vector2.ZERO) if k == 0 else box.expand(p)
		box = box.grow(CLOSE_GAP)
		var cur := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y),
			box.end, Vector2(box.position.x, box.end.y)])
		var i := 0
		while i < shapes.size():
			var outer := _single_outer(Geometry2D.merge_polygons(cur, shapes[i]))
			if outer.is_empty():
				i += 1
				continue
			cur = outer
			shapes.remove_at(i)
			i = 0
		shapes.append(cur)
	var out: Array[PackedVector2Array] = []
	for shape in shapes:
		var wound := Geometry2D.is_polygon_clockwise(shape)
		for contour in Geometry2D.offset_polygon(shape, -CLOSE_GAP, Geometry2D.JOIN_MITER):
			# A hole is wound the other way: an outline only needs the edge
			if Geometry2D.is_polygon_clockwise(contour) == wound:
				out.append(contour)
	return out

## `node`'s transform in station space as it sits when the station is whole: a wing
## hanging off true (ArrayNudge) counts as home.
func _seated_transform(node: Node) -> Transform2D:
	var xf := Transform2D.IDENTITY
	var n := node
	while n != null and n != station:
		if n is ArrayNudge:
			xf = (n as ArrayNudge).home_transform() * xf
		elif n is Node2D:
			xf = (n as Node2D).transform * xf
		n = n.get_parent()
	return xf

## The one contour two pieces merge into when they overlap, or empty when they don't (two
## outer contours come back). Holes - wound the other way - are dropped.
static func _single_outer(merged: Array[PackedVector2Array]) -> PackedVector2Array:
	if merged.is_empty():
		return PackedVector2Array()
	var biggest := merged[0]
	for poly in merged:
		if absf(_area(poly)) > absf(_area(biggest)):
			biggest = poly
	var outers := merged.filter(func(poly: PackedVector2Array) -> bool:
		return Geometry2D.is_polygon_clockwise(poly) == Geometry2D.is_polygon_clockwise(biggest))
	return biggest if outers.size() == 1 else PackedVector2Array()

## Its hull pieces: every Polygon2D big enough to be a module and not inside another
## (those are surface detail).
func _collect_hull(node: Node, hull: Array[Polygon2D]) -> void:
	for child in node.get_children():
		if NOT_HULL.has(child.name):
			continue
		var poly := child as Polygon2D
		if poly == null:
			_collect_hull(child, hull)
		elif absf(_area(poly.polygon)) < MIN_PIECE_AREA:
			continue
		# A clip mask (the dorsal claw's Well) is a window to draw through, not plating
		elif poly.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
			continue
		# Only shapes that will fill: a degenerate one would fail to draw
		elif poly.polygon.size() >= 3 and not Geometry2D.triangulate_polygon(poly.polygon).is_empty():
			hull.append(poly)

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a / 2.0
