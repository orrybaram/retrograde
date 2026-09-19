extends "res://dev/gate_styles/GateStyle.gd"
## E. SLAB — four boulders, joined by machinery.
##
## The mass is all rock: four irregular blocks big enough that dragging one anywhere
## is an event. What holds them apart is not: each gap is spanned by a machined strut
## with an indicator on it, clamped into the stone on both sides. Primitive material,
## advanced joinery, and the seam between the two is the whole idea.

const BLOCKS := 4
const WIDTH := 50.0

var _blocks: Array[PackedVector2Array] = []
var _gaps: PackedFloat32Array = PackedFloat32Array()
var _grain: Array[PackedVector2Array] = []

func _init() -> void:
	id = "slab"
	title = "SLAB"
	blurb = "four boulders, machined struts clamped between them"
	var r := seeded("slab")
	_build(r)

func _build(r: RandomNumberGenerator) -> void:
	var seg := span() / BLOCKS
	var gap := deg_to_rad(7.0)
	for i in BLOCKS:
		var from := start() + seg * i
		var to := from + seg - gap
		_gaps.append(to)
		var pts := PackedVector2Array()
		# Four corners a side, each thrown well off the circle and then joined with
		# straight runs: the block comes out faceted, like something split off a cliff
		# rather than ground down to a curve.
		var steps := 4
		for s in steps + 1:
			var t := float(s) / steps
			var a: float = lerpf(from, to, t)
			pts.append(polar(a, RADIUS + WIDTH / 2.0 + r.randf_range(-11.0, 7.0)))
		for s in range(steps, -1, -1):
			var t := float(s) / steps
			var a: float = lerpf(from, to, t)
			pts.append(polar(a, RADIUS - WIDTH / 2.0 + r.randf_range(-7.0, 11.0)))
		_blocks.append(pts)
		# Bedding planes across the face. They follow the block round rather than
		# cutting straight across it, so they read as layers in the rock.
		var lines := PackedVector2Array()
		for l in r.randi_range(2, 4):
			var rr := RADIUS + r.randf_range(-WIDTH / 2.0 + 7.0, WIDTH / 2.0 - 7.0)
			var drift := r.randf_range(-5.0, 5.0)
			var plane := PackedVector2Array()
			for s in 5:
				var t := float(s) / 4.0
				plane.append(polar(lerpf(from + 0.03, to - 0.03, t), rr + drift * t))
			for s in 4:
				lines.append(plane[s])
				lines.append(plane[s + 1])
		_grain.append(lines)

func draw_gate(c: CanvasItem, glow: float, clock: float) -> void:
	var stone := stone_of(glow)
	var hull := hull_of(glow)
	var lit := signal_of(glow)
	var pulse := 0.65 + 0.35 * sin(clock * 2.1)

	for i in BLOCKS:
		var block: PackedVector2Array = _blocks[i]
		c.draw_colored_polygon(block, stone)
		c.draw_polyline(block, stone.darkened(0.55), 2.4, true)
		var lines: PackedVector2Array = _grain[i]
		var j := 0
		while j + 1 < lines.size():
			c.draw_line(lines[j], lines[j + 1], stone.darkened(0.3), 1.6)
			j += 2

	# The struts. Machined, square-ended, bolted into rock that was never cut for it.
	for i in BLOCKS:
		var a: float = _gaps[i]
		var b := a + deg_to_rad(7.0)
		if i == BLOCKS - 1:
			continue
		_draw_strut(c, a, b, hull, lit, glow, pulse)

	draw_halo(c, glow, RADIUS + WIDTH / 2.0)
	_draw_clamp_cradle(c, hull, stone, lit, glow)
	draw_blinker(c, glow, clock, polar(-PI / 2.0, RADIUS))

## A strut bridging one gap: a plate across the rock faces with a lit core.
func _draw_strut(c: CanvasItem, a: float, b: float, hull: Color, lit: Color,
		glow: float, pulse: float) -> void:
	var mid := (a + b) / 2.0
	for rr in [RADIUS - 13.0, RADIUS + 13.0]:
		c.draw_line(polar(a - 0.04, rr), polar(b + 0.04, rr), hull, 7.0)
		c.draw_line(polar(a - 0.04, rr), polar(b + 0.04, rr), hull.darkened(0.45), 2.0)
	# Clamps biting into the stone on either side.
	for edge in [a - 0.03, b + 0.03]:
		c.draw_line(polar(edge, RADIUS - 18.0), polar(edge, RADIUS + 18.0), hull.darkened(0.3), 5.0)
	# The core between the plates: dark and dead, or carrying the Module's current.
	c.draw_line(polar(a, RADIUS), polar(b, RADIUS), Colors.SPACE_BG, 10.0)
	c.draw_line(polar(a, RADIUS), polar(b, RADIUS), Color(lit, (0.08 + glow * 0.8) * pulse), 6.0)
	c.draw_circle(polar(mid, RADIUS), 3.0, Color(lit, 0.3 + glow * 0.7))
	if glow > 0.0:
		c.draw_circle(polar(mid, RADIUS), 9.0, Color(Colors.TITAN, glow * 0.16 * pulse))

## The cradle is one more strut, the longest of them, spanning the mouth.
func _draw_clamp_cradle(c: CanvasItem, hull: Color, stone: Color, lit: Color, glow: float) -> void:
	var left := Vector2(-CRADLE_HALF, RADIUS)
	var right := Vector2(CRADLE_HALF, RADIUS)
	c.draw_line(left, right, Colors.SPACE_BG, 14.0)
	c.draw_line(left, right, hull, 11.0)
	c.draw_line(left + Vector2(0, -5), right + Vector2(0, -5), Color(lit, 0.12 + glow * 0.7), 2.0)
	for x in [-CRADLE_HALF, CRADLE_HALF]:
		c.draw_line(Vector2(x, RADIUS - 12), Vector2(x, RADIUS + 12), hull.darkened(0.3), 6.0)
		var foot := PackedVector2Array([
			Vector2(x - 6, RADIUS + 8), Vector2(x + 6, RADIUS + 9),
			Vector2(x * 1.3 + 7, RADIUS + 24), Vector2(x * 1.3 - 7, RADIUS + 23),
		])
		c.draw_colored_polygon(foot, stone.darkened(0.25))
