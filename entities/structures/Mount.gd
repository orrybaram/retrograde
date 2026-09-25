extends Node2D
class_name Mount

## The cut place on SR-7 where one Section belongs (docs/adr/0012, docs/OPENING.md §2).
## Until the Section is seated, the station's `part` polygon is hidden, the parts of it
## that showed are cut out of the station's collision, and the edges it was cut from are
## drawn as they were left: a straight torch line, empty bolt holes, a few beads of slag,
## squared-off bracket stubs. SR-7 was taken apart, not broken, so nothing here is torn -
## and it is never a ghost outline or a socket.
##
## The Section goes home into any of the part's gaps - wherever the cut shows - either way
## round: turned end for end it still fits. Released within SEAT_RANGE px and SEAT_ANGLE
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
## The cut edge: the lip of plate left standing (px deep), the spacing of the emptied
## bolt holes along it and how far in from the cut they sit, and every how-many holes a
## bead of slag hangs off the line.
const CUT_LIP := 3.0
const BOLT_PITCH := 10.0
const BOLT_INSET := 6.0
const SLAG_EVERY := 3
## How far past the gap the station's collision is cut back, so no sliver of wall is
## left standing where the part's edge met the hull's outline.
const COLLISION_CLEARANCE := 2.0
## How much of a buried Section sticks out of the ground (px, along its length).
const BURIED_EXPOSED := 62.0
## The scrap left beside a Section adrift in a ring sits this far (px) behind it round
## the orbit, and a Section with scrap already this near is left as it is.
const SCRAP_BESIDE := 130.0
const SCRAP_NEAR := 260.0
## How often (s) a Section adrift beside scrap checks it still has some.
const SCRAP_CHECK_TIME := 1.0
## How far back from the cut, onto the hull, the red emergency lamp sits (px).
const ALARM_LAMP_SETBACK := 7.0

## Which Section fits here (Sections.gd).
@export var section := Sections.FUEL_TANK
## The station polygon the Section becomes once seated.
@export var part: NodePath
## The station's collision, which loses the part's exposed pieces while it is missing.
@export var collision: NodePath
## Where a new game leaves the Section: floating dead at this offset, turned this much.
## The offset is in the frame of the planet the station orbits when `start_on_planet`
## (out in its debris, fixed there as the station moves on), else in the station's own.
@export var section_start_offset := Vector2(-460, 110)
@export var section_start_rotation := 0.25
@export var start_on_planet := false
## With `start_on_planet`: adrift in the planet's debris ring, going round with it at the
## ring's speed for its distance (OrbitalRingSpawner), instead of hanging still.
@export var start_in_orbit := false
## With `start_in_orbit`: a piece of scrap is left going round just beside it, so the Sweep
## that finds the Section is likely to find the scrap too.
@export var start_beside_scrap := false
## With `start_on_planet`: buried in the planet's ground on its sunlit face, the Lug end
## sticking out, taking Freight.BURY_TUGS tugs to pull free. `section_start_offset` is
## ignored; `section_start_rotation` leans it off straight up.
@export var start_buried := false

var seated := false
var _part: Polygon2D
var _collision: CollisionPolygon2D
## The part's exposed pieces, in the part's own space, and which of their edges were cut.
var _gaps: Array[PackedVector2Array] = []
var _tracking: NodeTrackingTarget
var _seating: Tween
## Sparks along the cut and a red strobe beside it, while the Section is missing.
var alarm: CutAlarm

func _ready() -> void:
	add_to_group("mounts")
	z_index = 1
	_part = get_node_or_null(part) as Polygon2D
	_collision = get_node_or_null(collision) as CollisionPolygon2D
	if _part:
		_gaps = exposed_regions(_part.polygon, _covers())
		_build_alarm()
	EventBus.planets_restored.connect(refresh)
	if start_beside_scrap:
		# The ring clears and respawns its scrap on its own schedule (a new game, a load,
		# a harvest): keep checking the Section still has its companion while it waits
		var check := Timer.new()
		check.wait_time = SCRAP_CHECK_TIME
		check.autostart = true
		check.timeout.connect(_check_scrap_beside)
		add_child(check)
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

## Match the saved or new game: seated or cut away, and a missing Section somewhere in the
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
	var anchor := start_anchor()
	if piece == null:
		if anchor == null:
			return
		var world := get_tree().get_first_node_in_group("ship")
		world = world.get_parent() if world else get_parent()
		var offset := start_offset(anchor)
		var turn := section_start_rotation
		if start_buried and anchor is Planet:
			turn += offset.angle() + PI  # standing out of the ground, Lug end up
		piece = Freight.spawn_section(world, section, anchor.to_global(offset), anchor.global_rotation + turn)
		piece.lodge_in(anchor, offset, start_spin(anchor, offset))
		if start_buried and anchor is Planet:
			piece.bury_in(anchor, Freight.BURY_TUGS)
	elif piece.lodged and anchor:
		piece.lodge_in(anchor, piece.lodged_offset, piece.lodged_spin)
		piece.bury_in(anchor)
	if start_beside_scrap and piece and piece.lodged and not piece.handled and not piece.beside_spent:
		_leave_scrap_beside.call_deferred(piece)

## What a new game's Section hangs in: the planet the station orbits when `start_on_planet`
## and there is one, else the station.
func start_anchor() -> Node2D:
	var station := get_parent() as Node2D
	if start_on_planet and station and station.get_parent() is Planet:
		return station.get_parent() as Node2D
	return station

## Where a new game leaves the Section in `anchor`'s frame.
func start_offset(anchor: Node2D) -> Vector2:
	var planet := anchor as Planet
	if start_buried and planet:
		var sun_dir := (VoidZone.sun_position() - planet.global_position).normalized()
		var local_dir := planet.global_transform.basis_xform_inv(sun_dir).normalized()
		var half_length := Freight.bounds(PackedVector2Array(Sections.DATA[section]["outline"])).size.x * 0.5
		return local_dir * (ground_radius(planet) + half_length - BURIED_EXPOSED)
	return section_start_offset

## How far out a planet's ground is: its collision, or its disc if that is bigger.
static func ground_radius(planet: Planet) -> float:
	return planet.radius * maxf(planet.collision_radius_ratio, 1.0)

## How fast a new game's Section goes round `anchor` from `offset`: the debris ring's own
## speed at that distance when `start_in_orbit`, else still.
func start_spin(anchor: Node2D, offset: Vector2) -> float:
	if not start_in_orbit:
		return 0.0
	for child in anchor.get_children():
		var ring := child as OrbitalRingSpawner
		if ring:
			return OrbitalRingSpawner.angular_speed(ring.orbital_speed, offset.length())
	return 0.0

## Put a piece of scrap going round beside `piece` in the ring, unless one already is.
## Deferred a frame: a load clears and respawns the ring on the same signal that brings
## the piece back, and the scrap must land after that, not be swept away by it.
func _leave_scrap_beside(piece: Freight) -> void:
	await get_tree().process_frame
	if not is_instance_valid(piece) or not piece.lodged or piece.lodged_in == null or piece.beside_spent:
		return
	var ring: OrbitalRingSpawner = null
	for child in piece.lodged_in.get_children():
		if child is OrbitalRingSpawner:
			ring = child
	if ring == null:
		return
	var scrap := _scrap_near(piece)
	if scrap == null:
		var r := piece.lodged_offset.length()
		scrap = ring.spawn_scrap_at(r, piece.lodged_offset.angle() - SCRAP_BESIDE / maxf(r, 1.0))
	if scrap and scrap._orbital_motion:
		var world_angle := piece.lodged_in.global_transform.basis_xform(piece.lodged_offset).angle()
		piece.lodge_beside(scrap, angle_difference(scrap._orbital_motion.angle_now(), world_angle))
		# Harvested, it is gone for good: the Section is not given another
		var on_harvest := _on_companion_harvested.bind(scrap)
		if not scrap.resource_depleted.is_connected(on_harvest):
			scrap.resource_depleted.connect(on_harvest)

## A pooled scrap is reused elsewhere later, so it only counts while it is still this
## Section's companion.
func _on_companion_harvested(scrap: Node2D) -> void:
	var piece := _find_section()
	if piece and piece.lodged_beside == scrap:
		piece.beside_spent = true
		piece.lodged_beside = null

## The ring clears and respawns its scrap on a new game or a load, which can take the
## companion away; put it back then - but never once the player has harvested it.
func _check_scrap_beside() -> void:
	var piece := _find_section()
	if piece and piece.lodged and not piece.handled and not piece.beside_spent and not piece._beside_valid():
		_leave_scrap_beside(piece)

## Scrap already going round close beside `piece`, on its own orbit (so the two keep
## together), or null.
func _scrap_near(piece: Freight) -> ScrapNode:
	var r := piece.lodged_offset.length()
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		var s := node as ScrapNode
		if s == null or not s.is_inside_tree() or s.amount <= 0:
			continue
		if s._orbital_motion and s._orbital_motion.orbital_body == piece.lodged_in \
				and s.global_position.distance_to(piece.global_position) <= SCRAP_NEAR \
				and absf(s._orbital_motion.orbital_distance - r) < 20.0:
			return s
	return null

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
	NavSystem.clear()
	_seating = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_seating.tween_property(f, "transform", global_transform.affine_inverse() * home, SEAT_TIME)
	_seating.tween_callback(func() -> void:
		Mount.clunk(self)
		f.queue_free()
		_show_seated(true)
		EventBus.section_seated.emit(section))

func is_seating() -> bool:
	return _seating != null and _seating.is_running()

func _show_seated(on: bool) -> void:
	seated = on
	if _part:
		_part.visible = on
	if alarm:
		alarm.active = not on
	Mount.recut.call_deferred(_collision, get_tree())
	queue_redraw()

## Rebuild the station's `collision` with the gaps of every empty Mount on it cut out (a
## missing part is not a wall), or whole again once all are seated. The Mounts share the
## one hull, so it is always cut for all of them at once. Deferred by callers: shapes
## can't change mid physics step.
static func recut(collision: CollisionPolygon2D, tree: SceneTree) -> void:
	if collision == null or not is_instance_valid(collision) or tree == null:
		return
	for piece in collision.get_meta("cut_pieces", []):
		if is_instance_valid(piece):
			piece.queue_free()
	var holes: Array[PackedVector2Array] = []
	for node in tree.get_nodes_in_group("mounts"):
		var m := node as Mount
		if m and m._collision == collision and not m.seated and m._part:
			var to_collision := collision.transform.affine_inverse() * m._part_to_station()
			for gap in m._gaps:
				holes.append(to_collision * gap)
	collision.disabled = not holes.is_empty()
	var pieces: Array[CollisionPolygon2D] = []
	if not holes.is_empty():
		for poly in cut_polygon(collision.polygon, holes):
			var piece := CollisionPolygon2D.new()
			piece.name = "CutCollision"
			piece.polygon = poly
			piece.transform = collision.transform
			collision.get_parent().add_child(piece)
			pieces.append(piece)
	collision.set_meta("cut_pieces", pieces)

## `poly` with every one of `holes` cut out of it: the pieces left.
static func cut_polygon(poly: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = [poly]
	for hole in holes:
		# A little wider, so edges that line up with the hull leave no slivers behind
		var grown := Geometry2D.offset_polygon(hole, COLLISION_CLEARANCE)
		var cutter: PackedVector2Array = grown[0] if not grown.is_empty() else hole
		var next: Array[PackedVector2Array] = []
		for p in pieces:
			# A hole wholly inside comes back as a clockwise outline of itself: a collision
			# polygon can't hold a hole, so it is dropped rather than walled in solid
			next.append_array(Geometry2D.clip_polygons(p, cutter).filter(
				func(q: PackedVector2Array) -> bool: return not Geometry2D.is_polygon_clockwise(q)))
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

## The clunk of something going home on SR-7 at `at`: sparks, two rings, and a bump the
## ship feels if it is near. Shared with the nudged solar wing (ArrayNudge).
static func clunk(at: Node2D) -> void:
	var ship := at.get_tree().get_first_node_in_group("ship") as Ship
	var parent := ship.get_parent() if ship else at.get_parent()
	var station := at.get_parent() as RigidBody2D
	var velocity := station.linear_velocity if station else Vector2.ZERO
	ClampFX.burst(parent, at.global_position, velocity, CLUNK_BURST, CLUNK_DENSITY)
	HarvestJuice.ring(parent, at.global_position, Color(Colors.CREAM, Ship.CLAMP_RING_ALPHA), 70.0, velocity)
	HarvestJuice.ring(parent, at.global_position, Color(Colors.PRIMARY, Ship.CLAMP_RING_ALPHA), 120.0, velocity)
	if ship and ship.global_position.distance_to(at.global_position) <= CLUNK_FELT_WITHIN:
		ship.damage_shake_time = CLUNK_SHAKE_DURATION
		ship.damage_shake_current_intensity = CLUNK_SHAKE_INTENSITY

# --- the cut ---

## The alarm at the cut: sparks off every cut edge, spraying into the gap, and a red lamp
## on the hull just behind the longest edge of each gap.
func _build_alarm() -> void:
	alarm = CutAlarm.new()
	alarm.name = "Alarm"
	var to_me := global_transform.affine_inverse() * _part.global_transform
	var covers := _covers()
	for gap in _gaps:
		var longest: Array = []
		for edge in cut_edges(Freight.bounds(gap), covers):
			var from: Vector2 = to_me * edge[0]
			var to: Vector2 = to_me * edge[1]
			var inward := to_me.basis_xform(edge[2]).normalized()
			alarm.segments.append([from + inward * CUT_LIP, to + inward * CUT_LIP, inward])
			if longest.is_empty() or from.distance_to(to) > longest[0].distance_to(longest[1]):
				longest = [from, to, inward]
		if not longest.is_empty():
			alarm.lamps.append((longest[0] + longest[1]) * 0.5 - longest[2] * ALARM_LAMP_SETBACK)
	add_child(alarm)

func _draw() -> void:
	if seated or _part == null:
		return
	var to_me := global_transform.affine_inverse() * _part.global_transform
	var covers := _covers()
	for gap in _gaps:
		var box := Freight.bounds(gap)
		for edge in cut_edges(box, covers):
			_draw_cut_edge(to_me, edge[0], edge[1], edge[2])

## The edges of `box` the part was cut from - where another station polygon is on the
## far side - as [from, to, inward] in the part's space (inward points into the gap).
static func cut_edges(box: Rect2, covers: Array[PackedVector2Array]) -> Array:
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

## Where the emptied bolt holes sit along a cut edge `length` px long: every BOLT_PITCH,
## never closer than half a pitch to either end.
static func bolt_stations(length: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := int(floor(length / BOLT_PITCH))
	if count < 1:
		return out
	var start := (length - (count - 1) * BOLT_PITCH) * 0.5
	for i in count:
		out.append(start + i * BOLT_PITCH)
	return out

## One cut edge: a lip of plate with a straight torch line along it, the holes its bolts
## came out of, slag hanging off the line, and two bracket stubs cut square.
func _draw_cut_edge(to_me: Transform2D, from: Vector2, to: Vector2, inward: Vector2) -> void:
	var along := (to - from).normalized()
	var length := from.distance_to(to)
	var lip := PackedVector2Array([from, to, to + inward * CUT_LIP, from + inward * CUT_LIP])
	draw_colored_polygon(to_me * lip, Colors.HULL_DARK)
	draw_line(to_me * (from + inward * CUT_LIP), to_me * (to + inward * CUT_LIP), Colors.HULL_LIGHT, 1.0)
	var stations := bolt_stations(length)
	for i in stations.size():
		var at := from + along * stations[i] - inward * (BOLT_INSET - CUT_LIP)
		draw_circle(to_me * at, 1.8, Colors.SPACE_BG)
		draw_arc(to_me * at, 1.8, 0.0, TAU, 8, Colors.HULL_LIGHT, 1.0)
		if i % SLAG_EVERY == 1:
			draw_circle(to_me * (from + along * (stations[i] + 3.0) + inward * (CUT_LIP + 1.5)), 1.4, Color(Colors.CREAM, 0.55))
	# Bracket stubs: short bars standing into the gap, cut off square
	for f: float in [0.25, 0.75]:
		var base := from + along * length * f + inward * CUT_LIP
		var stub := PackedVector2Array([
			base - along * 2.5, base + along * 2.5,
			base + along * 2.5 + inward * 7.0, base - along * 2.5 + inward * 7.0,
		])
		draw_colored_polygon(to_me * stub, Colors.HULL_MID)
		draw_line(to_me * (base - along * 2.5 + inward * 7.0), to_me * (base + along * 2.5 + inward * 7.0), Colors.HULL_LIGHT, 1.0)

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
