extends Node2D
class_name Mount

## The torn place on SR-7 where one Section belongs (docs/adr/0012, docs/OPENING.md §2).
## Until the Section is seated, the station's `part` polygon is hidden, the parts of it
## that showed are cut out of the station's collision, and their torn edges are drawn
## as sheared brackets and broken strut stubs - never a ghost outline or a socket.
##
## The Section goes home into any of the part's gaps - wherever the tear shows - pushed in
## from either side: a strut has no front. Released within SEAT_RANGE px and SEAT_ANGLE
## of a seat, it is pulled home over SEAT_TIME with a clunk, the Freight is gone, and
## `part` is the station again. The Mount's own transform is its main seat (and what the
## tracker points at). Only the Section with
## the Mount's id fits. The seated state lives in GameState.seated_sections.

## Close enough to seat: the docking tolerance.
const SEAT_RANGE := 40.0
const SEAT_ANGLE := deg_to_rad(30.0)
## How long the Mount takes to pull a released Section home.
const SEAT_TIME := 0.5
## The clunk once it is home: particle strength and density, the camera bump, and how
## near (px) the ship must be to feel it.
const CLUNK_BURST := 2.0
const CLUNK_DENSITY := 3.0
const CLUNK_SHAKE_INTENSITY := 2.5
const CLUNK_SHAKE_DURATION := 0.4
const CLUNK_FELT_WITHIN := 1500.0
## How deep the torn edge's teeth run into the gap, cycling along the edge (px), and how
## far apart they are. Shallow, so the gap still reads as wide enough for the Section.
const TEAR_TEETH := [3.0, 6.0, 2.0, 5.0, 2.0, 7.0, 4.0, 3.0]
const TEAR_TOOTH_WIDTH := 7.0

## Which Section fits here (Sections.gd).
@export var section := Sections.MAST_1
## The station polygon the Section becomes once seated.
@export var part: NodePath
## The station's collision, which loses the part's exposed pieces while it is missing.
@export var collision: NodePath
## Where a new game leaves the Section: floating dead this far from the station (in the
## station's frame), turned this much.
@export var section_start_offset := Vector2(-460, 110)
@export var section_start_rotation := 0.25

var seated := false
var _part: Polygon2D
var _collision: CollisionPolygon2D
var _cut_pieces: Array[CollisionPolygon2D] = []
var _is_cut := false
## The part's exposed pieces, in the part's own space, and which of their edges are torn.
var _gaps: Array[PackedVector2Array] = []
var _tracking: NodeTrackingTarget
var _seating: Tween

func _ready() -> void:
	add_to_group("mounts")
	z_index = 1
	_part = get_node_or_null(part) as Polygon2D
	_collision = get_node_or_null(collision) as CollisionPolygon2D
	if _part:
		_gaps = exposed_regions(_part.polygon, _covers())
	EventBus.planets_restored.connect(refresh)
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	_show_seated(gs != null and gs.is_section_seated(section))

## The Mount for Section `id` in `tree`, or null.
static func for_section(tree: SceneTree, id: String) -> Mount:
	for node in tree.get_nodes_in_group("mounts"):
		var m := node as Mount
		if m and m.section == id:
			return m
	return null

## The Mount `f` would seat in if let go of right now, or null.
static func accepting(tree: SceneTree, f: Freight) -> Mount:
	if f == null or f.section == "":
		return null
	var m := for_section(tree, f.section)
	return m if m and m.fits(f) else null

## Whether `f` is this Mount's Section, the Mount is still empty, and the piece is close
## enough in place and turn to be pulled home.
func fits(f: Freight) -> bool:
	return not seated and f != null and f.section == section \
		and matching_seat(f.global_transform, seats()) >= 0

## Every pose the Section can be pulled home into, in world space: the middle of each of
## the part's gaps, the Mount's way round and turned end for end.
func seats() -> Array[Transform2D]:
	var out: Array[Transform2D] = [global_transform, global_transform * Transform2D(PI, Vector2.ZERO)]
	if _part == null:
		return out
	var to_me := global_transform.affine_inverse() * _part.global_transform
	for gap in _gaps:
		var at := to_me * Freight.bounds(gap).get_center()
		if at.length() < 1.0:
			continue  # the Mount's own seat, already in
		out.append(global_transform * Transform2D(0.0, at))
		out.append(global_transform * Transform2D(PI, at))
	return out

## The index of the first of `seat_poses` that `piece` is within tolerance of, or -1.
static func matching_seat(piece: Transform2D, seat_poses: Array[Transform2D]) -> int:
	for i in seat_poses.size():
		if in_tolerance(piece, seat_poses[i]):
			return i
	return -1

static func in_tolerance(piece: Transform2D, mount: Transform2D) -> bool:
	return piece.origin.distance_to(mount.origin) <= SEAT_RANGE \
		and absf(angle_difference(piece.get_rotation(), mount.get_rotation())) <= SEAT_ANGLE

func tracking_target() -> NodeTrackingTarget:
	if _tracking == null:
		_tracking = NodeTrackingTarget.new(self, "MOUNT", 60.0)
	return _tracking

## Match the saved or new game: seated or torn, and a missing Section somewhere in the
## world. Runs on every new game and load (planets_restored).
func refresh() -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	_show_seated(gs != null and gs.is_section_seated(section))
	ensure_section()

## The Section is never lost: while the Mount is empty and no piece of it is anywhere in
## the world (a new game, or a save from before Sections), one is left floating dead just
## outside the station, keeping pace with it. A piece put back from a save still lodged
## is lodged again.
func ensure_section() -> void:
	var piece := _find_section()
	if seated:
		if piece:  # already home: a stale copy must not linger
			piece.remove_from_group("freight")
			piece.queue_free()
		return
	var anchor := get_parent() as Node2D
	if piece == null:
		if anchor == null:
			return
		var world := get_tree().get_first_node_in_group("ship")
		world = world.get_parent() if world else anchor
		piece = Freight.spawn_section(world, section, anchor.to_global(section_start_offset), anchor.global_rotation + section_start_rotation)
		piece.lodge_in(anchor, section_start_offset)
	elif piece.lodged and anchor:
		piece.lodge_in(anchor, piece.lodged_offset)

## Pull `f` home and seat it. `f` has just been let go of, within tolerance.
func seat(f: Freight) -> void:
	if seated or f == null:
		return
	seated = true
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.mark_section_seated(section)
		Save.save_seated_section(section, PackedStringArray(gs.seated_sections.keys()))
	# From here it is part of the station, not Freight: no saves, marks or Sweep answers
	f.remove_from_group("freight")
	f.remove_from_group("sonar_listeners")
	f.process_mode = Node.PROCESS_MODE_DISABLED
	var poses := seats()
	var home := poses[maxi(matching_seat(f.global_transform, poses), 0)]
	f.reparent(self, true)
	NavSystem.track_home()
	_seating = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_seating.tween_property(f, "transform", global_transform.affine_inverse() * home, SEAT_TIME)
	_seating.tween_callback(func() -> void:
		_clunk()
		f.queue_free()
		_show_seated(true))

func is_seating() -> bool:
	return _seating != null and _seating.is_running()

func _show_seated(on: bool) -> void:
	seated = on
	if _part:
		_part.visible = on
	_set_cut.call_deferred(not on)
	queue_redraw()

## The station's collision with the part's exposed pieces cut out (a missing part is
## not a wall), or whole again. Deferred: shapes can't change mid physics step.
func _set_cut(cut: bool) -> void:
	if _collision == null or cut == _is_cut:
		return
	_is_cut = cut
	for piece in _cut_pieces:
		piece.queue_free()
	_cut_pieces.clear()
	_collision.disabled = cut
	if not cut:
		return
	var to_collision := _collision.transform.affine_inverse() * _part_to_station()
	var holes: Array[PackedVector2Array] = []
	for gap in _gaps:
		holes.append(to_collision * gap)
	for poly in cut_polygon(_collision.polygon, holes):
		var piece := CollisionPolygon2D.new()
		piece.name = "TornCollision"
		piece.polygon = poly
		piece.transform = _collision.transform
		_collision.get_parent().add_child(piece)
		_cut_pieces.append(piece)

## `poly` with every one of `holes` cut out of it: the pieces left.
static func cut_polygon(poly: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [poly]
	for hole in holes:
		# A hair wider, so edges that line up exactly leave no slivers behind
		var grown := Geometry2D.offset_polygon(hole, 0.5)
		var cutter: PackedVector2Array = grown[0] if not grown.is_empty() else hole
		var next: Array[PackedVector2Array] = []
		for p in pieces:
			next.append_array(Geometry2D.clip_polygons(p, cutter))
		pieces = next
	return pieces

## The parts of `part_poly` not hidden under any of `covers`: what shows of it, and so
## what goes missing when it is gone.
static func exposed_regions(part_poly: PackedVector2Array, covers: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var regions: Array[PackedVector2Array] = [part_poly]
	for cover in covers:
		var next: Array[PackedVector2Array] = []
		for r in regions:
			next.append_array(Geometry2D.clip_polygons(r, cover))
		regions = next
	var out: Array[PackedVector2Array] = []
	for r in regions:
		if absf(_area(r)) > 1.0:
			out.append(r)
	return out

## The other station polygons, in the part's space.
func _covers() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for sibling in _part.get_parent().get_children():
		var p := sibling as Polygon2D
		if p and p != _part:
			out.append(_part.transform.affine_inverse() * p.transform * p.polygon)
	return out

func _part_to_station() -> Transform2D:
	var station := get_parent() as Node2D
	return station.global_transform.affine_inverse() * _part.global_transform

func _find_section() -> Freight:
	for node in get_tree().get_nodes_in_group("freight"):
		var f := node as Freight
		if f and f.section == section and not f.is_queued_for_deletion():
			return f
	return null

func _clunk() -> void:
	var world := get_tree().get_first_node_in_group("ship")
	var ship := world as Ship
	var parent := ship.get_parent() if ship else get_parent()
	var velocity := (get_parent() as RigidBody2D).linear_velocity if get_parent() is RigidBody2D else Vector2.ZERO
	ClampFX.burst(parent, global_position, velocity, CLUNK_BURST, CLUNK_DENSITY)
	HarvestJuice.ring(parent, global_position, Color(Colors.CREAM, Ship.CLAMP_RING_ALPHA), 70.0, velocity)
	HarvestJuice.ring(parent, global_position, Color(Colors.PRIMARY, Ship.CLAMP_RING_ALPHA), 120.0, velocity)
	if ship and ship.global_position.distance_to(global_position) <= CLUNK_FELT_WITHIN:
		ship.damage_shake_time = CLUNK_SHAKE_DURATION
		ship.damage_shake_current_intensity = CLUNK_SHAKE_INTENSITY

# --- the tear ---

func _draw() -> void:
	if seated or _part == null:
		return
	var to_me := global_transform.affine_inverse() * _part.global_transform
	var covers := _covers()
	for gap in _gaps:
		var box := Freight.bounds(gap)
		for edge in torn_edges(box, covers):
			_draw_torn_edge(to_me, edge[0], edge[1], edge[2])

## The edges of `box` that the part was torn from - where another station polygon is on
## the far side - as [from, to, inward] in the part's space (inward points into the gap).
static func torn_edges(box: Rect2, covers: Array[PackedVector2Array]) -> Array:
	var tl := box.position
	var br := box.end
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	var candidates := [
		[tl, tr, Vector2.DOWN], [bl, br, Vector2.UP],
		[tl, bl, Vector2.RIGHT], [tr, br, Vector2.LEFT],
	]
	var out := []
	for e in candidates:
		var probe: Vector2 = (e[0] + e[1]) * 0.5 - e[2] * 2.0
		for cover in covers:
			if Geometry2D.is_point_in_polygon(probe, cover):
				out.append(e)
				break
	return out

## Sheared plating along one torn edge - a ragged strip of the lost part still hanging on
## - with bent bracket stubs sticking out of it.
func _draw_torn_edge(to_me: Transform2D, from: Vector2, to: Vector2, inward: Vector2) -> void:
	var length := from.distance_to(to)
	var along := (to - from).normalized()
	var teeth := PackedVector2Array([from])
	var steps := maxi(int(length / TEAR_TOOTH_WIDTH), 2)
	for i in steps + 1:
		var t := float(i) / steps
		var depth: float = TEAR_TEETH[i % TEAR_TEETH.size()]
		teeth.append(from + along * length * t + inward * depth)
	teeth.append(to)
	var ragged := to_me * teeth
	draw_colored_polygon(ragged, Colors.HULL_DARK)
	draw_polyline(to_me * teeth.slice(1, teeth.size() - 1), Colors.HULL_LIGHT, 1.0)
	# Broken strut stubs: short bars bent off the edge, sheared at a slant
	for f: float in [0.2, 0.55, 0.85]:
		var base := from + along * length * f
		var bend := inward.rotated(0.35 if f < 0.5 else -0.3)
		var reach := 7.0 + 4.0 * f
		var tip := base + bend * reach
		var sheared := tip + along * 4.0 - bend * 3.0
		var stub := PackedVector2Array([
			base - along * 2.5, base + along * 2.5, sheared, tip - along * 2.5,
		])
		draw_colored_polygon(to_me * stub, Colors.HULL_MID)
		draw_polyline(to_me * PackedVector2Array([base - along * 2.5, tip - along * 2.5, sheared, base + along * 2.5]), Colors.HULL_LIGHT, 1.0)

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
