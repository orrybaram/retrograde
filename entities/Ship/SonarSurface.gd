extends Node2D
class_name SonarSurface

## Something a Sweep ring meets on its way (SonarRing): an outline - taken from a collision
## shape it sits beside, or set by hand (set_polygons) - and a SonarMaterial that says what
## the ring does inside it. Opt-in: only what carries one of these blocks a ring; the rest of
## the world (scrap, freight, the ship) lets it through.
##
## Lives in group `sonar_surfaces` while it is in the tree and visible, so a pooled or
## sleeping rock (ResourceNodePool, OrbitalNode) drops out of every ring until it is back.
##
## Outlines stay in the target's local space; a ring asks in global space and the surface
## turns the point round with a cached inverse transform, so a moving station or a drifting
## rock costs nothing extra per frame. Holes are not modelled.
##
## The station's hull follows Mount.recut: while Sections are missing its collision polygon
## is disabled and the cut pieces left (meta `cut_pieces`) are what the ring meets.
##
## A `reactive` material samples the outline every SAMPLE px and reports each ring's touch
## (`touched`): which sample, and with what amplitude the ring got there. Nothing is drawn
## here; the glow belongs to whoever listens (SonarGlow).
##
## An outline can also be a set of open lines (set_polylines): something a ring only touches,
## never enters - the cut edges round a Mount's gap. It has no inside, so it blocks nothing.
## One-sided lines are faces: a ring only touches them from the side they face. A closed
## outline faces outward the same way, so a ring bending round a solid never lights its back.

## A ring reached outline sample `sample_index` (global_samples) with `amplitude` (0..1),
## sent from `origin`; `ring` tells one ring from the next. Reactive materials only, once per
## ring per sample.
signal touched(sample_index: int, amplitude: float, origin: Vector2, ring: int)

const GROUP := &"sonar_surfaces"
## Spacing of a reactive outline's samples, px.
const SAMPLE := 5.0

enum Preset { PLATE, ROCK, PLANET }
@export var preset := Preset.PLATE
## Overrides the preset when set.
@export var sonar_material: SonarMaterial
## The CollisionPolygon2D or CollisionShape2D (circle, rectangle or convex polygon) whose
## outline this is. Empty: the first such sibling.
@export var target: NodePath

## Global bounding circle, current after refresh().
var center := Vector2.ZERO
var bound_radius := 0.0

var _target: Node2D
var _manual := false
## Outline pieces in the target's space, and each one's box.
var _polys: Array[PackedVector2Array] = []
var _rects: Array[Rect2] = []
var _circle := false
## The outline is open lines, not polygons: touched, never entered.
var _open := false
var _circle_radius := 0.0
var _local_center := Vector2.ZERO
var _local_radius := 0.0
var _xform := Transform2D()
var _inv := Transform2D()
var _scale := 1.0
var _has_xform := false
## What the outline was last built from, to notice it changing.
var _src_poly := PackedVector2Array()
var _src_pieces: Array = []
var _src_disabled := false
var _src_radius := -1.0
## Reactive outline samples, in the target's space, and the sample that follows each one
## along the outline (-1 at the end of an open line).
var _samples := PackedVector2Array()
var _next := PackedInt32Array()
## The way each sample faces, outward (empty: every side is touched - two-sided lines).
var _facing := PackedVector2Array()
var _one_sided := false

## A surface of `mat` (a preset if null) on `collision`, added under `parent`.
static func attach(parent: Node, collision: Node2D, mat_preset := Preset.PLATE, mat: SonarMaterial = null) -> SonarSurface:
	var s := SonarSurface.new()
	s.name = "SonarSurface"
	s.preset = mat_preset
	s.sonar_material = mat
	parent.add_child(s)
	s.set_target(collision)
	return s

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_VISIBILITY_CHANGED:
			_sync_group()
		NOTIFICATION_EXIT_TREE:
			if is_in_group(GROUP):
				remove_from_group(GROUP)

func _sync_group() -> void:
	var on := is_inside_tree() and is_visible_in_tree()
	if on and not is_in_group(GROUP):
		add_to_group(GROUP)
	elif not on and is_in_group(GROUP):
		remove_from_group(GROUP)

func get_sonar_material() -> SonarMaterial:
	if sonar_material:
		return sonar_material
	match preset:
		Preset.ROCK:
			return SonarMaterial.ROCK
		Preset.PLANET:
			return SonarMaterial.PLANET
	return SonarMaterial.PLATE

func set_target(node: Node2D) -> void:
	_target = node
	_manual = false
	_open = false
	_one_sided = false
	_has_xform = false
	_src_radius = -1.0
	_src_poly = PackedVector2Array()

## Use these outlines (in this node's own space) instead of a collision shape.
func set_polygons(polys: Array[PackedVector2Array]) -> void:
	_target = self
	_manual = true
	_has_xform = false
	_open = false
	_one_sided = false
	_set_outline(polys)

## Use these open lines (in this node's own space) as the outline: a ring touches them where
## it reaches them, and passes on as if they were not there. `one_sided`: each line is a face,
## touched only from the side `(b - a).orthogonal()` points to along it.
func set_polylines(lines: Array[PackedVector2Array], one_sided := false) -> void:
	_target = self
	_manual = true
	_has_xform = false
	_open = true
	_one_sided = one_sided
	_set_outline(lines)

## Whether a ring is stopped, slowed or shadowed by it at all: an open outline has no inside.
func blocks() -> bool:
	return not _open

## Whether it takes part at all: in the tree, visible, and with something to meet.
func is_active() -> bool:
	if not is_inside_tree() or not is_visible_in_tree():
		return false
	if _target == null and not _manual:
		_target = _find_target()
	return _target != null and is_instance_valid(_target) and _target.is_inside_tree() \
		and (_circle or not _polys.is_empty() or _rebuild_needed())

## Bring the outline and bounding circle up to date with the world as it is now. Cheap when
## nothing moved.
func refresh() -> void:
	if _target == null or not is_instance_valid(_target):
		_target = _find_target()
		if _target == null:
			return
	if not _manual and _rebuild_needed():
		_rebuild()
	var xf := _target.global_transform
	if _has_xform and xf == _xform:
		return
	_xform = xf
	_inv = xf.affine_inverse()
	_scale = maxf(xf.x.length(), xf.y.length())
	_has_xform = true
	center = xf * _local_center
	bound_radius = _local_radius * _scale

## Whether global `p` is inside (call refresh() first in a frame).
func contains(p: Vector2) -> bool:
	if _open:
		return false
	var q := _inv * p
	if _circle:
		return q.length_squared() <= _circle_radius * _circle_radius
	for i in _polys.size():
		if _rects[i].has_point(q) and Geometry2D.is_point_in_polygon(q, _polys[i]):
			return true
	return false

## The outward normal of the outline near global `p`, turned to face `from`.
func normal_at(p: Vector2, from: Vector2) -> Vector2:
	var q := _inv * p
	var n := Vector2.ZERO
	if _circle:
		n = q.normalized()
	else:
		var best := INF
		for poly in _polys:
			var count := poly.size()
			for i in count:
				var a := poly[i]
				var b := poly[(i + 1) % count]
				var c := Geometry2D.get_closest_point_to_segment(q, a, b)
				var d := q.distance_squared_to(c)
				if d < best and a != b:
					best = d
					var t := (b - a).normalized()
					n = Vector2(-t.y, t.x)
	n = (_xform.basis_xform(n)).normalized()
	if n.dot(from - p) < 0.0:
		n = -n
	return n

## Where the straight line from `from` to `to` (inside) last comes in through the outline:
## the point a ring heading for `to` meets the surface. `to` itself if it isn't inside.
func entry_point(from: Vector2, to: Vector2, step := 2.0) -> Vector2:
	var length := from.distance_to(to)
	if length <= 0.0:
		return to
	var back := (from - to) / length
	var p := to
	var went := 0.0
	while went < length and contains(p):
		went += step
		p = to + back * minf(went, length)
	return p

## The outline in global space: polygons (empty for a circle).
func global_polygons() -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for poly in _polys:
		out.append(_xform * poly)
	return out

## For a circle: its global centre and radius (radius 0 when it is a polygon).
func global_circle() -> Vector3:
	if not _circle:
		return Vector3.ZERO
	var c := _xform.origin
	return Vector3(c.x, c.y, _circle_radius * _scale)

## The reactive outline's samples in global space (empty unless reactive).
func global_samples() -> PackedVector2Array:
	return _xform * _samples

func sample_count() -> int:
	return _samples.size()

## Whether sample `i` can be touched by a ring from global `from`: not from behind the face
## it is on (except on two-sided lines).
func faces(i: int, from: Vector2) -> bool:
	if _facing.is_empty():
		return true
	return _xform.basis_xform(_facing[i]).dot(from - _xform * _samples[i]) > 0.0

## The sample after `i` along the outline: round a closed outline, -1 at an open line's end.
func next_sample(i: int) -> int:
	return _next[i] if i >= 0 and i < _next.size() else -1

## A ring (`ring`, any id that tells rings apart) reached sample `i` with `amplitude`
## (SonarRing). The hook for a glow or trace.
func touch(i: int, amplitude: float, origin: Vector2, ring := 0) -> void:
	touched.emit(i, amplitude, origin, ring)

func _find_target() -> Node2D:
	if not target.is_empty():
		return get_node_or_null(target) as Node2D
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is CollisionPolygon2D or child is CollisionShape2D:
			return child
	return null

func _rebuild_needed() -> bool:
	if _target is CollisionPolygon2D:
		var cp := _target as CollisionPolygon2D
		return cp.polygon != _src_poly or cp.disabled != _src_disabled \
			or cp.get_meta("cut_pieces", []) != _src_pieces
	if _target is CollisionShape2D:
		var shape := (_target as CollisionShape2D).shape
		if shape is CircleShape2D:
			return not _circle or (shape as CircleShape2D).radius != _src_radius
		return _src_radius < 0.0
	return false

func _rebuild() -> void:
	_has_xform = false
	var polys: Array[PackedVector2Array] = []
	if _target is CollisionPolygon2D:
		var cp := _target as CollisionPolygon2D
		_src_poly = cp.polygon
		_src_disabled = cp.disabled
		_src_pieces = cp.get_meta("cut_pieces", []).duplicate()
		var pieces: Array = _src_pieces.filter(func(p): return is_instance_valid(p) and p is CollisionPolygon2D)
		if not pieces.is_empty():
			# Mount.recut's pieces share the hull's parent and transform
			for piece in pieces:
				var to_target := cp.transform.affine_inverse() * (piece as CollisionPolygon2D).transform
				polys.append(to_target * (piece as CollisionPolygon2D).polygon)
		elif not cp.disabled:
			polys.append(cp.polygon)
		_set_outline(polys)
		return
	var shape := (_target as CollisionShape2D).shape if _target is CollisionShape2D else null
	if shape is CircleShape2D:
		_circle = true
		_circle_radius = (shape as CircleShape2D).radius
		_src_radius = _circle_radius
		_polys.clear()
		_rects.clear()
		_local_center = Vector2.ZERO
		_local_radius = _circle_radius
		_samples = PackedVector2Array()
		_next = PackedInt32Array()
		_facing = PackedVector2Array()
		if get_sonar_material().reactive:
			var n := maxi(8, ceili(TAU * _circle_radius / SAMPLE))
			for i in n:
				_samples.append(Vector2.from_angle(TAU * i / n) * _circle_radius)
				_next.append((i + 1) % n)
				_facing.append(Vector2.from_angle(TAU * i / n))
		return
	_src_radius = 0.0
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size / 2.0
		polys.append(PackedVector2Array([-half, Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]))
	elif shape is ConvexPolygonShape2D:
		polys.append((shape as ConvexPolygonShape2D).points)
	_set_outline(polys)

func _set_outline(polys: Array[PackedVector2Array]) -> void:
	_circle = false
	_polys = polys
	_rects.clear()
	var box := Rect2()
	var first := true
	for poly in _polys:
		var r := Rect2()
		if not poly.is_empty():
			r = Rect2(poly[0], Vector2.ZERO)
			for p in poly:
				r = r.expand(p)
		_rects.append(r)
		box = r if first else box.merge(r)
		first = false
	_local_center = box.get_center()
	_local_radius = 0.0
	for poly in _polys:
		for p in poly:
			_local_radius = maxf(_local_radius, _local_center.distance_to(p))
	_samples = PackedVector2Array()
	_next = PackedInt32Array()
	_facing = PackedVector2Array()
	var faced := _one_sided or not _open
	if get_sonar_material().reactive:
		for poly in _polys:
			var start := _samples.size()
			var count := poly.size()
			var edges := count - 1 if _open else count
			# A closed outline faces out, whichever way round it was drawn
			var turn := 1.0 if _open or _faces_out(poly) else -1.0
			var before := Vector2.ZERO
			if not _open and count > 1:
				before = (poly[0] - poly[count - 1]).orthogonal().normalized() * turn
			for i in edges:
				var a := poly[i]
				var b := poly[(i + 1) % count]
				var face := (b - a).orthogonal().normalized() * turn
				var n := maxi(1, roundi(a.distance_to(b) / SAMPLE))
				for k in n:
					_samples.append(a.lerp(b, float(k) / n))
					if faced:
						# A corner faces both ways it is a corner of
						_facing.append((face + before).normalized() if k == 0 else face)
				before = face
			if _open and count > 0:
				_samples.append(poly[count - 1])  # an open line ends on its last point
				if faced:
					_facing.append(before)
			for i in range(start, _samples.size()):
				_next.append(i + 1)
			if _samples.size() > start:
				_next[_samples.size() - 1] = -1 if _open else start

## Whether `(b - a).orthogonal()` along closed `poly` points out of it (tested off its
## longest edge).
static func _faces_out(poly: PackedVector2Array) -> bool:
	var best := -1.0
	var mid := Vector2.ZERO
	var face := Vector2.ZERO
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if a.distance_squared_to(b) > best:
			best = a.distance_squared_to(b)
			mid = (a + b) * 0.5
			face = (b - a).orthogonal().normalized()
	return not Geometry2D.is_point_in_polygon(mid + face * 0.5, poly)
