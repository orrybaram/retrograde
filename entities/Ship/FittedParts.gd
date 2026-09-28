extends RefCounted
class_name FittedParts

## The Components fitted to the ship, on the hull (docs/adr/0014): each one drawn over the
## Body and solid, a collider of its own on the ship. Ship.refit rebuilds them from what is
## fitted; its mass and turn come from Ship._apply_mass.
##
## The art is Polygon2Ds under the Body, so a hull abandoned with parts on keeps drawing
## them (DerelictShip copies every Polygon2D it is given): dead metal, not Freight.

const ART := "Fitted"
const COLLIDER_PREFIX := "Fitted_"

## Make `ship` wear exactly the Components `ids`, and nothing it wore before.
static func build(ship: Ship, ids: PackedStringArray) -> void:
	clear(ship)
	var body := ship.get_node_or_null("Body") as Node2D
	if body == null:
		return
	var art := Node2D.new()
	art.name = ART
	body.add_child(art)
	for id in ids:
		var outline := Components.fitted_outline(id)
		if outline.is_empty():
			continue
		art.add_child(_part_art(id, outline))
		var hit := CollisionPolygon2D.new()
		hit.name = COLLIDER_PREFIX + id
		hit.polygon = outline
		ship.add_child(hit)

## Take every fitted part off `ship`: a new game's bare hull. Freed at once, not queued:
## fitting runs from the dock menu and loads, never inside a physics step, and a rebuild
## straight after must not find the old parts still there.
static func clear(ship: Ship) -> void:
	var body := ship.get_node_or_null("Body")
	var art := body.get_node_or_null(ART) if body else null
	if art:
		body.remove_child(art)
		art.free()
	for child in ship.get_children():
		if child is CollisionPolygon2D and String(child.name).begins_with(COLLIDER_PREFIX):
			ship.remove_child(child)
			child.free()

## Whether `ship` wears Component `id` on its hull right now.
static func wears(ship: Ship, id: String) -> bool:
	return ship.get_node_or_null(NodePath(COLLIDER_PREFIX + id)) != null

static func _part_art(id: String, outline: PackedVector2Array) -> Node2D:
	var part := Node2D.new()
	part.name = id
	var edge := Polygon2D.new()
	edge.polygon = outline
	edge.color = Colors.HULL_LIGHT
	part.add_child(edge)
	var fill := Polygon2D.new()
	fill.polygon = _inset(outline, 1.0)
	fill.color = Colors.HULL_MID
	part.add_child(fill)
	for band in Components.fitted_bands(id):
		var r := band as Rect2
		var strap := Polygon2D.new()
		strap.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		strap.color = Colors.HULL_LIGHT
		part.add_child(strap)
	return part

## `outline` shrunk by `by` on every side, so the part below shows as a rim.
static func _inset(outline: PackedVector2Array, by: float) -> PackedVector2Array:
	var shrunk := Geometry2D.offset_polygon(outline, -by)
	return shrunk[0] if not shrunk.is_empty() else outline
