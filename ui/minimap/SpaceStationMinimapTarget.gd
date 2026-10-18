extends MinimapTarget
class_name SpaceStationMinimapTarget

## MinimapTarget for a SpaceStation: charted, and drawn as its own outline - its major hull
## pieces, simplified and merged into one silhouette, traced at the station's live position
## and turn - so home can always be picked out. Too small on the scope to read as a shape,
## it falls back to a diamond.

## Roughly a station's reach, world px.
const ECHO_RADIUS := 450.0
## Subtrees that sit on the hull rather than being it: damage marks and lights.
const NOT_HULL := [&"HullDamage", &"Lights"]
## Pieces smaller than this, px², are left off: crates, radiators, struts and masts are
## detail at scope scale, and only the modules make the silhouette.
const MIN_PIECE_AREA := 5000.0
## Each piece is grown this much, world px, before they are merged, so modules that nearly
## touch close up into one contour instead of tracing every seam between them.
const MERGE_GROW := 12.0

var station: SpaceStation
## Its hull pieces: every Polygon2D not inside another (those are surface detail). Found
## once; a Section that is not seated is a hidden piece, so visibility is checked per frame.
var _hull: Array[Polygon2D] = []
var _hull_found := false
## The merged silhouette in station space, and which pieces were showing when it was made.
var _outline: Array[PackedVector2Array] = []
var _outline_key := ""

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

## The station's silhouette, world space: closed contours for the chart to trace. Merged
## again only when a piece shows or hides (a Section seated or lost).
func chart_outline() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if station == null or not is_instance_valid(station):
		return out
	if not _hull_found:
		_hull_found = true
		_collect_hull(station)
	var shown: Array[Polygon2D] = []
	var key := ""
	for poly in _hull:
		var on := is_instance_valid(poly) and poly.is_visible_in_tree()
		key += "1" if on else "0"
		if on:
			shown.append(poly)
	if key != _outline_key:
		_outline_key = key
		_outline = _merge(shown)
	var xf := station.global_transform
	for contour in _outline:
		out.append(xf * contour)
	return out

## The shown pieces as one silhouette in station space: each piece's convex shape, grown
## a little, unioned with every other it overlaps.
func _merge(pieces: Array[Polygon2D]) -> Array[PackedVector2Array]:
	var to_station := station.global_transform.affine_inverse()
	var shapes: Array[PackedVector2Array] = []
	for poly in pieces:
		var local := PackedVector2Array()
		for p in _shape(poly):
			local.append(to_station * poly.global_transform * (p + poly.offset))
		var grown := Geometry2D.offset_polygon(local, MERGE_GROW, Geometry2D.JOIN_MITER)
		var cur: PackedVector2Array = grown[0] if not grown.is_empty() else local
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
	return shapes

## The one contour two pieces merge into when they overlap, or empty when they don't (two
## outer contours come back). Holes - wound the other way - are dropped: an outline only
## needs the edge.
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

func _collect_hull(node: Node) -> void:
	for child in node.get_children():
		if NOT_HULL.has(child.name):
			continue
		var poly := child as Polygon2D
		if poly == null:
			_collect_hull(child)
		elif absf(_area(poly.polygon)) < MIN_PIECE_AREA:
			continue
		# A clip mask (the dorsal claw's Well) is a window to draw through, not plating
		elif poly.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
			continue
		# Only shapes that will fill: a degenerate one would fail to draw
		elif poly.polygon.size() >= 3 and not Geometry2D.triangulate_polygon(poly.polygon).is_empty():
			_hull.append(poly)

## A piece's outline with its notches filled: the convex hull, closing point dropped.
func _shape(poly: Polygon2D) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(poly.polygon)
	if hull.size() > 1:
		hull.remove_at(hull.size() - 1)
	return hull

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a / 2.0
