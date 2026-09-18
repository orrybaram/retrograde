@tool
class_name RobotView
extends Control

## The guide robot: a CRT case and antenna drawn as shapes, with an
## ASCII face (RobotFaces) glowing on a dot-matrix screen. Size scales with
## `font_size`; multiples of 8 keep the pixel font crisp.

enum Antenna { TWIN, SINGLE, OFFSET, DISH, TRIPLE, NONE }
## What sits on the panel under the screen.
enum Faceplate { BOLTS, BUTTONS, LIGHTS, SPEAKER, KEYPAD }

const FONT := preload("res://assets/fonts/kongtext.ttf")
const BLINK_TIME := 0.12
const TALK_FPS := 8.0

@export var expression: StringName = &"neutral" : set = set_expression
@export var antenna: Antenna = Antenna.NONE : set = _set_antenna
@export var faceplate: Faceplate = Faceplate.SPEAKER : set = _set_faceplate
@export var talking: bool = false
@export var font_size: int = 16 : set = _set_font_size
## Random glitch bursts per second. The "glitch" face always glitches.
@export_range(0.0, 5.0) var glitch_rate: float = 0.0

var _time := 0.0
var _next_blink := 2.5
var _blink_left := 0.0
var _glitch_left := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_time = _rng.randf() * 10.0
	_update_min_size()

func set_expression(v: StringName) -> void:
	expression = v if RobotFaces.has_face(v) else &"neutral"
	queue_redraw()

func glitch_burst(duration: float = 0.18) -> void:
	_glitch_left = maxf(_glitch_left, duration)

func blink() -> void:
	_blink_left = BLINK_TIME

func _set_antenna(v: Antenna) -> void:
	antenna = v
	_update_min_size()

func _set_faceplate(v: Faceplate) -> void:
	faceplate = v
	queue_redraw()

func _set_font_size(v: int) -> void:
	font_size = maxi(v, 8)
	_update_min_size()

func _update_min_size() -> void:
	custom_minimum_size = _body_size()
	update_minimum_size()
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink_left = BLINK_TIME
		_next_blink = _rng.randf_range(2.0, 5.0)
	_blink_left = maxf(_blink_left - delta, 0.0)
	_glitch_left = maxf(_glitch_left - delta, 0.0)
	# The broken faces tear themselves up whatever the caller asked for.
	var rate := 3.0 if expression == &"glitch" or expression == &"lost" else glitch_rate
	if rate > 0.0 and _rng.randf() < rate * delta:
		glitch_burst(_rng.randf_range(0.06, 0.2))
	queue_redraw()

# --- Layout -----------------------------------------------------------------
# Everything is measured in character cells `c` so the robot scales with the font.
# The screen is 8c x 5.5c inside a thick bezel, with a short panel strip below.

## One "pixel" of chunky detail at this size.
func _px() -> float:
	return maxf(1.0, floorf(font_size / 8.0))

func _c() -> float:
	return FONT.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _line_h() -> float:
	return font_size * 1.75

func _screen_size() -> Vector2:
	return Vector2(8.0, 5.5) * _c()

## Case rim outside the bezel.
func _case_pad() -> float:
	return _bezel() + _px() * 2.0

func _bezel() -> float:
	return _px() * 10.0

## Bezel, then a 7px panel strip, then the bottom rim.
func _chin_h() -> float:
	return _bezel() + _px() * 12.0

func _case_size() -> Vector2:
	var s := _screen_size()
	var p := _case_pad()
	return Vector2(s.x + p * 2.0, p + s.y + _chin_h())

func _antenna_h() -> float:
	return 0.0 if antenna == Antenna.NONE else _c() * 1.75

func _body_size() -> Vector2:
	var c := _case_size()
	return Vector2(c.x, c.y + _antenna_h())

# --- Drawing ----------------------------------------------------------------

func _draw() -> void:
	var px := _px()
	var origin := ((size - _body_size()) * 0.5).floor()
	var case_rect := Rect2(origin + Vector2(0, _antenna_h()), _case_size())
	_draw_antenna(case_rect, px)
	_draw_case(case_rect, px)
	var screen_rect := Rect2(case_rect.position + Vector2.ONE * _case_pad(), _screen_size())
	_draw_screen(screen_rect, px)
	var panel_top := screen_rect.end.y + _bezel() + px
	var panel_rect := Rect2(screen_rect.position.x, panel_top, screen_rect.size.x, case_rect.end.y - px * 4.0 - panel_top)
	_draw_faceplate(panel_rect, px)

## Blinking LED with a soft halo. `speed` is in radians per second.
func _led(pos: Vector2, radius: float, color: Color, speed: float, phase: float = 0.0) -> void:
	var lit := sin(_time * speed + phase) > 0.0
	draw_circle(pos, radius, color if lit else Color(color.darkened(0.6), 1.0))
	if lit:
		draw_circle(pos, radius * 2.0, Color(color, 0.15))

func _signal_speed() -> float:
	return 10.0 if talking else 2.0

func _mount(x: float, top: float, px: float) -> void:
	draw_rect(Rect2(x - px * 3.0, top - px * 2.0, px * 6.0, px * 2.0), Colors.HULL_MID)

func _draw_antenna(case_rect: Rect2, px: float) -> void:
	var top := case_rect.position.y
	var cx := case_rect.get_center().x
	var h := _antenna_h()
	var w := case_rect.size.x
	match antenna:
		Antenna.TWIN:
			var spread := _c() * 1.1
			var left_tip := Vector2(cx - spread, top - h + px * 2.0)
			var right_tip := Vector2(cx + spread, top - h + px * 2.0)
			draw_line(Vector2(cx, top), left_tip, Colors.HULL_LIGHT, px)
			draw_line(Vector2(cx, top), right_tip, Colors.HULL_LIGHT, px)
			draw_circle(left_tip, px * 1.5, Colors.HULL_LIGHT)
			_led(right_tip, px * 2.0, Colors.PRIMARY, _signal_speed())
			_mount(cx, top, px)
		Antenna.SINGLE:
			var tip := Vector2(cx, top - h + px * 2.0)
			draw_line(Vector2(cx, top), tip, Colors.HULL_LIGHT, px)
			var ring_y := top - h * 0.55
			draw_line(Vector2(cx - px * 3.0, ring_y), Vector2(cx + px * 3.0, ring_y), Colors.HULL_LIGHT, px)
			_led(tip, px * 2.0, Colors.PRIMARY, _signal_speed())
			_mount(cx, top, px)
		Antenna.OFFSET:
			var mast_x := case_rect.position.x + w * 0.25
			var tip := Vector2(mast_x, top - h + px * 2.0)
			draw_line(Vector2(mast_x, top), tip, Colors.HULL_LIGHT, px)
			_led(tip, px * 2.0, Colors.DANGER, _signal_speed())
			_mount(mast_x, top, px)
			var whip_x := case_rect.position.x + w * 0.72
			var whip_tip := Vector2(whip_x + px * 5.0, top - h * 0.55)
			draw_line(Vector2(whip_x, top), whip_tip, Colors.HULL_LIGHT, px)
			draw_circle(whip_tip, px, Colors.HULL_LIGHT)
			_mount(whip_x, top, px)
		Antenna.DISH:
			var post_top := Vector2(cx, top - h * 0.35)
			draw_line(Vector2(cx, top), post_top, Colors.HULL_LIGHT, px * 1.5)
			# Bowl: half-ellipse opening upward, tilted toward the sky
			var bowl := PackedVector2Array()
			var steps := 12
			for i in steps + 1:
				var t := PI * float(i) / float(steps)
				var p := Vector2(cos(t) * px * 7.0, sin(t) * px * 3.0).rotated(-0.35)
				bowl.append(post_top + Vector2(0, -px * 2.0) + p)
			draw_colored_polygon(bowl, Colors.HULL_MID)
			draw_polyline(bowl, Colors.HULL_LIGHT, px)
			draw_line(bowl[0], bowl[steps], Colors.HULL_LIGHT, px)
			var horn := post_top + Vector2(px * 2.0, -px * 8.0)
			draw_line(post_top + Vector2(0, -px * 2.0), horn, Colors.HULL_LIGHT, px)
			_led(horn, px * 1.5, Colors.PRIMARY, _signal_speed())
			_mount(cx, top, px)
		Antenna.TRIPLE:
			var gap := px * 5.0
			var heights := [h * 0.55, h - px * 2.0, h * 0.75]
			var colors := [Colors.SUCCESS, Colors.PRIMARY, Colors.DANGER]
			draw_rect(Rect2(cx - gap - px * 2.0, top - px * 2.0, gap * 2.0 + px * 4.0, px * 2.0), Colors.HULL_MID)
			for i in 3:
				var x := cx + gap * (i - 1)
				var tip := Vector2(x, top - heights[i])
				draw_line(Vector2(x, top - px * 2.0), tip, Colors.HULL_LIGHT, px)
				_led(tip, px * 1.5, colors[i], _signal_speed() * (1.0 + 0.3 * i), i * 1.7)

func _draw_case(r: Rect2, px: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Colors.HULL_MID
	box.border_color = Colors.HULL_LIGHT
	box.set_border_width_all(int(px))
	box.set_corner_radius_all(int(px * 3.0))
	box.anti_aliasing = false
	draw_style_box(box, r)
	# Top highlight and bottom shade give the case some depth
	draw_rect(Rect2(r.position + Vector2(px * 3.0, px), Vector2(r.size.x - px * 6.0, px)), Color(Colors.CREAM, 0.12))
	draw_rect(Rect2(Vector2(r.position.x + px * 3.0, r.end.y - px * 2.0), Vector2(r.size.x - px * 6.0, px)), Color(Colors.SPACE, 0.35))

func _draw_screen(r: Rect2, px: float) -> void:
	# Bezel
	var bezel := r.grow(_bezel())
	draw_rect(bezel, Colors.HULL_DARK)
	# Inner lip so the bezel reads as a recess
	draw_rect(r.grow(px), Color(Colors.SPACE, 0.6))
	draw_rect(Rect2(bezel.position.x, bezel.end.y - px, bezel.size.x, px), Color(Colors.CREAM, 0.08))
	draw_rect(r, Colors.SPACE)
	var face_color := _face_color()
	# Dot matrix
	var dot := Color(face_color, 0.07)
	var step := px * 3.0
	var y := r.position.y + step * 0.5
	while y < r.end.y:
		var x := r.position.x + step * 0.5
		while x < r.end.x:
			draw_rect(Rect2(Vector2(x, y).floor(), Vector2(px, px)), dot)
			x += step
		y += step
	# Face
	var rows := _current_rows()
	var lh := _line_h()
	var glitching := _glitch_left > 0.0
	var text_w := RobotFaces.WIDTH * _c()
	var left := r.position.x + (r.size.x - text_w) * 0.5
	var top := r.position.y + (r.size.y - RobotFaces.ROWS * lh) * 0.5
	var ascent := FONT.get_ascent(font_size)
	var flicker := 0.92 + 0.08 * sin(_time * 53.0)
	for i in rows.size():
		var jitter := 0.0
		if glitching and _rng.randf() < 0.5:
			jitter = _rng.randf_range(-2.0, 2.0) * px * 2.0
		var pos := Vector2(left + jitter, top + lh * i + (lh - font_size) * 0.5 + ascent).floor()
		draw_string_outline(FONT, pos, rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(px * 3.0), Color(face_color, 0.12))
		draw_string(FONT, pos, rows[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(face_color, flicker))
	# Scanlines
	var line := Color(Colors.SPACE, 0.35)
	var sy := r.position.y
	while sy < r.end.y:
		draw_rect(Rect2(r.position.x, sy, r.size.x, maxf(1.0, px * 0.5)), line)
		sy += px * 2.0
	if glitching:
		var band_y := r.position.y + _rng.randf() * r.size.y
		draw_rect(Rect2(r.position.x, band_y, r.size.x, px * 2.0), Color(face_color, 0.35))
	# Glass sheen
	draw_rect(Rect2(r.position + Vector2(px, px), Vector2(r.size.x * 0.35, px)), Color(Colors.CREAM, 0.06))

# --- Panel strip under the screen ------------------------------------------

func _draw_faceplate(r: Rect2, px: float) -> void:
	var cy := roundf(r.get_center().y)
	match faceplate:
		Faceplate.BOLTS:
			_bolt(Vector2(r.position.x + px * 3.0, cy), px)
			_bolt(Vector2(r.end.x - px * 3.0, cy), px)
			var mid := r.get_center().x
			draw_rect(Rect2(mid - px * 5.0, cy - px, px * 10.0, px * 2.0), Colors.HULL_DARK)
			draw_rect(Rect2(mid - px * 5.0, cy - px, px * 2.0, px * 2.0), _power_color())
		Faceplate.BUTTONS:
			var bw := px * 5.0
			var active := int(_time * 4.0) % 4 if talking else 0
			for i in 4:
				var lit := i == active
				_button(Rect2(r.position.x + px * 2.0 + i * (bw + px * 2.0), cy - px * 2.0, bw, px * 3.0), px, Colors.PRIMARY if lit else Colors.HULL_LIGHT)
			draw_circle(Vector2(r.end.x - px * 3.0, cy), px * 1.5, _power_color())
		Faceplate.LIGHTS:
			_bolt(Vector2(r.position.x + px * 3.0, cy), px)
			_bolt(Vector2(r.end.x - px * 3.0, cy), px)
			var count := 6
			var spacing := px * 4.0
			var start := r.get_center().x - spacing * (count - 1) * 0.5
			var colors := [Colors.SUCCESS, Colors.SUCCESS, Colors.SUCCESS, Colors.PRIMARY, Colors.PRIMARY, Colors.DANGER]
			# Idle: a slow chase. Talking: a bouncing level meter.
			var level := int(_time * 3.0) % count
			if talking:
				level = int((0.5 + 0.5 * sin(_time * 13.0) * sin(_time * 5.0)) * count)
			for i in count:
				var on := (i <= level) if talking else (i == level)
				var c: Color = colors[i] if on else Colors.HULL_DARK
				draw_rect(Rect2(start + spacing * i - px, cy - px, px * 2.0, px * 2.0), c)
		Faceplate.SPEAKER:
			var gw := r.size.x * 0.45
			for i in 3:
				draw_rect(Rect2(r.position.x + px * 2.0, cy - px * 2.5 + i * px * 2.0, gw, px), Colors.HULL_DARK)
			var bx := r.end.x - px * 3.0
			draw_circle(Vector2(bx, cy), px * 2.0, Colors.HULL_DARK)
			draw_circle(Vector2(bx, cy), px * 1.5, Colors.ORANGE)
			draw_circle(Vector2(bx - px * 6.0, cy), px * 2.0, Colors.HULL_DARK)
			draw_circle(Vector2(bx - px * 6.0, cy), px * 1.5, Colors.HULL_LIGHT)
			_led(Vector2(bx - px * 11.0, cy), px, Colors.SUCCESS, _signal_speed())
		Faceplate.KEYPAD:
			var kw := px * 3.0
			var kh := px * 2.0
			for row in 2:
				for col in 4:
					var key := Rect2(r.position.x + px * 2.0 + col * (kw + px), cy - kh - px * 0.5 + row * (kh + px), kw, kh)
					draw_rect(key, Colors.HULL_LIGHT)
					draw_rect(Rect2(key.position.x, key.end.y - maxf(1.0, px * 0.5), kw, maxf(1.0, px * 0.5)), Colors.HULL_DARK)
			var big := Vector2(r.end.x - px * 4.0, cy)
			draw_circle(big, px * 3.0, Colors.HULL_DARK)
			draw_circle(big, px * 2.0, Colors.DANGER)
			draw_circle(big + Vector2(-px * 0.5, -px * 0.5), px * 0.7, Color(Colors.CREAM, 0.35))
			_led(Vector2(big.x - px * 7.0, cy), px, Colors.PRIMARY, _signal_speed())

func _bolt(pos: Vector2, px: float) -> void:
	draw_circle(pos, px * 1.5, Colors.HULL_LIGHT)
	draw_line(pos - Vector2(px, 0), pos + Vector2(px, 0), Colors.HULL_DARK, maxf(1.0, px * 0.5))

## Small raised button: lit cap over a dark shadow.
func _button(r: Rect2, px: float, cap: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(0, px), r.size), Colors.HULL_DARK)
	draw_rect(r, cap)

func _power_color() -> Color:
	return Colors.DANGER if expression == &"dead" or expression == &"lost" else Colors.SUCCESS

func _face_color() -> Color:
	match expression:
		&"titan":
			return Colors.TITAN
		&"dead", &"lost":
			return Colors.DANGER
	return Colors.PRIMARY

func _current_rows() -> PackedStringArray:
	var rows := RobotFaces.rows_for(expression)
	var animated := not RobotFaces.is_text_face(expression)
	if animated and talking:
		rows = RobotFaces.talk(rows, int(_time * TALK_FPS))
	if animated and _blink_left > 0.0 and expression != &"dead" and expression != &"lost":
		rows = RobotFaces.blink(rows)
	if _glitch_left > 0.0:
		rows = RobotFaces.corrupt(rows, _rng, 0.25)
	return rows
