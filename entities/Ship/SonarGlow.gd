extends Node2D
class_name SonarGlow

## What a reactive SonarSurface shows of the Sweep rings that reach it (SonarSurface.touched).
## Each sample a ring touches glows white where it was touched, as bright as the ring was
## there, fading over GLOW_TIME; a line is drawn between neighbouring samples while both are
## lit, so only what the ring actually reached shows - never the whole outline.
##
## A discoverable surface answers too: FOUND_DELAY after a ring first touches it, a mustard
## trace runs both ways along the outline from that first sample, the heads reaching the far
## end (or meeting, round a closed outline) after TRACE_TIME, each sample fading after the head
## passes. Then `fill_polygons` (this node's space) glow faintly and fade, and the two-note
## FoundChime plays as the trace starts. One trace per ring; a later ring starts it again.
##
## A child of its surface (SonarGlow.on). Hide the surface and the glow goes with it.

## The touch glow: how long it lasts, how much brighter than the ring's amplitude it starts,
## the line, and the soft halo drawn under it.
const GLOW_TIME := 1.4
const LIT_GAIN := 1.2
const LINE_WIDTH := 2.2
const LINE_ALPHA := 0.95
const HALO_WIDTH := 7.0
const HALO_ALPHA := 0.2
## The found trace: how long after first contact it starts, how long it all lasts, how long
## the heads take to run the outline, how long a sample stays lit behind its head, and the
## fill once they are done.
const FOUND_DELAY := 0.22
const FOUND_LIFE := 1.6
const TRACE_TIME := 0.7
const TRACE_FADE := 0.9
const FILL_FADE := 0.6
const FILL_PEAK := 0.6
const FILL_ALPHA := 0.18
## Rings remembered as having started a trace (ids); older ones are dropped.
const RINGS_KEPT := 8
## A sample never touched (far enough back that it has long gone dark).
const NEVER := -1.0e9

## Filled briefly as the found trace closes, in this node's space.
var fill_polygons: Array[PackedVector2Array] = []
## How many found traces have been started (one per ring that reached it).
var traces := 0

var _surface: SonarSurface
var _t := 0.0
## Per sample: when it was last touched (_t) and how bright it started.
var _lit_at := PackedFloat32Array()
var _lit_a := PackedFloat32Array()
var _prev := PackedInt32Array()
var _rings: Array[int] = []
## The found trace: when it starts (_t), each sample's distance along the outline from
## where it began (-1: not on that line), and the furthest of them.
var _trace_at := -INF
## The ring the trace answers, and how far from where it was sent the trace begins.
var _trace_ring := 0
var _trace_from_d := INF
var _trace_off := PackedInt32Array()
var _trace_span := 1
var _chime_due := false
var _chime: FoundChime
## Whether anything was drawn last frame, so the frame after it goes dark is drawn too.
var _showing := false

## A glow for `surface`, added under it.
static func on(surface: SonarSurface) -> SonarGlow:
	var glow := SonarGlow.new()
	glow.name = "SonarGlow"
	surface.add_child(glow)
	glow._surface = surface
	surface.touched.connect(glow._on_touched)
	return glow

func _ready() -> void:
	_chime = FoundChime.new()
	_chime.name = "FoundChime"
	add_child(_chime)

## Forget every touch and trace (the Mount was seated).
func clear() -> void:
	_lit_at.fill(NEVER)
	_trace_at = -INF
	_chime_due = false
	_rings.clear()
	queue_redraw()

## Whether any sample is glowing white right now.
func is_lit() -> bool:
	for at in _lit_at:
		if _t - at < GLOW_TIME:
			return true
	return false

## Whether a found trace is waiting to start or running.
func is_tracing() -> bool:
	return _t - _trace_at <= FOUND_LIFE

func _process(delta: float) -> void:
	_t += delta
	if _chime_due and _t >= _trace_at:
		_chime_due = false
		_chime.chime()
	var live := is_lit() or is_tracing()
	if live or _showing:
		queue_redraw()
	_showing = live

func _on_touched(i: int, amplitude: float, origin: Vector2, ring: int) -> void:
	_fit()
	if i < 0 or i >= _lit_at.size():
		return
	_lit_at[i] = _t
	_lit_a[i] = minf(1.0, amplitude * LIT_GAIN)
	if not _surface.get_sonar_material().discoverable:
		return
	var d := origin.distance_to(_surface.global_samples()[i])
	if _rings.has(ring):
		# A ring touches many samples in one frame: until the trace shows, it begins at the
		# one nearest where the ring was sent - where it really touched first
		if ring == _trace_ring and _t < _trace_at and d < _trace_from_d:
			_trace_from_d = d
			_trace_offsets(i)
		return
	_rings.append(ring)
	if _rings.size() > RINGS_KEPT:
		_rings.pop_front()
	_trace_ring = ring
	_trace_from_d = d
	_start_trace(i)

## Keep the per-sample arrays the size of the outline (it can be re-cut).
func _fit() -> void:
	var n := _surface.sample_count()
	if _lit_at.size() == n:
		return
	_lit_at.resize(n)
	_lit_at.fill(NEVER)
	_lit_a.resize(n)
	_lit_a.fill(0.0)
	_prev.resize(n)
	_prev.fill(-1)
	for k in n:
		var j := _surface.next_sample(k)
		if j >= 0:
			_prev[j] = k
	_trace_at = -INF

## FOUND_DELAY from now, a trace from sample `from` (_trace_offsets: how far along the
## outline each sample is from it, both ways).
func _start_trace(from: int) -> void:
	traces += 1
	_trace_at = _t + FOUND_DELAY
	_chime_due = true
	_trace_offsets(from)

func _trace_offsets(from: int) -> void:
	var n := _lit_at.size()
	_trace_off.resize(n)
	_trace_off.fill(-1)
	_trace_off[from] = 0
	_trace_span = 1
	for way in 2:
		var k := from
		var steps := 0
		while true:
			k = _surface.next_sample(k) if way == 0 else _prev[k]
			steps += 1
			if k < 0 or k == from:
				break
			if _trace_off[k] < 0 or steps < _trace_off[k]:
				_trace_off[k] = steps
	for off in _trace_off:
		_trace_span = maxi(_trace_span, off)
	queue_redraw()

func _draw() -> void:
	if _surface == null or _lit_at.is_empty():
		return
	var t := _t - _trace_at
	if t >= TRACE_TIME and t <= FOUND_LIFE:
		var a := maxf(0.0, 1.0 - (t - TRACE_TIME) / FILL_FADE) * FILL_PEAK
		if a > 0.0:
			for poly in fill_polygons:
				draw_colored_polygon(poly, Color(Colors.PRIMARY, FILL_ALPHA * a))
	_surface.refresh()
	var pts := _surface.global_samples()
	if pts.size() != _lit_at.size():
		return
	# Samples are in the world; draw them there, whatever the surface has done since
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for i in pts.size():
		var j := _surface.next_sample(i)
		if j < 0:
			continue
		var a := minf(_touch_alpha(i), _touch_alpha(j))
		if a > 0.01:
			_line(pts[i], pts[j], Color.WHITE, a)
	if t >= 0.0 and t <= FOUND_LIFE:
		var head := t / TRACE_TIME * _trace_span
		for k in pts.size():
			var off := _trace_off[k]
			var j := _surface.next_sample(k)
			if off < 0 or j < 0 or off > head:
				continue
			var age := (head - off) / _trace_span * TRACE_TIME
			var a := maxf(0.0, 1.0 - age / TRACE_FADE) * (1.0 - t / FOUND_LIFE * 0.5)
			if a > 0.02:
				_line(pts[k], pts[j], Colors.PRIMARY, a)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _touch_alpha(i: int) -> float:
	return (1.0 - (_t - _lit_at[i]) / GLOW_TIME) * _lit_a[i]

## A bright line with a soft halo under it.
func _line(from: Vector2, to: Vector2, color: Color, a: float) -> void:
	draw_line(from, to, Color(color, HALO_ALPHA * a), HALO_WIDTH, true)
	draw_line(from, to, Color(color, LINE_ALPHA * a), LINE_WIDTH, true)
