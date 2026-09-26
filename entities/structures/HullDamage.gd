extends Node2D
class_name HullDamage

## Wear and damage across SR-7's hull, so the station reads as old and knocked about, not
## just missing pieces: soot and scorching, punctures with torn rims, dents, gouges, plates
## gone to show the truss behind them, loose plates hanging off the outer edges and swaying
## on what is left of their fixings, and a few chunks of it tumbling slowly round the
## station. None of it is ever repaired - the core's cold start brings the lights back, not
## the paint.
##
## It is laid over the station's own polygons (`visuals`), so every mark sits on real hull,
## and scattered from a fixed seed with its own RandomNumberGenerator: the same damage every
## run, and never a draw from the shared one. The Sections (the clean, machined pieces the
## player fits) and the core's bay are left alone.

@export var visuals: NodePath
## How many marks across the whole hull.
@export var marks := 110
@export var damage_seed := 347

## Parts that stay clean: the Sections, and the core's bay.
const SKIP: Array[String] = ["FuelTank", "SolarArray", "DorsalArm", "CentralCore", "FinPlate"]
## Marks are only ever this big, px, and never on a part too thin to hold one.
const SIZE := Vector2(2.5, 9.0)
const MIN_PART_AREA := 400.0
## How many tries to fit a mark on a part before giving up on it.
const TRIES := 14

enum Kind { SOOT, PUNCTURE, DENT, GOUGE, STRIPPED }
## How often each kind comes up.
const WEIGHTS := {Kind.SOOT: 5, Kind.PUNCTURE: 3, Kind.DENT: 4, Kind.GOUGE: 4, Kind.STRIPPED: 2}

## Loose plates hanging off outer edges.
const FLAPS := 7
const FLAP_SIZE := Vector2(10.0, 20.0)
const FLAP_SWAY := 0.35
## Chunks tumbling round the station: how many, and how far out.
const CHUNKS := 14
const CHUNK_ORBIT := Vector2(470.0, 760.0)

var _rng := RandomNumberGenerator.new()
var _marks: Array[Dictionary] = []
var _flaps: Array[Dictionary] = []
var _chunks: Array[Dictionary] = []
var _clock := 0.0

func _ready() -> void:
	z_index = 1  # with the hull, under the windows
	_rng.seed = damage_seed
	var parts := _parts()
	_scatter_marks(parts)
	_hang_flaps(parts)
	_loose_chunks()

## The hull polygons that take damage, each {poly (station space), area}.
func _parts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var root := get_node_or_null(visuals)
	if root == null:
		return out
	for child in root.get_children():
		var p := child as Polygon2D
		if p == null or p.polygon.size() < 3 or SKIP.has(str(p.name)):
			continue
		var poly: PackedVector2Array = (root as Node2D).transform * p.transform * p.polygon
		var area := absf(_area(poly))
		if area >= MIN_PART_AREA:
			out.append({"poly": poly, "area": area})
	return out

## Every mark placed, for tests.
func mark_list() -> Array[Dictionary]:
	return _marks

func flap_list() -> Array[Dictionary]:
	return _flaps

# --- Scatter ---------------------------------------------------------------------

func _scatter_marks(parts: Array[Dictionary]) -> void:
	var total := 0.0
	for p in parts:
		total += p["area"]
	if total <= 0.0:
		return
	for i in marks:
		var part := _pick_part(parts, total)
		var kind := _pick_kind()
		var size := _rng.randf_range(SIZE.x, SIZE.y)
		if kind == Kind.SOOT:
			size *= 1.8
		# a burn streak reaches well past its centre
		var at = _fit(part["poly"], size * (1.6 if kind == Kind.SOOT else 1.0))
		if at == null:
			continue
		_marks.append(_make_mark(kind, at, size))

func _pick_part(parts: Array[Dictionary], total: float) -> Dictionary:
	var roll := _rng.randf() * total
	for p in parts:
		roll -= p["area"]
		if roll <= 0.0:
			return p
	return parts[-1]

func _pick_kind() -> Kind:
	var sum := 0
	for w in WEIGHTS.values():
		sum += w
	var roll := _rng.randi_range(1, sum)
	for k in WEIGHTS:
		roll -= WEIGHTS[k]
		if roll <= 0:
			return k
	return Kind.SOOT

## A point in `poly` with a clear circle of `size` round it, or null.
func _fit(poly: PackedVector2Array, size: float) -> Variant:
	var box := _bounds(poly)
	for t in TRIES:
		var p := Vector2(_rng.randf_range(box.position.x, box.end.x), _rng.randf_range(box.position.y, box.end.y))
		if _clear(poly, p, size):
			return p
	return null

static func _clear(poly: PackedVector2Array, p: Vector2, r: float) -> bool:
	if not Geometry2D.is_point_in_polygon(p, poly):
		return false
	for i in 8:
		if not Geometry2D.is_point_in_polygon(p + Vector2.from_angle(TAU * i / 8.0) * r, poly):
			return false
	return true

func _make_mark(kind: Kind, at: Vector2, size: float) -> Dictionary:
	var m := {"kind": kind, "at": at, "size": size, "turn": _rng.randf() * TAU}
	match kind:
		Kind.SOOT:
			# a burn streak: blobs strung out along one direction, thinning toward the tail
			var blobs: Array[Vector3] = []
			var dir := Vector2.from_angle(m["turn"])
			var n := _rng.randi_range(4, 8)
			for b in n:
				var f := float(b) / n
				var o := dir * (f - 0.3) * size * 1.4 + dir.orthogonal() * _rng.randf_range(-0.2, 0.2) * size
				blobs.append(Vector3(o.x, o.y, lerpf(0.7, 0.25, f) * size * _rng.randf_range(0.8, 1.1)))
			m["blobs"] = blobs
		Kind.PUNCTURE:
			m["hole"] = _ragged(at, size * 0.45, 9)
		Kind.DENT:
			m["shape"] = _ragged(at, size * 0.6, 6)
		Kind.GOUGE:
			var lines: Array[Vector2] = []
			for l in _rng.randi_range(1, 3):
				lines.append(Vector2(_rng.randf_range(-0.3, 0.3) * size, _rng.randf_range(0.7, 1.3) * size))
			m["lines"] = lines
		Kind.STRIPPED:
			m["hole"] = _ragged(at, size * 0.75, 10)
			m["ribs"] = _rng.randi_range(2, 3)
	return m

## A jagged ring of `n` points round `at`, about `r` out.
func _ragged(at: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var start := _rng.randf() * TAU
	for i in n:
		out.append(at + Vector2.from_angle(start + TAU * i / n) * r * _rng.randf_range(0.6, 1.25))
	return out

## Plates hanging off outer edges: an edge whose outside is open space, not more station.
func _hang_flaps(parts: Array[Dictionary]) -> void:
	var edges: Array[Dictionary] = []
	for p in parts:
		var poly: PackedVector2Array = p["poly"]
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			if a.distance_to(b) < FLAP_SIZE.x * 2.0:
				continue
			var mid := (a + b) * 0.5
			var out := (b - a).orthogonal().normalized()
			if Geometry2D.is_point_in_polygon(mid + out * 3.0, poly):
				out = -out
			if _inside_any(parts, mid + out * 5.0):
				continue
			edges.append({"a": a, "b": b, "out": out})
	for i in mini(FLAPS, edges.size()):
		var e: Dictionary = edges[_rng.randi_range(0, edges.size() - 1)]
		edges.erase(e)
		var hinge: Vector2 = e["a"].lerp(e["b"], _rng.randf_range(0.25, 0.75))
		_flaps.append({
			"hinge": hinge,
			"along": (e["b"] - e["a"]).normalized(),
			"out": e["out"],
			"w": _rng.randf_range(FLAP_SIZE.x, FLAP_SIZE.y),
			"h": _rng.randf_range(FLAP_SIZE.x, FLAP_SIZE.y),
			"hang": _rng.randf_range(0.4, 1.2),
			"phase": _rng.randf() * TAU,
			"period": _rng.randf_range(3.0, 6.0),
		})

static func _inside_any(parts: Array[Dictionary], p: Vector2) -> bool:
	for part in parts:
		if Geometry2D.is_point_in_polygon(p, part["poly"]):
			return true
	return false

func _loose_chunks() -> void:
	for i in CHUNKS:
		var pts := PackedVector2Array()
		var s := _rng.randf_range(2.0, 6.0)
		var n := _rng.randi_range(3, 5)
		for k in n:
			pts.append(Vector2.from_angle(TAU * k / n + _rng.randf_range(-0.3, 0.3)) * s * _rng.randf_range(0.6, 1.0))
		_chunks.append({
			"pts": pts,
			"r": _rng.randf_range(CHUNK_ORBIT.x, CHUNK_ORBIT.y),
			"a": _rng.randf() * TAU,
			"drift": _rng.randf_range(-0.012, 0.012),
			"spin": _rng.randf_range(-0.8, 0.8),
			"turn": _rng.randf() * TAU,
			"color": Colors.HULL_MID if i % 3 else Colors.HULL_LIGHT,
		})

# --- Motion and drawing ------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	for c in _chunks:
		c["a"] += c["drift"] * delta
		c["turn"] += c["spin"] * delta
	queue_redraw()

func _draw() -> void:
	for m in _marks:
		_draw_mark(m)
	for f in _flaps:
		_draw_flap(f)
	for c in _chunks:
		var xf := Transform2D(c["turn"], Vector2.from_angle(c["a"]) * c["r"])
		draw_set_transform_matrix(xf)
		draw_colored_polygon(c["pts"], c["color"])
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_mark(m: Dictionary) -> void:
	var at: Vector2 = m["at"]
	var size: float = m["size"]
	match m["kind"]:
		Kind.SOOT:
			for b in m["blobs"]:
				draw_circle(at + Vector2(b.x, b.y), b.z, Color(Colors.SPACE_BG, 0.16))
		Kind.PUNCTURE:
			var hole: PackedVector2Array = m["hole"]
			draw_circle(at, size * 0.9, Color(Colors.SPACE_BG, 0.2))
			draw_colored_polygon(hole, Colors.SPACE_BG)
			var rim := hole.duplicate()
			rim.append(hole[0])
			draw_polyline(rim, Colors.HULL_LIGHT, 1.0)
		Kind.DENT:
			var shape: PackedVector2Array = m["shape"]
			draw_colored_polygon(shape, Color(Colors.HULL_DARK, 0.7))
			# light catching the far lip of the dent
			var lip := PackedVector2Array([shape[0], shape[1], shape[2]])
			draw_polyline(lip, Color(Colors.HULL_LIGHT, 0.6), 1.0)
		Kind.GOUGE:
			var dir := Vector2.from_angle(m["turn"])
			var side := dir.orthogonal()
			for l in m["lines"]:
				var from: Vector2 = at + side * l.x - dir * l.y * 0.5
				var to: Vector2 = from + dir * l.y
				draw_line(from, to, Color(Colors.HULL_DARK, 0.9), 1.4)
				draw_line(from + side * 0.8, to + side * 0.8, Color(Colors.HULL_LIGHT, 0.5), 0.8)
		Kind.STRIPPED:
			# plating torn away, the ribs behind it showing through
			var hole: PackedVector2Array = m["hole"]
			draw_colored_polygon(hole, Colors.SPACE_BG)
			var ribs: int = m["ribs"]
			for i in ribs:
				var x := at.x + (float(i + 1) / (ribs + 1) - 0.5) * size * 1.2
				draw_line(Vector2(x, at.y - size * 0.7), Vector2(x, at.y + size * 0.7), Colors.HULL_MID, 1.4)
			draw_line(at + Vector2(-size * 0.7, 0), at + Vector2(size * 0.7, 0), Color(Colors.HULL_MID, 0.7), 1.0)
			var rim := hole.duplicate()
			rim.append(hole[0])
			draw_polyline(rim, Color(Colors.HULL_LIGHT, 0.8), 1.0)

## A plate hanging off its hinge, swaying a little, its free end tipped out into space.
func _draw_flap(f: Dictionary) -> void:
	var sway: float = sin(_clock * TAU / f["period"] + f["phase"]) * FLAP_SWAY
	var hang: float = f["hang"] + sway
	var along: Vector2 = f["along"]
	var down: Vector2 = f["out"].rotated(-hang * 0.3)
	var w: float = f["w"]
	var h: float = f["h"]
	var hinge: Vector2 = f["hinge"]
	# Seen side-on from above, a plate swung out shortens toward the hinge
	var reach := down * h * (0.5 + 0.5 * cos(hang))
	var pts := PackedVector2Array([hinge, hinge + along * w, hinge + along * w + reach, hinge + reach * 0.9])
	draw_colored_polygon(pts, Colors.HULL_MID)
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Colors.HULL_DARK, 1.0)
	draw_line(hinge + along * w + reach, hinge + reach * 0.9, Colors.HULL_LIGHT, 1.0)

static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
