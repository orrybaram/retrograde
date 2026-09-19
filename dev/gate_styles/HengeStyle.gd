extends "res://dev/gate_styles/GateStyle.gd"
## D. HENGE — standing stones with the tech buried in the joints.
##
## Nine megaliths set on the circle, each one tapered and chipped, with lintels laid
## across the pairs above. Nothing about the rock is machined: the only worked parts
## are the seams where lintel meets post, and those are glowing sockets. The whole
## thing reads as something dragged into place by hand and then wired.

const STONES := 9
const POST_LEN := 74.0

var _posts: Array[PackedVector2Array] = []
var _lintels: Array[PackedVector2Array] = []
var _runes: Array = []
var _angles: PackedFloat32Array = PackedFloat32Array()

func _init() -> void:
	id = "henge"
	title = "HENGE"
	blurb = "nine megaliths, glowing sockets where the lintels sit"
	var r := seeded("henge")
	_build(r)

func _build(r: RandomNumberGenerator) -> void:
	var step := span() / (STONES - 1)
	for i in STONES:
		var a := start() + step * i
		_angles.append(a)
		# A post stands radially: wide at the outside, narrower where the lintel lands.
		var out_w := r.randf_range(26.0, 34.0)
		var in_w := out_w * r.randf_range(0.62, 0.8)
		var outer := RADIUS + POST_LEN / 2.0 + r.randf_range(-4.0, 4.0)
		var inner := RADIUS - POST_LEN / 2.0 + r.randf_range(-3.0, 3.0)
		var t := Vector2(cos(a), sin(a)).orthogonal()
		var n := Vector2(cos(a), sin(a))
		var quad := PackedVector2Array([
			n * outer - t * out_w / 2.0, n * outer + t * out_w / 2.0,
			n * inner + t * in_w / 2.0, n * inner - t * in_w / 2.0,
		])
		_posts.append(rough(quad, r, 3.0))
		# Runes cut into the face of about half the stones.
		var marks := PackedVector2Array()
		if r.randf() < 0.6:
			for m in r.randi_range(2, 4):
				var p := n * r.randf_range(inner + 8.0, outer - 8.0) + t * r.randf_range(-4.0, 4.0)
				marks.append(p)
				marks.append(p + t * r.randf_range(-5.0, 5.0) + n * r.randf_range(-4.0, 4.0))
		_runes.append(marks)

	# Lintels bridge the gap between neighbours, laid over the outer end of the posts.
	# They follow the circle rather than cutting across it, so the ring holds together.
	for i in STONES - 1:
		var a0: float = _angles[i] - 0.05
		var a1: float = _angles[i + 1] + 0.05
		# The lintel band sits below the tops of the posts, so every stone still shows
		# its own head above the ring and the silhouette stays lumpy.
		var ro := RADIUS + POST_LEN / 2.0 - r.randf_range(9.0, 14.0)
		var ri := ro - r.randf_range(15.0, 19.0)
		var slab := PackedVector2Array()
		var steps := 6
		for s in steps + 1:
			slab.append(polar(lerpf(a0, a1, float(s) / steps), ro))
		for s in range(steps, -1, -1):
			slab.append(polar(lerpf(a0, a1, float(s) / steps), ri))
		_lintels.append(rough(slab, r, 2.0))

func draw_gate(c: CanvasItem, glow: float, clock: float) -> void:
	var stone := stone_of(glow)
	var lit := signal_of(glow)
	var pulse := 0.7 + 0.3 * sin(clock * 1.3)

	for i in STONES:
		var post: PackedVector2Array = _posts[i]
		c.draw_colored_polygon(post, stone)
		c.draw_polyline(post, stone.darkened(0.55), 2.2, true)
		# A face light down one side of every stone.
		c.draw_line(post[0], post[3], stone.lightened(0.18), 2.0)
		var marks: PackedVector2Array = _runes[i]
		var j := 0
		while j + 1 < marks.size():
			c.draw_line(marks[j], marks[j + 1],
				Color(Colors.PRIMARY, 0.1).lerp(Color(Colors.TITAN, 0.8 * pulse), glow), 1.6)
			j += 2

	# Lintels lie across the tops of the posts, the way they were levered up there.
	for slab in _lintels:
		c.draw_colored_polygon(slab, stone.lightened(0.06))
		c.draw_polyline(slab, stone.darkened(0.55), 2.2, true)

	# The sockets: where lintel meets post is the only worked joint on the thing, and
	# the only place the machine shows through the rock.
	for i in STONES:
		var a: float = _angles[i]
		var at := polar(a, RADIUS + POST_LEN / 2.0 - 9.0)
		c.draw_circle(at, 6.0, Color(lit, (0.05 + glow * 0.3) * pulse))
		c.draw_circle(at, 2.2, Color(lit, 0.25 + glow * 0.75))
		# The current running between sockets, along the underside of the lintels.
		if glow > 0.0 and i < STONES - 1:
			var b := polar(_angles[i + 1], RADIUS + POST_LEN / 2.0 - 9.0)
			c.draw_line(at, b, Color(Colors.TITAN, glow * 0.5 * pulse), 1.4)

	draw_halo(c, glow, RADIUS + POST_LEN / 2.0)
	_draw_altar(c, stone, lit, glow)
	draw_blinker(c, glow, clock, polar(-PI / 2.0, RADIUS + POST_LEN / 2.0 + 8.0))

## The cradle is an altar stone laid flat across the mouth, on two stubby footings.
func _draw_altar(c: CanvasItem, stone: Color, lit: Color, glow: float) -> void:
	var slab := PackedVector2Array([
		Vector2(-CRADLE_HALF - 8, RADIUS - 9), Vector2(CRADLE_HALF + 7, RADIUS - 8),
		Vector2(CRADLE_HALF + 10, RADIUS + 8), Vector2(-CRADLE_HALF - 11, RADIUS + 7),
	])
	for x in [-CRADLE_HALF + 2, CRADLE_HALF - 2]:
		var foot := PackedVector2Array([
			Vector2(x - 7, RADIUS + 2), Vector2(x + 7, RADIUS + 3),
			Vector2(x * 1.3 + 8, RADIUS + 26), Vector2(x * 1.3 - 8, RADIUS + 25),
		])
		c.draw_colored_polygon(foot, stone.darkened(0.3))
		c.draw_polyline(foot, stone.darkened(0.6), 2.0, true)
	c.draw_colored_polygon(slab, stone.lightened(0.05))
	c.draw_polyline(slab, stone.darkened(0.55), 2.2, true)
	c.draw_line(Vector2(-CRADLE_HALF, RADIUS - 4), Vector2(CRADLE_HALF, RADIUS - 4),
		Color(lit, 0.12 + glow * 0.75), 2.0)
