extends "res://dev/gate_styles/GateStyle.gd"
## A. BULWARK — the Gate as it is now, built heavy.
##
## Same seven machined segments, but twice the bezel: a deep outer shadow band, a
## chamfered inner lip catching the light, and a capped end on every segment so the
## ring reads as plate stacked on plate rather than a drawn line. The recessed channel
## behind the gaps is where the Module's light comes through.

const SEGMENTS := 7
const WIDTH := 30.0

func _init() -> void:
	id = "bezel"
	title = "BULWARK"
	blurb = "the current ring, twice the bezel"

func draw_gate(c: CanvasItem, glow: float, clock: float) -> void:
	var hull := hull_of(glow)
	var rim := rim_of(glow)
	var seg := span() / SEGMENTS
	var gap := deg_to_rad(4.0)

	# The recessed channel behind the segments: dark while dormant, the light source
	# once the Module is online.
	c.draw_arc(Vector2.ZERO, RADIUS, start(), start() + span(), 96,
		Colors.SPACE_BG.lerp(Colors.TITAN, glow * 0.75), WIDTH - 9.0, true)

	for i in SEGMENTS:
		var from := start() + seg * i
		var to := from + seg - gap
		# Body, then the shadow it throws outward and the chamfer that catches light in.
		c.draw_arc(Vector2.ZERO, RADIUS, from, to, 32, hull, WIDTH, true)
		c.draw_arc(Vector2.ZERO, RADIUS + WIDTH / 2.0 - 2.5, from, to, 32,
			hull.darkened(0.45), 5.0, true)
		c.draw_arc(Vector2.ZERO, RADIUS - WIDTH / 2.0 + 2.0, from, to, 32, rim, 3.0, true)
		# Capped ends: the plate has a thickness you can see into.
		for a in [from, to]:
			c.draw_line(polar(a, RADIUS - WIDTH / 2.0), polar(a, RADIUS + WIDTH / 2.0),
				hull.darkened(0.55), 3.0)
		# Two bolt rows down the middle of every plate.
		var mid := (from + to) / 2.0
		for d in [-seg * 0.22, seg * 0.22]:
			for rr in [RADIUS - 8.0, RADIUS + 8.0]:
				c.draw_circle(polar(mid + d, rr), 1.6, hull.darkened(0.5))

	draw_halo(c, glow, RADIUS + WIDTH / 2.0)
	if glow > 0.0:
		c.draw_arc(Vector2.ZERO, RADIUS - WIDTH / 2.0, start(), start() + span(), 96,
			Color(Colors.TITAN, glow * 0.65), 2.0, true)
	_draw_heavy_cradle(c, hull, rim)
	draw_blinker(c, glow, clock)

## The cradle gets the same treatment: a thick bar with a lip, on braced legs.
func _draw_heavy_cradle(c: CanvasItem, hull: Color, rim: Color) -> void:
	var left := Vector2(-CRADLE_HALF, RADIUS)
	var right := Vector2(CRADLE_HALF, RADIUS)
	c.draw_line(left, right, hull, 13.0)
	c.draw_line(left + Vector2(0, -6), right + Vector2(0, -6), rim, 2.0)
	c.draw_line(left + Vector2(0, 6), right + Vector2(0, 6), hull.darkened(0.45), 3.0)
	for x in [-CRADLE_HALF + 7.0, CRADLE_HALF - 7.0]:
		c.draw_line(Vector2(x, RADIUS + 4), Vector2(x * 1.3, RADIUS + 20.0), hull, 7.0)
