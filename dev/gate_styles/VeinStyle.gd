extends "res://dev/gate_styles/GateStyle.gd"
## B. FRACTURE — one unbroken stone ring, lit from inside the cracks.
##
## No panels and no seams: a single rough band of rock, chipped along both edges, with
## a fault running through it. Dormant the veins are black hairlines. Powered, the
## light comes up out of the rock itself and the branches fill from the root outward,
## so the ring reads as something split open rather than switched on.

const WIDTH := 40.0
const BRANCHES := 9

var _outer := PackedVector2Array()
var _inner := PackedVector2Array()
var _veins: Array[PackedVector2Array] = []

func _init() -> void:
	id = "vein"
	title = "FRACTURE"
	blurb = "solid rock, lit from inside the cracks"
	var r := seeded("fracture")
	_build_band(r)
	_build_veins(r)

## The band: the outer and inner edges wander independently, on long swells rather
## than per-point noise, so the rock has no constant thickness and no sawtooth either.
func _build_band(r: RandomNumberGenerator) -> void:
	var steps := 128
	var out_wander := make_wander(r, 6.0)
	var in_wander := make_wander(r, 5.0)
	for i in steps + 1:
		var t := float(i) / steps
		var a := start() + span() * t
		_outer.append(polar(a, RADIUS + WIDTH / 2.0 + wander_at(out_wander, t)))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		var a := start() + span() * t
		_inner.append(polar(a, RADIUS - WIDTH / 2.0 + wander_at(in_wander, t)))

## A vein is a walk along the ring that wanders across the band and forks.
func _build_veins(r: RandomNumberGenerator) -> void:
	for b in BRANCHES:
		var a := start() + span() * (float(b) + r.randf_range(0.15, 0.85)) / BRANCHES
		var line := PackedVector2Array()
		var offset := r.randf_range(-6.0, 6.0)
		var length := r.randf_range(0.05, 0.16) * span()
		var sign_ := 1.0 if r.randf() < 0.5 else -1.0
		var steps := 7
		for i in steps + 1:
			var t := float(i) / steps
			offset += r.randf_range(-3.0, 3.0) + sign_ * 1.6
			offset = clampf(offset, -WIDTH / 2.0 + 3.0, WIDTH / 2.0 - 3.0)
			line.append(polar(a + length * t * sign_, RADIUS + offset))
		_veins.append(line)
		# A short spur off the middle of most veins.
		if r.randf() < 0.7:
			var at := line[steps / 2]
			var spur := PackedVector2Array([at])
			var dir := at.normalized() * (1.0 if r.randf() < 0.5 else -1.0)
			for i in 3:
				spur.append(spur[i] + dir * r.randf_range(3.0, 6.0)
					+ at.orthogonal().normalized() * r.randf_range(-4.0, 4.0))
			_veins.append(spur)

func draw_gate(c: CanvasItem, glow: float, clock: float) -> void:
	var stone := stone_of(glow)
	var band := PackedVector2Array(_outer)
	band.append_array(_inner)
	c.draw_colored_polygon(band, stone.darkened(0.15))
	# Edge chipping: the outline is drawn back over the fill a shade darker.
	c.draw_polyline(_outer, stone.darkened(0.5), 2.0)
	c.draw_polyline(_inner, stone.darkened(0.5), 2.0)
	# Weathering across the face.
	c.draw_arc(Vector2.ZERO, RADIUS + WIDTH * 0.22, start(), start() + span(), 96,
		stone.lightened(0.08), 5.0, true)

	# The fault. It carries a slow pulse once powered, so the light looks like it is
	# coming from somewhere deeper rather than painted on.
	var pulse := 0.75 + 0.25 * sin(clock * 1.7)
	var lit := signal_of(glow)
	for line in _veins:
		c.draw_polyline(line, Colors.SPACE_BG.darkened(0.3), 3.0)
		if glow > 0.0:
			c.draw_polyline(line, Color(lit, glow * 0.25 * pulse), 6.0)
			c.draw_polyline(line, Color(lit, glow * 0.9), 1.6)
		else:
			# Dormant, one ember still sits in the rock.
			c.draw_polyline(line, Color(Colors.PRIMARY, 0.07), 1.2)

	draw_halo(c, glow, RADIUS + WIDTH / 2.0)
	_draw_stone_cradle(c, stone, lit, glow)
	draw_blinker(c, glow, clock, polar(-PI / 2.0, RADIUS))

## A slab of the same rock wedged across the mouth, with the fault running under it.
func _draw_stone_cradle(c: CanvasItem, stone: Color, lit: Color, glow: float) -> void:
	var slab := PackedVector2Array([
		Vector2(-CRADLE_HALF - 4, RADIUS - 7), Vector2(CRADLE_HALF + 2, RADIUS - 6),
		Vector2(CRADLE_HALF + 6, RADIUS + 7), Vector2(-CRADLE_HALF - 7, RADIUS + 6),
	])
	c.draw_colored_polygon(slab, stone.darkened(0.2))
	c.draw_polyline(slab, stone.darkened(0.5), 2.0, true)
	c.draw_line(Vector2(-CRADLE_HALF, RADIUS - 2), Vector2(CRADLE_HALF, RADIUS - 3),
		Color(lit, 0.1 + glow * 0.8), 1.5)
	for x in [-CRADLE_HALF, CRADLE_HALF]:
		var leg := PackedVector2Array([
			Vector2(x - 4, RADIUS + 4), Vector2(x + 4, RADIUS + 4),
			Vector2(x * 1.35 + 5, RADIUS + 22), Vector2(x * 1.35 - 5, RADIUS + 22),
		])
		c.draw_colored_polygon(leg, stone.darkened(0.3))
