extends "res://dev/gate_styles/GateStyle.gd"
## F. CAIRN — dry stone, and light in the mortar.
##
## Seven stacks of rough blocks set around the ring, laid up without mortar the way a
## field wall is. What runs between the courses is not mortar either: every joint is a
## thread of light, so the ring looks stacked by hand and then filled with something
## that has been seeping through the gaps ever since.

const STACKS := 7
const COURSES := 4
const WIDTH := 46.0

var _blocks: Array = []      # per stack: Array[PackedVector2Array]
var _joints: Array = []      # per stack: Array[PackedVector2Array] (two points each)
var _angles: PackedFloat32Array = PackedFloat32Array()

func _init() -> void:
	id = "cairn"
	title = "CAIRN"
	blurb = "dry stone stacks with light seeping through every joint"
	var r := seeded("cairn")
	_build(r)

func _build(r: RandomNumberGenerator) -> void:
	var seg := span() / STACKS
	for i in STACKS:
		var a := start() + seg * (i + 0.5)
		_angles.append(a)
		var n := Vector2(cos(a), sin(a))
		var t := n.orthogonal()
		var stack: Array = []
		var joints: Array = []
		var edge := RADIUS - WIDTH / 2.0
		for course in COURSES:
			# Courses get shallower toward the outside, like a wall corbelled up.
			var h := (WIDTH / COURSES) * r.randf_range(0.8, 1.2)
			# Wide enough that the stacks almost touch: it has to read as a wall with
			# gaps in it, not as seven little towers.
			var w := r.randf_range(62.0, 74.0) * (1.0 - 0.1 * course)
			var skew := r.randf_range(-4.0, 4.0)
			var quad := PackedVector2Array([
				n * edge - t * w / 2.0, n * edge + t * w / 2.0,
				n * (edge + h) + t * (w / 2.0 + skew), n * (edge + h) - t * (w / 2.0 - skew),
			])
			stack.append(rough(quad, r, 1.9))
			if course > 0:
				joints.append(PackedVector2Array([
					n * edge - t * w / 2.0, n * edge + t * w / 2.0]))
			edge += h
		_blocks.append(stack)
		_joints.append(joints)

func draw_gate(c: CanvasItem, glow: float, clock: float) -> void:
	var stone := stone_of(glow)
	var lit := signal_of(glow)

	for i in STACKS:
		var a: float = _angles[i]
		for course in (_blocks[i] as Array).size():
			var quad: PackedVector2Array = _blocks[i][course]
			# Lower courses sit in the shadow of the ones above.
			var shade: float = 0.28 - 0.07 * course
			c.draw_colored_polygon(quad, stone.darkened(shade))
			c.draw_polyline(quad, stone.darkened(0.55), 2.0, true)
			c.draw_line(quad[2], quad[3], stone.lightened(0.12), 1.8)
		# The joints. Each one lights on its own slow beat, so the whole stack breathes
		# instead of flashing.
		for j in (_joints[i] as Array).size():
			var line: PackedVector2Array = _joints[i][j]
			var beat := 0.6 + 0.4 * sin(clock * 1.1 + i * 0.7 + j * 1.9)
			c.draw_line(line[0], line[1], Colors.SPACE_BG.darkened(0.4), 3.5)
			c.draw_line(line[0], line[1], Color(lit, (0.07 + glow * 0.75) * beat), 2.0)
			if glow > 0.0:
				c.draw_line(line[0], line[1], Color(Colors.TITAN, glow * 0.2 * beat), 6.0)

	# The seam between the stacks themselves: a gap you can see light through.
	var seg := span() / STACKS
	for i in STACKS - 1:
		var a: float = _angles[i] + seg / 2.0
		c.draw_line(polar(a, RADIUS - WIDTH / 2.0 + 3.0), polar(a, RADIUS + WIDTH / 2.0 - 3.0),
			Color(lit, 0.05 + glow * 0.4), 1.6)

	draw_halo(c, glow, RADIUS + WIDTH / 2.0)
	_draw_stone_cradle(c, stone, lit, glow)
	draw_blinker(c, glow, clock, polar(-PI / 2.0, RADIUS + WIDTH / 2.0))

## Two cairn footings with a single long stone laid across them.
func _draw_stone_cradle(c: CanvasItem, stone: Color, lit: Color, glow: float) -> void:
	for x in [-CRADLE_HALF, CRADLE_HALF]:
		for course in 2:
			var y := RADIUS + 6.0 + course * 10.0
			var w := 17.0 - course * 2.0
			var quad := PackedVector2Array([
				Vector2(x - w / 2.0, y), Vector2(x + w / 2.0, y - 1),
				Vector2(x * 1.15 + w / 2.0, y + 10), Vector2(x * 1.15 - w / 2.0, y + 11),
			])
			c.draw_colored_polygon(quad, stone.darkened(0.3 - 0.06 * course))
			c.draw_polyline(quad, stone.darkened(0.55), 1.8, true)
	var slab := PackedVector2Array([
		Vector2(-CRADLE_HALF - 12, RADIUS - 6), Vector2(CRADLE_HALF + 10, RADIUS - 7),
		Vector2(CRADLE_HALF + 13, RADIUS + 7), Vector2(-CRADLE_HALF - 14, RADIUS + 8),
	])
	c.draw_colored_polygon(slab, stone.lightened(0.04))
	c.draw_polyline(slab, stone.darkened(0.55), 2.2, true)
	c.draw_line(Vector2(-CRADLE_HALF - 8, RADIUS + 7), Vector2(CRADLE_HALF + 8, RADIUS + 6),
		Color(lit, 0.1 + glow * 0.7), 2.0)
