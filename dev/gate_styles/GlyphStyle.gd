extends "res://dev/gate_styles/GateStyle.gd"
## C. SCRIPT — a chunky bezel with something written on it.
##
## The hull is machined and heavy, but the inner face is covered edge to edge in a
## carved script nobody has read in a long time. Dormant it is just tooling marks.
## Powered, the writing lights a character at a time, a pulse running the whole ring
## like a line being read aloud.

const SEGMENTS := 5
const WIDTH := 32.0
const GLYPHS := 44

## One glyph: a stem with branches, drawn in a box roughly 8 x 12 and then placed
## flat against the ring.
var _glyphs: Array[Array] = []

func _init() -> void:
	id = "glyph"
	title = "SCRIPT"
	blurb = "heavy bezel, alien writing that lights a word at a time"
	var r := seeded("script")
	for i in GLYPHS:
		_glyphs.append(make_rune(r, r.randf_range(7.0, 11.0)))

func draw_gate(c: CanvasItem, glow: float, clock: float) -> void:
	var hull := hull_of(glow)
	var rim := rim_of(glow)
	var seg := span() / SEGMENTS
	var gap := deg_to_rad(3.0)

	for i in SEGMENTS:
		var from := start() + seg * i
		var to := from + seg - gap
		c.draw_arc(Vector2.ZERO, RADIUS + 5.0, from, to, 40, hull, WIDTH - 10.0, true)
		c.draw_arc(Vector2.ZERO, RADIUS + WIDTH / 2.0 + 2.0, from, to, 40,
			hull.darkened(0.45), 6.0, true)
		# The written face is recessed: a darker band the glyphs sit in.
		c.draw_arc(Vector2.ZERO, RADIUS - WIDTH / 2.0 + 5.0, from, to, 40,
			hull.darkened(0.3), 13.0, true)
		c.draw_arc(Vector2.ZERO, RADIUS - WIDTH / 2.0 + 12.0, from, to, 40, rim, 1.5, true)
		for a in [from, to]:
			c.draw_line(polar(a, RADIUS - WIDTH / 2.0), polar(a, RADIUS + WIDTH / 2.0 + 4.0),
				hull.darkened(0.55), 3.5)

	_draw_script(c, glow, clock)
	draw_halo(c, glow, RADIUS + WIDTH / 2.0 + 4.0)
	draw_cradle(c, glow)
	draw_blinker(c, glow, clock, polar(-PI / 2.0, RADIUS + WIDTH / 2.0 + 10.0))

## The reading head: a bright band travelling the ring, with the characters behind it
## fading back down. Dormant, none of this runs and the carving is barely there.
func _draw_script(c: CanvasItem, glow: float, clock: float) -> void:
	var head := fmod(clock * 0.16, 1.0)
	var band := RADIUS - WIDTH / 2.0 + 5.0
	for i in GLYPHS:
		var t := (float(i) + 0.5) / GLYPHS
		var a := start() + span() * t
		var at := polar(a, band)
		var behind := fposmod(head - t, 1.0)
		var read: float = clampf(1.0 - behind / 0.28, 0.0, 1.0)
		var carve := Color(Colors.PRIMARY, 0.08)
		var color := carve.lerp(Color(Colors.TITAN, 0.35 + 0.65 * read), glow)
		var width := 1.2 + glow * read * 1.1
		for stroke in _glyphs[i]:
			var p0: Vector2 = at + (stroke[0] as Vector2).rotated(a + PI / 2.0)
			var p1: Vector2 = at + (stroke[1] as Vector2).rotated(a + PI / 2.0)
			c.draw_line(p0, p1, color, width)
		if glow > 0.0 and read > 0.6:
			c.draw_circle(at, 4.0 * read, Color(Colors.TITAN, glow * 0.12 * read))
