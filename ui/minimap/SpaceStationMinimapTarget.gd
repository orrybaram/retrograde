extends MinimapTarget
class_name SpaceStationMinimapTarget

## MinimapTarget for a SpaceStation: charted, and drawn as its own outline - a schematic,
## not a tracing. SR-7 is a stack of boxes on one spine (SCHEMATIC): deck, module block,
## hub, core, keel, and the solar wings across it. Each box is the bounds of its parts at
## their seated place. A station without those parts (the Sun Station) gets every major
## hull piece as a box, closed up into one blocky silhouette. Either way it is made once and
## never follows the station's state: a wing hanging off true, or pushed home, is the same
## station on the scope. Too small on the scope to read as a shape, it falls back to a
## diamond. What is broken on it - an empty Mount, a wing hanging off true - is marked on
## the outline in red (broken_points).

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
## SR-7 on the scope, top to bottom: each entry is one box, the bounds of those parts
## (paths from the station). The dorsal arm is left off: it is the Cradle, not the hull.
const SCHEMATIC := [
	["Visuals/Deck"],
	["Visuals/ModuleL", "Visuals/ModuleC", "Visuals/ModuleR", "Visuals/BlockPlate"],
	["Visuals/CentralHub"],
	["Visuals/CentralCore"],
	["Visuals/KeelLower"],
	["Visuals/SolarArray", "ArrayNudge/Visual"],
]
## The spine that joins the schematic's boxes: as wide as the keel, from the top box to the
## bottom one.
const SCHEMATIC_SPINE := "Visuals/KeelLower"

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
		_outline = _schematic()
	if _outline.is_empty():
		var hull: Array[Polygon2D] = []
		_collect_hull(station, hull)
		_outline = _silhouette(hull)
	var xf := station.global_transform
	for contour in _outline:
		out.append(xf * contour)
	return out

## Where the station is broken, world space: each empty Mount, and the middle of a wing
## hanging off true at its seated place. Empty once SR-7 is whole, and always for a station
## with neither (the Sun Station).
func broken_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	if station == null or not is_instance_valid(station):
		return out
	var tree := station.get_tree()
	for m in tree.get_nodes_in_group("mounts"):
		if not m.seated and station.is_ancestor_of(m):
			out.append((m as Node2D).global_position)
	for n in tree.get_nodes_in_group("nudges"):
		if n.seated or not station.is_ancestor_of(n):
			continue
		var visual := n.get_node_or_null("Visual") as Polygon2D
		var at := _seated_box(visual).get_center() if visual else _seated_transform(n).origin
		out.append(station.global_transform * at)
	return out

## SR-7's schematic (SCHEMATIC), station space: its boxes and the spine through them, as
## one contour. Empty if the station is missing any of the parts.
func _schematic() -> Array[PackedVector2Array]:
	var boxes: Array[Rect2] = []
	for parts in SCHEMATIC:
		var group := Rect2()
		for k in parts.size():
			var poly := station.get_node_or_null(parts[k]) as Polygon2D
			if poly == null:
				return []
			var box := _seated_box(poly)
			group = box if k == 0 else group.merge(box)
		boxes.append(group)
	var spine := _seated_box(station.get_node(SCHEMATIC_SPINE) as Polygon2D)
	var top := boxes[0].position.y
	var bottom := top
	for box in boxes:
		top = minf(top, box.position.y)
		bottom = maxf(bottom, box.end.y)
	var shape := _rect_points(Rect2(spine.position.x, top, spine.size.x, bottom - top))
	for box in boxes:
		var merged := _single_outer(Geometry2D.merge_polygons(shape, _rect_points(box)))
		if merged.is_empty():
			return []
		shape = merged
	var out: Array[PackedVector2Array] = [shape]
	return out

## Every piece's bounding box at its seated place, station space, closed up into as few
## contours as will go: grown, unioned with every box it overlaps, shrunk back.
func _silhouette(pieces: Array[Polygon2D]) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	for poly in pieces:
		var cur := _rect_points(_seated_box(poly).grow(CLOSE_GAP))
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

## `poly`'s bounding box in station space, at its seated place.
func _seated_box(poly: Polygon2D) -> Rect2:
	var xf := _seated_transform(poly)
	var box := Rect2()
	for k in poly.polygon.size():
		var p := xf * (poly.polygon[k] + poly.offset)
		box = Rect2(p, Vector2.ZERO) if k == 0 else box.expand(p)
	return box

static func _rect_points(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

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
