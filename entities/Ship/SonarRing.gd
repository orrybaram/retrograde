extends RefCounted
class_name SonarRing

## One Sweep ring in the air (SonarPulse): RAYS rays from where it was sent, stepped every
## frame against the world as it is now (SonarSurface). The ring's front is an "effective
## distance" E that eases out to the ring's reach over its lifetime, the same easing the
## plain ring always had. Each ray steps STEP px at a time until its own effective distance
## reaches E: every px costs 1 in the open or inside a solid, and 1/speed + density inside a
## finite material (rock), so a rock drains a ray's reach and only a strong ring gets through.
## A ray ends when its effective distance runs out.
##
## Each ray carries an amplitude, 1 at the start and 0 inside a solid (the ray keeps going).
## What the ray had is written down every CELL px (`_hist`), so a listener is heard where
## the ring's amplitude at its point clears FIND, at the moment the ring passes it.
##
## Hot loop data is in packed arrays on this object, and the loops run in its own methods,
## so the arrays are written in place.

const RAYS := 360
const STEP := 4.0
const CELL := 8.0
## How close (px) a ray must come to a point to count as reaching it.
const TOL := 6.0
## The amplitude a ring must still have at a listener for it to hear.
const FIND := 0.3
## The amplitude a reactive outline still reports a touch at (SonarSurface.touched).
const SEE := 0.12
## Neighbouring rays further apart than this (px along the ray) are not one front.
const NEIGHBOUR_GAP := 30.0
## Listeners this far (px) ahead of the furthest ray are not looked at yet.
const LOOK_AHEAD := 64.0

var age := 0.0
var lifetime := 1.0
## Reach in open space (the old ring's radius; SonarPulse.widest_ring).
var radius := 280.0
var start_radius := 6.0
var alpha := 0.22
var width := 1.0
var color := Color.WHITE
var origin := Vector2.ZERO
var strength := 1.0
var marks: Array[int] = []
var sweep := true

var _dir := PackedVector2Array()
var _dist := PackedFloat32Array()
var _e := PackedFloat32Array()
var _amp := PackedFloat32Array()
var _alive := PackedByteArray()
## Instance id of the solid a ray is inside (0: none).
var _solid := PackedInt64Array()
## Whether a ray is inside a finite material (drawn dimmer).
var _inside := PackedByteArray()
## Amplitude per ray per CELL of distance; -1 where the ray has not been.
var _hist := PackedFloat32Array()
var _cells := 0
var _prev_e := 0.0
var _max_dist := 0.0
var _min_dist := 0.0
var _alive_count := 0
## Surfaces (instance ids) the ring started inside: open to it.
var _ignore := {}
## Per-frame candidates: surfaces near the stepped annulus.
var _cand: Array[SonarSurface] = []
var _cand_id := PackedInt64Array()
var _cand_c := PackedVector2Array()
var _cand_r2 := PackedFloat32Array()
var _cand_cost := PackedFloat32Array()
var _cand_solid := PackedByteArray()
## Per ray, which candidates' angular span covers it; and candidates covering every ray.
var _bucket: Array = []
var _bucket_used := PackedInt32Array()
var _all := PackedInt32Array()
## Listeners still waiting to hear the ring pass (sorted by distance at fire), and those
## answering from past its reach (heard when it dies).
var _pending: Array[Dictionary] = []
var _far: Array[Dictionary] = []
## Reactive surfaces' samples already decided this ring: surface id -> PackedByteArray.
var _lit := {}

func _init(at: Vector2, ring_strength: float, reach: float, life: float, start: float) -> void:
	origin = at
	strength = ring_strength
	radius = maxf(reach, start + 1.0)
	lifetime = maxf(life, 0.001)
	start_radius = start
	_cells = int(radius / CELL) + 3
	_dir.resize(RAYS)
	_dist.resize(RAYS)
	_e.resize(RAYS)
	_amp.resize(RAYS)
	_alive.resize(RAYS)
	_solid.resize(RAYS)
	_inside.resize(RAYS)
	_bucket.resize(RAYS)
	for i in RAYS:
		_dir[i] = Vector2.from_angle(TAU * i / RAYS)
		_amp[i] = 1.0
		_alive[i] = 1
		_bucket[i] = PackedInt32Array()
	_hist.resize(RAYS * _cells)
	_hist.fill(-1.0)
	_alive_count = RAYS

## The front's effective distance `at` s after leaving.
func front(at: float) -> float:
	var t := clampf(at / lifetime, 0.0, 1.0)
	return start_radius + (radius - start_radius) * (1.0 - (1.0 - t) * (1.0 - t))

func is_done() -> bool:
	return age >= lifetime

## The emitter's own body is open to its ring: any surface the ring starts inside, and any
## on the body `emitter` is mounted on (the dish rides on its station, just off the hull).
func ignore_own_body(surfaces: Array[SonarSurface], emitter: Node) -> void:
	for s in surfaces:
		var body := s.get_parent()
		if s.contains(origin) or (emitter and body and body.is_ancestor_of(emitter)):
			_ignore[s.get_instance_id()] = true

## Note who is listening, as the ring leaves. A listener with `answer_clarity` decides for
## itself; one answering from past the reach is heard when the ring dies, if the ray toward it
## still carries the ring there.
func listen(nodes: Array) -> void:
	for node in nodes:
		if not node.has_method("sonar_point") or not node.has_method("on_sonar_touched"):
			continue
		var d0 := origin.distance_to(node.sonar_point())
		var clarity := -1.0
		var far := false
		if node.has_method("answer_clarity"):
			clarity = node.answer_clarity(d0, radius)
			if clarity <= 0.0:
				continue
			far = d0 > radius
		elif d0 > radius:
			continue
		var entry := {"id": node.get_instance_id(), "d0": d0, "clarity": clarity,
			"far": far, "depth": -1.0}
		if far:
			_far.append(entry)
		else:
			_pending.append(entry)
	_pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.d0 < b.d0)

## Step every ray up to the front at `age`, against `surfaces` (refreshed this frame).
func advance(surfaces: Array[SonarSurface]) -> void:
	var big_e := front(age)
	if big_e <= _prev_e or _alive_count == 0:
		return
	_gather(surfaces, big_e)
	var max_d := 0.0
	var min_d := INF
	for i in RAYS:
		if _alive[i] == 1 and _e[i] < big_e:
			var bucket: PackedInt32Array = _bucket[i]
			if bucket.is_empty() and _all.is_empty():
				_glide(i, big_e)
			else:
				_march(i, big_e, bucket)
		if _alive[i] == 1:
			min_d = minf(min_d, _dist[i])
		max_d = maxf(max_d, _dist[i])
	_max_dist = max_d
	_min_dist = min_d if min_d < INF else max_d
	for i in _bucket_used:
		_bucket[i] = PackedInt32Array()
	_bucket_used.clear()
	_prev_e = big_e

## Surfaces that could be met between the closest live ray and the front, and which rays
## each could be met by (its angular span from the origin).
func _gather(surfaces: Array[SonarSurface], big_e: float) -> void:
	_cand.clear()
	_cand_id.clear()
	_cand_c.clear()
	_cand_r2.clear()
	_cand_cost.clear()
	_cand_solid.clear()
	_all.clear()
	var dtheta := TAU / RAYS
	for s in surfaces:
		var sid := s.get_instance_id()
		if _ignore.has(sid):
			continue
		var r := s.bound_radius
		var dc := origin.distance_to(s.center)
		if dc + r < _min_dist - STEP or dc - r > big_e + STEP:
			continue
		var m := s.get_sonar_material()
		var k := _cand.size()
		_cand.append(s)
		_cand_id.append(sid)
		_cand_c.append(s.center)
		_cand_r2.append(r * r)
		_cand_cost.append(m.cost())
		_cand_solid.append(1 if m.is_solid() else 0)
		if dc <= r + STEP:
			_all.append(k)
			continue
		var half := asin(clampf(r / dc, 0.0, 1.0))
		var ang := (s.center - origin).angle()
		var lo := floori((ang - half) / dtheta)
		var hi := ceili((ang + half) / dtheta)
		if hi - lo >= RAYS:
			_all.append(k)
			continue
		for j in range(lo, hi + 1):
			var i := posmod(j, RAYS)
			var bucket: PackedInt32Array = _bucket[i]
			if bucket.is_empty():
				_bucket_used.append(i)
			bucket.append(k)
			_bucket[i] = bucket

## A ray with nothing in its way this frame: straight on to the front.
func _glide(i: int, big_e: float) -> void:
	var n := ceili((big_e - _e[i]) / STEP)
	var d0 := _dist[i]
	var d1 := d0 + n * STEP
	var a := _amp[i]
	var base := i * _cells
	for c in range(int((d0 + STEP) / CELL), mini(int(d1 / CELL), _cells - 1) + 1):
		if _hist[base + c] < 0.0:
			_hist[base + c] = a
	_dist[i] = d1
	_e[i] += n * STEP
	_solid[i] = 0
	_inside[i] = 0
	if _e[i] >= radius:
		_alive[i] = 0
		_alive_count -= 1

## A ray that may meet something: STEP by STEP, looking at what is at each step's middle.
func _march(i: int, big_e: float, bucket: PackedInt32Array) -> void:
	var dir := _dir[i]
	var d := _dist[i]
	var e := _e[i]
	var a := _amp[i]
	var in_solid := _solid[i]
	var inside := 0
	var base := i * _cells
	var last_cell := _cells - 1
	var guard := 4096
	while e < big_e and guard > 0:
		guard -= 1
		var mid := origin + dir * (d + STEP * 0.5)
		var hit := -1
		for k in bucket:
			if mid.distance_squared_to(_cand_c[k]) <= _cand_r2[k] and _cand[k].contains(mid):
				hit = k
				break
		if hit < 0:
			for k in _all:
				if mid.distance_squared_to(_cand_c[k]) <= _cand_r2[k] and _cand[k].contains(mid):
					hit = k
					break
		var cost := 1.0
		inside = 0
		if hit >= 0 and _cand_solid[hit] == 1:
			var sid := _cand_id[hit]
			if in_solid != sid:
				# Meeting a solid's face: note what reached it, before it goes dark inside
				var cell := mini(int(d / CELL), last_cell)
				if _hist[base + cell] < a:
					_hist[base + cell] = a
				_on_hit(i, hit, origin + dir * d, a)
			in_solid = sid
			a = 0.0
		else:
			in_solid = 0
			if hit >= 0:
				cost = _cand_cost[hit]
				inside = 1
		e += STEP * cost
		d += STEP
		var c := mini(int(d / CELL), last_cell)
		if _hist[base + c] < 0.0:
			_hist[base + c] = a
		if e >= radius:
			_alive[i] = 0
			_alive_count -= 1
			break
	_dist[i] = d
	_e[i] = e
	_amp[i] = a
	_solid[i] = in_solid
	_inside[i] = inside

## A ray with amplitude `amp` met candidate `k`'s solid face at `at`.
func _on_hit(_i: int, _k: int, _at: Vector2, _amp_there: float) -> void:
	pass

## The amplitude the ring had at `d` px out along `angle` as it went past; -1 if it has not
## got there yet (and may still).
func amp_at(angle: float, d: float, tol := TOL) -> float:
	var f := posmod(angle, TAU) / TAU * RAYS
	var i0 := int(f) % RAYS
	var i1 := (i0 + 1) % RAYS
	var w := f - floorf(f)
	var a := _ray_amp_at(i0, d, tol)
	var b := _ray_amp_at(i1, d, tol)
	if a < 0.0 or b < 0.0:
		return -1.0
	return lerpf(a, b, w)

func amp_at_point(p: Vector2, tol := TOL) -> float:
	return amp_at((p - origin).angle(), origin.distance_to(p), tol)

func _ray_amp_at(i: int, d: float, tol: float) -> float:
	if _dist[i] < d - tol:
		return -1.0 if _alive[i] == 1 else 0.0
	var best := 0.0
	var base := i * _cells
	for c in range(maxi(floori((d - tol) / CELL), 0), mini(floori((d + 2.0) / CELL), _cells - 1) + 1):
		best = maxf(best, _hist[base + c])
	return best

## The amplitude the ray(s) toward `p` carry now (at the ring's end: what is left of it).
func amp_toward(p: Vector2) -> float:
	var f := posmod((p - origin).angle(), TAU) / TAU * RAYS
	var i0 := int(f) % RAYS
	var i1 := (i0 + 1) % RAYS
	return lerpf(_amp[i0], _amp[i1], f - floorf(f))

## Listeners the ring has just passed with amplitude to spare: their entries, to deliver.
## Reactive outlines it reached are told (SonarSurface.touch).
func hear(surfaces: Array[SonarSurface]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var finishing := is_done() or _alive_count == 0
	if not _pending.is_empty():
		var left: Array[Dictionary] = []
		for idx in _pending.size():
			var entry: Dictionary = _pending[idx]
			if not finishing and entry.d0 > _max_dist + LOOK_AHEAD:
				left.append_array(_pending.slice(idx))
				break
			var node := instance_from_id(entry.id)
			if node == null or not is_instance_valid(node):
				continue
			var p: Vector2 = node.sonar_point()
			if entry.depth < 0.0:
				entry.depth = _depth_inside(p, surfaces)
			var a := amp_at((p - origin).angle(), maxf(origin.distance_to(p) - entry.depth, 0.0))
			if a < 0.0:
				left.append(entry)
				continue
			if a >= FIND:
				out.append(entry)
		_pending = left
	if is_done():
		for entry in _far:
			var node := instance_from_id(entry.id)
			if node and is_instance_valid(node) and amp_toward(node.sonar_point()) >= FIND:
				out.append(entry)
		_far.clear()
	_touch_reactive(surfaces)
	return out

## How deep `p` is inside a solid surface (not one the ring started in), along the line from
## the origin: 0 out in the open. A listener in there hears the ring at the surface.
func _depth_inside(p: Vector2, surfaces: Array[SonarSurface]) -> float:
	for s in surfaces:
		if _ignore.has(s.get_instance_id()) or not s.get_sonar_material().is_solid():
			continue
		if p.distance_squared_to(s.center) > s.bound_radius * s.bound_radius:
			continue
		if s.contains(p):
			return p.distance_to(s.entry_point(origin, p))
	return 0.0

func _touch_reactive(surfaces: Array[SonarSurface]) -> void:
	for s in surfaces:
		if not s.get_sonar_material().reactive or s.sample_count() == 0:
			continue
		if origin.distance_to(s.center) - s.bound_radius > _max_dist + TOL:
			continue
		var sid := s.get_instance_id()
		var lit: PackedByteArray = _lit.get(sid, PackedByteArray())
		if lit.size() != s.sample_count():
			lit.resize(s.sample_count())
			lit.fill(0)
		var pts := s.global_samples()
		for i in pts.size():
			if lit[i] == 1:
				continue
			var a := amp_at_point(pts[i])
			if a < 0.0:
				continue
			lit[i] = 1
			if a >= SEE:
				s.touch(i, minf(a, 1.0), origin)
		_lit[sid] = lit

## Draw the ring as a polyline through the ray fronts, in global space, on `ci`.
func draw(ci: CanvasItem) -> void:
	var t := clampf(age / lifetime, 0.0, 1.0)
	var base := alpha * (1.0 - t)
	if base <= 0.001:
		return
	var dtheta := TAU / RAYS
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	# Start the walk at a break, if there is one, so each run is drawn whole
	var start := 0
	for i in RAYS:
		if not _segment_ok(i):
			start = (i + 1) % RAYS
			break
	for n in RAYS:
		var i := (start + n) % RAYS
		var j := (i + 1) % RAYS
		if not _segment_ok(i):
			_flush(ci, pts, cols)
			pts.clear()
			cols.clear()
			continue
		var ca := _front_color(i, base)
		var cb := _front_color(j, base)
		var chord := maxf(_dist[i], _dist[j]) * dtheta
		var pieces := clampi(ceili(chord / 6.0), 1, 8)
		if pts.is_empty():
			pts.append(origin + _dir[i] * _dist[i])
			cols.append(ca)
		for k in range(1, pieces + 1):
			var f := float(k) / pieces
			var ang := (i + f) * dtheta
			pts.append(origin + Vector2.from_angle(ang) * lerpf(_dist[i], _dist[j], f))
			cols.append(ca.lerp(cb, f))
	_flush(ci, pts, cols)

func _segment_ok(i: int) -> bool:
	var j := (i + 1) % RAYS
	if _dist[i] < 4.0 or _dist[j] < 4.0 or absf(_dist[i] - _dist[j]) > NEIGHBOUR_GAP:
		return false
	return (_amp[i] + _amp[j]) * 0.5 >= 0.02

func _front_color(i: int, base: float) -> Color:
	var c := color
	c.a = base * _amp[i] * (0.45 if _inside[i] == 1 else 1.0)
	return c

func _flush(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if pts.size() >= 2:
		ci.draw_polyline_colors(pts, cols, width, true)
