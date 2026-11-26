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
## Every frame amplitude spreads sideways between neighbouring open rays (a cheap stand-in
## for diffraction: D = WAVELENGTH / 2pi per px the front moves), so the ring fades into a
## shadow instead of snapping, shadow edges blur, and shadows fill back in with distance:
## short behind small things, long behind big ones. What the ray had is written down every
## CELL px (`_hist`), so a listener is heard where the ring's amplitude at its point clears
## FIND, at the moment the ring passes it. Echoing solids throw a faint reflected arc back.
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
## The note's wavelength, px: how far round an edge the ring bends.
const WAVELENGTH := 45.0
## Rays closer in than this don't spread (the front is too tight to resolve it).
const DIFFUSE_FROM := 40.0
const MAX_SUBSTEPS := 30
const SUBSTEP_RATE := 0.4
const MAX_RATE := 0.45
## A reflected arc: what share of the hit it carries, how far it goes, the least hit that
## throws one.
const BOUNCE_KEEP := 0.6
const BOUNCE_REACH := 160.0
const BOUNCE_MIN := 0.05
const BOUNCE_ALPHA := 0.5
const BOUNCE_COLOR := Colors.CREAM

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
var _cand_echo := PackedByteArray()
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
## Diffusion scratch: per-ray rate, the two amplitude buffers, which neighbours count, and
## which rays can change this frame.
var _k := PackedFloat32Array()
var _a := PackedFloat32Array()
var _b := PackedFloat32Array()
var _left_open := PackedByteArray()
var _right_open := PackedByteArray()
var _active := PackedByteArray()
## Reflected points: where, which way, how strong, how far they have gone, which ray threw them.
var _bounce_at := PackedVector2Array()
var _bounce_dir := PackedVector2Array()
var _bounce_amp := PackedFloat32Array()
var _bounce_went := PackedFloat32Array()
var _bounce_ray := PackedInt32Array()

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
	_k.resize(RAYS)
	_a.resize(RAYS)
	_b.resize(RAYS)
	_left_open.resize(RAYS)
	_right_open.resize(RAYS)
	_active.resize(RAYS)
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
	var d_e := big_e - _prev_e
	_prev_e = big_e
	_diffuse(d_e)
	_move_bounces(d_e)

## Surfaces that could be met between the closest live ray and the front, and which rays
## each could be met by (its angular span from the origin).
func _gather(surfaces: Array[SonarSurface], big_e: float) -> void:
	_cand.clear()
	_cand_id.clear()
	_cand_c.clear()
	_cand_r2.clear()
	_cand_cost.clear()
	_cand_solid.clear()
	_cand_echo.clear()
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
		_cand_echo.append(1 if m.echo else 0)
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

## Ray `i`, with amplitude `amp_there`, met candidate `k`'s solid face at `at`: an echoing
## face throws a reflected point back, mirrored about the face.
func _on_hit(i: int, k: int, at: Vector2, amp_there: float) -> void:
	if _cand_echo[k] == 0 or amp_there <= BOUNCE_MIN:
		return
	var n := _cand[k].normal_at(at, origin)
	var d := _dir[i]
	_bounce_at.append(at)
	_bounce_dir.append(d - 2.0 * d.dot(n) * n)
	_bounce_amp.append(amp_there * BOUNCE_KEEP)
	_bounce_went.append(0.0)
	_bounce_ray.append(i)

## Reflected points ride out at the front's pace and fade over BOUNCE_REACH.
func _move_bounces(d_e: float) -> void:
	if _bounce_at.is_empty():
		return
	var keep := 0
	for j in _bounce_at.size():
		var went := _bounce_went[j] + d_e
		if went >= BOUNCE_REACH:
			continue
		_bounce_at[keep] = _bounce_at[j] + _bounce_dir[j] * d_e
		_bounce_dir[keep] = _bounce_dir[j]
		_bounce_amp[keep] = _bounce_amp[j]
		_bounce_went[keep] = went
		_bounce_ray[keep] = _bounce_ray[j]
		keep += 1
	_bounce_at.resize(keep)
	_bounce_dir.resize(keep)
	_bounce_amp.resize(keep)
	_bounce_went.resize(keep)
	_bounce_ray.resize(keep)

func bounce_count() -> int:
	return _bounce_at.size()

## Spread amplitude sideways between neighbouring open rays, for a front that moved `d_e`.
## A ray's rate is D * d_e / (its spacing)^2, taken in substeps that stay stable. A neighbour
## inside a solid, or too far off along its ray, counts as the ray's own value (no flow).
## Only rays within reach of an amplitude step can change, so only those are worked.
func _diffuse(d_e: float) -> void:
	if d_e <= 0.0:
		return
	var dtheta := TAU / RAYS
	var diffusion := WAVELENGTH / TAU
	var k_max := 0.0
	var lo := INF
	var hi := -INF
	for i in RAYS:
		var k := 0.0
		if _solid[i] == 0:
			var a := _amp[i]
			lo = minf(lo, a)
			hi = maxf(hi, a)
			var d := _dist[i]
			if d >= DIFFUSE_FROM:
				var spacing := d * dtheta
				k = diffusion * d_e / (spacing * spacing)
		_k[i] = k
		k_max = maxf(k_max, k)
	if k_max <= 0.0 or hi - lo < 1e-4:
		return
	var n := mini(MAX_SUBSTEPS, maxi(1, ceili(k_max / SUBSTEP_RATE)))
	_active.fill(0)
	var any := false
	for i in RAYS:
		var l := (i + RAYS - 1) % RAYS
		var r := (i + 1) % RAYS
		_left_open[i] = 1 if _solid[l] == 0 and absf(_dist[l] - _dist[i]) < NEIGHBOUR_GAP else 0
		_right_open[i] = 1 if _solid[r] == 0 and absf(_dist[r] - _dist[i]) < NEIGHBOUR_GAP else 0
		_k[i] = minf(MAX_RATE, _k[i] / n)
		_a[i] = _amp[i]
		_b[i] = _amp[i]
	for i in RAYS:
		var step_here := (_left_open[i] == 1 and absf(_amp[(i + RAYS - 1) % RAYS] - _amp[i]) > 1e-4) \
			or (_right_open[i] == 1 and absf(_amp[(i + 1) % RAYS] - _amp[i]) > 1e-4)
		if step_here:
			any = true
			for j in range(i - n, i + n + 1):
				_active[posmod(j, RAYS)] = 1
	if not any:
		return
	var work := PackedInt32Array()
	for i in RAYS:
		if _active[i] == 1 and _k[i] > 0.0:
			work.append(i)
	for it in n:
		for i in work:
			var ai := _a[i]
			var al := _a[(i + RAYS - 1) % RAYS] if _left_open[i] == 1 else ai
			var ar := _a[(i + 1) % RAYS] if _right_open[i] == 1 else ai
			_b[i] = ai + _k[i] * (al + ar - 2.0 * ai)
		for i in work:
			_a[i] = _b[i]
	for i in work:
		if _solid[i] == 0:
			_amp[i] = clampf(_a[i], 0.0, 1.0)

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
## A ray that ran out inside rock never came out the far side, so it carries nothing: a far
## listener behind thick rock goes quiet as it would behind a solid.
func amp_toward(p: Vector2) -> float:
	var f := posmod((p - origin).angle(), TAU) / TAU * RAYS
	var i0 := int(f) % RAYS
	var i1 := (i0 + 1) % RAYS
	return lerpf(_carried(i0), _carried(i1), f - floorf(f))

func _carried(i: int) -> float:
	return 0.0 if _inside[i] == 1 else _amp[i]

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
		var pts := s.global_samples()
		if lit.size() != s.sample_count():
			# New outline (e.g. a Mount re-cut the hull mid-ring): what the ring has already
			# passed counts as decided, so nothing it touched is touched twice.
			var fresh := lit.is_empty()
			lit.resize(s.sample_count())
			for i in pts.size():
				lit[i] = 0 if fresh or origin.distance_to(pts[i]) > _min_dist - TOL else 1
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
		# Today's ring was at most 512 points round: a couple per ray on a big one
		var pieces := clampi(ceili(chord / 16.0), 1, 3)
		if pts.is_empty():
			pts.append(origin + _dir[i] * _dist[i])
			cols.append(ca)
		for k in range(1, pieces + 1):
			var f := float(k) / pieces
			var ang := (i + f) * dtheta
			pts.append(origin + Vector2.from_angle(ang) * lerpf(_dist[i], _dist[j], f))
			cols.append(ca.lerp(cb, f))
	_flush(ci, pts, cols)
	_draw_bounces(ci, base)

## Reflected arcs: joined where they came off neighbouring rays, faint, cream.
func _draw_bounces(ci: CanvasItem, base: float) -> void:
	var count := _bounce_at.size()
	for j in count:
		var c := BOUNCE_COLOR
		c.a = BOUNCE_ALPHA * base * _bounce_amp[j] * (1.0 - _bounce_went[j] / BOUNCE_REACH)
		if c.a <= 0.002:
			continue
		var at := _bounce_at[j]
		if j + 1 < count and _bounce_ray[j + 1] == _bounce_ray[j] + 1 \
				and at.distance_to(_bounce_at[j + 1]) < NEIGHBOUR_GAP:
			ci.draw_line(at, _bounce_at[j + 1], c, width, true)
		else:
			ci.draw_rect(Rect2(at - Vector2.ONE, Vector2(2, 2)), c)

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
