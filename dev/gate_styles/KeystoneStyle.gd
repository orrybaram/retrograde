extends "res://dev/gate_styles/GateStyle.gd"
## G. KEYSTONE — the script, cut into rock the size of BULWARK's plates.
##
## SCRIPT's writing and its travelling reading head, but the ring under it is quarried
## rather than machined: seven blocks with weathered edges, a deep shadow on the outer
## face and a lip on the inner one, capped where each block ends so the thickness shows.
##
## The block at the top is the keystone. It is wider than the rest, stands a little
## proud of the ring, carries a sigil no other block does, and holds the one blinker
## that is still running while the Gate is dead. It is what you line up on coming in.

const SEGMENTS := 7
## The keystone's index, and how much wider it is than an ordinary block.
const KEY := 3
const KEY_WIDE := 1.5
## How far it stands out past the rest of the ring.
const KEY_PROUD := 9.0
const WIDTH := 42.0
## Glyphs are laid out by arc length, so a wider block simply carries more of them.
const GLYPH_SPACING := 13.0

var _blocks: Array[PackedVector2Array] = []
var _bounds: Array = []      # per block: {from, to, mid}
var _glyphs: Array = []      # per block: Array of {t, strokes}
var _sigil: Array = []

func _init() -> void:
	id = "keystone"
	title = "KEYSTONE"
	blurb = "the script cut into quarried rock, with one block standing proud"
	var r := seeded("keystone")
	_build(r)

func _build(r: RandomNumberGenerator) -> void:
	var gap := deg_to_rad(3.4)
	var total := float(SEGMENTS - 1) + KEY_WIDE
	var cursor := start()
	for i in SEGMENTS:
		var arc: float = span() * (KEY_WIDE if i == KEY else 1.0) / total
		var from := cursor
		var to := cursor + arc - gap
		cursor += arc
		_bounds.append({"from": from, "to": to, "mid": (from + to) / 2.0})

		var proud: float = KEY_PROUD if i == KEY else 0.0
		var outer := RADIUS + WIDTH / 2.0 + proud
		var inner := RADIUS - WIDTH / 2.0 - proud * 0.35
		var out_wander := make_wander(r, 4.5)
		var in_wander := make_wander(r, 3.0)
		var pts := PackedVector2Array()
		var steps := 7
		for s in steps + 1:
			var t := float(s) / steps
			pts.append(polar(lerpf(from, to, t), outer + wander_at(out_wander, t)))
		for s in range(steps, -1, -1):
			var t := float(s) / steps
			pts.append(polar(lerpf(from, to, t), inner + wander_at(in_wander, t)))
		_blocks.append(pts)

		# The writing runs along the inner face of every block, keystone included.
		var count := int((to - from) * RADIUS / GLYPH_SPACING)
		var runes: Array = []
		for g in count:
			runes.append({
				"a": lerpf(from, to, (float(g) + 0.5) / count),
				"strokes": make_rune(r, r.randf_range(7.5, 11.0) * (1.15 if i == KEY else 1.0)),
			})
		_glyphs.append(runes)

	# The keystone's sigil: one character, bigger than the script and set above it.
	_sigil = make_rune(r, 20.0)
	_sigil.append(PackedVector2Array([Vector2(-7, 11), Vector2(7, 11)]))
	_sigil.append(PackedVector2Array([Vector2(-5, -12), Vector2(5, -12)]))

func draw_gate(c: CanvasItem, glow: float, clock: float) -> void:
	var stone := stone_of(glow)

	# The channel behind the blocks: dead rock while dormant, the way the light gets
	# out once the Module is running.
	c.draw_arc(Vector2.ZERO, RADIUS, start(), start() + span(), 96,
		Colors.SPACE_BG.lerp(Colors.TITAN, glow * 0.6), WIDTH - 16.0, true)

	for i in SEGMENTS:
		_draw_block(c, i, stone, glow, clock)

	draw_halo(c, glow, RADIUS + WIDTH / 2.0)
	_draw_keystone_mark(c, stone, glow, clock)
	_draw_heavy_cradle(c, stone, glow)
	draw_blinker(c, glow, clock, polar(_bounds[KEY]["mid"], RADIUS + WIDTH / 2.0 + KEY_PROUD + 9.0))

## One block: the rock, the shadow it throws outward, the lip that catches light on the
## inside, and the cut ends that show how thick it is.
func _draw_block(c: CanvasItem, i: int, stone: Color, glow: float, clock: float) -> void:
	var b: Dictionary = _bounds[i]
	var from: float = b["from"]
	var to: float = b["to"]
	var key := i == KEY
	var proud: float = KEY_PROUD if key else 0.0
	var face := stone.lightened(0.07) if key else stone

	c.draw_colored_polygon(_blocks[i], face)
	c.draw_polyline(_blocks[i], stone.darkened(0.55), 2.4, true)
	# Outer shadow and inner lip, the bulk BULWARK gets from its bezel.
	c.draw_arc(Vector2.ZERO, RADIUS + WIDTH / 2.0 + proud - 3.0, from, to, 40,
		stone.darkened(0.42), 6.0, true)
	c.draw_arc(Vector2.ZERO, RADIUS - WIDTH / 2.0 + 4.0, from, to, 40,
		stone.lightened(0.14 if key else 0.1), 3.0, true)
	# Cut ends.
	for a in [from, to]:
		c.draw_line(polar(a, RADIUS - WIDTH / 2.0 - proud * 0.35),
			polar(a, RADIUS + WIDTH / 2.0 + proud), stone.darkened(0.5), 3.5)

	_draw_script(c, i, glow, clock)

## The reading head runs the whole ring; each character lights as it passes and fades
## behind it. Dormant, none of it runs and the carving is barely there.
func _draw_script(c: CanvasItem, i: int, glow: float, clock: float) -> void:
	var head := fmod(clock * 0.16, 1.0)
	var band := RADIUS - WIDTH / 2.0 + 12.0
	var key := i == KEY
	for rune in _glyphs[i]:
		var a: float = rune["a"]
		var t: float = (a - start()) / span()
		var behind := fposmod(head - t, 1.0)
		var read: float = clampf(1.0 - behind / 0.26, 0.0, 1.0)
		var carve := Color(Colors.PRIMARY, 0.1 if key else 0.07)
		var color := carve.lerp(Color(Colors.TITAN, 0.3 + 0.7 * read), glow)
		var at := polar(a, band)
		for stroke in rune["strokes"]:
			c.draw_line(at + (stroke[0] as Vector2).rotated(a + PI / 2.0),
				at + (stroke[1] as Vector2).rotated(a + PI / 2.0),
				color, 1.3 + glow * read * 1.2)
		if glow > 0.0 and read > 0.6:
			c.draw_circle(at, 4.0 * read, Color(Colors.TITAN, glow * 0.12 * read))

## The sigil on the keystone, and the light behind it. This is the one character that
## is lit while the Gate is dead — faintly, the way the blinker is.
func _draw_keystone_mark(c: CanvasItem, stone: Color, glow: float, clock: float) -> void:
	var a: float = _bounds[KEY]["mid"]
	var at := polar(a, RADIUS + 3.0)
	var breath := 0.75 + 0.25 * sin(clock * 1.2)
	if glow > 0.0:
		c.draw_circle(at, 20.0, Color(Colors.TITAN, glow * 0.16 * breath))
		c.draw_circle(at, 11.0, Color(Colors.TITAN, glow * 0.2 * breath))
	var color := Color(Colors.PRIMARY, 0.16 * breath).lerp(
		Color(Colors.TITAN, 0.55 + 0.45 * breath), glow)
	for stroke in _sigil:
		c.draw_line(at + (stroke[0] as Vector2).rotated(a + PI / 2.0),
			at + (stroke[1] as Vector2).rotated(a + PI / 2.0), color, 2.2 + glow * 1.0)
	# A cut frame around it, so the sigil reads as set into the block.
	var b: Dictionary = _bounds[KEY]
	for edge in [b["from"] + 0.05, b["to"] - 0.05]:
		c.draw_line(polar(edge, RADIUS - 14.0), polar(edge, RADIUS + 18.0),
			stone.darkened(0.45), 2.0)

## Quarried footings with a cut stone laid across them.
func _draw_heavy_cradle(c: CanvasItem, stone: Color, glow: float) -> void:
	for x in [-CRADLE_HALF, CRADLE_HALF]:
		var foot := PackedVector2Array([
			Vector2(x - 9, RADIUS + 3), Vector2(x + 9, RADIUS + 4),
			Vector2(x * 1.28 + 10, RADIUS + 26), Vector2(x * 1.28 - 10, RADIUS + 25),
		])
		c.draw_colored_polygon(foot, stone.darkened(0.3))
		c.draw_polyline(foot, stone.darkened(0.55), 2.0, true)
	var slab := PackedVector2Array([
		Vector2(-CRADLE_HALF - 10, RADIUS - 8), Vector2(CRADLE_HALF + 9, RADIUS - 9),
		Vector2(CRADLE_HALF + 12, RADIUS + 8), Vector2(-CRADLE_HALF - 13, RADIUS + 7),
	])
	c.draw_colored_polygon(slab, stone.lightened(0.05))
	c.draw_polyline(slab, stone.darkened(0.55), 2.4, true)
	c.draw_line(Vector2(-CRADLE_HALF, RADIUS - 4), Vector2(CRADLE_HALF, RADIUS - 4),
		Color(Colors.PRIMARY, 0.12).lerp(Color(Colors.TITAN, 0.8), glow), 2.0)
