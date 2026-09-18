extends Control
class_name SystemMap

## Fullscreen star chart: a dimmed backdrop behind a generously padded terminal
## frame that expands open from the middle, and a clipped chart view holding the
## sun, orbits, planets, stations, the ship reticle and the current nav target.

signal map_closed

## Chart contents. Clipped and scaled by the open animation, so it can never
## bleed into the padding around the frame.
class ChartCanvas extends Control:
	var map: SystemMap
	func _draw() -> void:
		if map:
			map.draw_chart(self)

## Frame, corner brackets, title/hint tabs and readouts. Drawn on top of the
## chart at full size so text stays crisp.
class ChromeCanvas extends Control:
	var map: SystemMap
	func _draw() -> void:
		if map:
			map.draw_chrome(self)

const BORDER_WIDTH := 2.0
const OPEN_TIME := 0.24
const CLOSE_TIME := 0.14
const TITLE_SIZE := 11
const TEXT_SIZE := 9
const SMALL_SIZE := 8
const READOUT_INSET := 18.0
const DASH_PERIOD_PX := 20.0
const STAR_COUNT := 160
const STARFIELD_SEED := 20260917
## Hazard hatching: spacing between the diagonals, and how far the chart reaches
## past the void's edge so the band is always visible at full zoom-out.
const HATCH_SPACING_PX := 13.0
const VOID_CHART_MARGIN := 1.02
## Where the single "THE VOID" label sits, from the deep line (0) out to the chart rim (1).
const VOID_LABEL_DEPTH := 0.5

@export_group("Colors")
@export var background_color: Color = Colors.UI_BACKGROUND
@export var border_color: Color = Colors.UI_BORDER
@export var grid_color: Color = Colors.PRIMARY_SUBTLE
@export var orbit_color: Color = Colors.PRIMARY_FADED
@export var moon_orbit_color: Color = Colors.MOON_ORBIT
@export var space_station_orbit_color: Color = Colors.MOON_ORBIT
@export var sun_color: Color = Colors.SUN
@export var ship_color: Color = Colors.PRIMARY
@export var space_station_color: Color = Colors.HULL_LIGHT
@export var nav_color: Color = Colors.NAV
@export var void_color: Color = Colors.DANGER

@export_group("Display")
@export var screen_margin_ratio: Vector2 = Vector2(0.065, 0.085)  ## Frame inset as a fraction of the screen
@export var min_screen_margin: Vector2 = Vector2(44.0, 34.0)  ## Floor for that inset, in pixels
@export var padding: float = 44.0  ## Gap between the frame and the outermost orbit
@export var planet_size_multiplier: float = 1.0  ## Multiplier for planet size (0.5 = half actual size for visibility)
@export var sun_size_multiplier: float = 1.0  ## Multiplier for sun size
@export var ship_size: float = 8.0  ## Ship indicator size

@export_group("Zoom and Pan")
@export var default_zoom_level: float = 1.0  ## Default zoom multiplier
@export var min_zoom_level: float = 1.0  ## Minimum zoom level (1.0 fits the whole system)
@export var max_zoom_level: float = 50.0  ## Maximum zoom level
@export var zoom_speed: float = 1.5  ## Zoom multiplier per key press
@export var pan_speed: float = 500.0  ## Pixels per second panning speed

var sun: Planet = null
var planets: Array[Planet] = []
var ship: Ship = null
var base_scale_factor: float = 1.0  ## Original auto-calculated scale
var scale_factor: float = 1.0  ## Current scale (base_scale_factor * zoom_level)
var map_center: Vector2 = Vector2.ZERO  ## Chart-local center of the view
var zoom_level: float = 0.0  ## Current zoom multiplier (0 until the first open; preserved after)
var pan_offset: Vector2 = Vector2.ZERO  ## Current pan offset from center

var _backdrop: ColorRect
var _chart: ChartCanvas
var _chrome: ChromeCanvas
var _font: Font
var _frame_rect: Rect2 = Rect2()
var _anim: float = 0.0  ## 0 = closed, 1 = fully open
var _anim_dir: int = 0  ## +1 opening, -1 closing, 0 settled
var _time: float = 0.0
var _stars: PackedVector2Array = PackedVector2Array()  ## Unit-square star positions
var _star_alpha: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("system_map")
	_font = get_theme_default_font()

	_backdrop = ColorRect.new()
	_backdrop.color = Color(Colors.SPACE_BG, 0.97)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_chart = ChartCanvas.new()
	_chart.map = self
	_chart.clip_contents = true
	_chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chart)

	_chrome = ChromeCanvas.new()
	_chrome.map = self
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chrome)

	_build_starfield()
	_layout()
	resized.connect(_layout)

	# Find references
	_find_celestial_bodies()
	ship = get_tree().get_first_node_in_group("ship") as Ship

func _build_starfield() -> void:
	# One fixed field so the chart backdrop is stable between openings.
	var rng := RandomNumberGenerator.new()
	rng.seed = STARFIELD_SEED
	for _i in range(STAR_COUNT):
		_stars.append(Vector2(rng.randf(), rng.randf()))
		_star_alpha.append(rng.randf_range(0.05, 0.22))

func _layout() -> void:
	var margin := Vector2(
		maxf(min_screen_margin.x, size.x * screen_margin_ratio.x),
		maxf(min_screen_margin.y, size.y * screen_margin_ratio.y)
	).floor()
	_frame_rect = Rect2(margin, (size - margin * 2.0).floor())

	_backdrop.position = Vector2.ZERO
	_backdrop.size = size

	_chrome.position = _frame_rect.position
	_chrome.size = _frame_rect.size

	var inset := Vector2.ONE * BORDER_WIDTH
	_chart.position = _frame_rect.position + inset
	_chart.size = _frame_rect.size - inset * 2.0
	_chart.pivot_offset = _chart.size / 2.0
	map_center = _chart.size / 2.0

func _find_celestial_bodies() -> void:
	# Find all planets in the scene
	planets.clear()
	sun = null

	var all_planets = get_tree().get_nodes_in_group("planets")
	for node in all_planets:
		if node is Planet:
			var planet = node as Planet
			if planet.planet_type == Planet.PlanetType.SUN:
				sun = planet
			else:
				planets.append(planet)

func _process(delta: float) -> void:
	if _anim_dir == 0 and not visible:
		return

	_time += delta
	_advance_anim(delta)
	if visible:
		_handle_panning(delta)
		_calculate_scale()
		_chart.queue_redraw()
		_chrome.queue_redraw()

func _advance_anim(delta: float) -> void:
	if _anim_dir > 0:
		_anim = minf(_anim + delta / OPEN_TIME, 1.0)
		if is_equal_approx(_anim, 1.0):
			_anim_dir = 0
	elif _anim_dir < 0:
		_anim = maxf(_anim - delta / CLOSE_TIME, 0.0)
		if _anim <= 0.0:
			_anim_dir = 0
			visible = false
			map_closed.emit()
			return

	# Backdrop dims in first, then the chart fades up and settles into place.
	_backdrop.modulate.a = _ease_out(_anim)
	var chart_t := _ease_out(clampf((_anim - 0.35) / 0.65, 0.0, 1.0))
	_chart.modulate.a = chart_t
	_chart.scale = Vector2.ONE * lerpf(0.965, 1.0, chart_t)

func _input(event: InputEvent) -> void:
	if not visible or _anim_dir < 0:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Close on M or Escape
		if event.keycode == KEY_M or event.keycode == KEY_ESCAPE:
			close_map()
			get_viewport().set_input_as_handled()
		# Zoom in with + or =
		elif event.keycode == KEY_PLUS or event.keycode == KEY_EQUAL:
			_zoom_in()
			get_viewport().set_input_as_handled()
		# Zoom out with - or _
		elif event.keycode == KEY_MINUS or event.keycode == KEY_UNDERSCORE:
			_zoom_out()
			get_viewport().set_input_as_handled()
		# Recenter on the ship with C
		elif event.keycode == KEY_C:
			_center_on_player()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	# Close on click
	if event is InputEventMouseButton and event.pressed:
		close_map()

func open_map() -> void:
	# Refresh references
	_find_celestial_bodies()
	if not ship:
		ship = get_tree().get_first_node_in_group("ship") as Ship

	# Initialize zoom level on first open, otherwise preserve it
	if zoom_level == 0.0 or zoom_level < min_zoom_level:
		zoom_level = default_zoom_level

	# Calculate scale first (needed for centering calculation)
	_layout()
	_calculate_scale()
	_refocus()

	visible = true
	_anim_dir = 1
	_advance_anim(0.0)

func close_map() -> void:
	if not visible or _anim_dir < 0:
		return
	_anim_dir = -1

## True while the map is on screen, including its close animation.
func is_open() -> bool:
	return visible

func _handle_panning(delta: float) -> void:
	var pan_direction = Vector2.ZERO

	# Arrow keys or WASD for panning
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		pan_direction.x -= 1.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		pan_direction.x += 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		pan_direction.y -= 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		pan_direction.y += 1.0

	# Normalize diagonal movement
	if pan_direction.length() > 0:
		pan_direction = pan_direction.normalized()
		var new_pan_offset = pan_offset + pan_direction * pan_speed * delta
		pan_offset = _clamp_pan_offset(new_pan_offset)

func _clamp_pan_offset(offset: Vector2) -> Vector2:
	if planets.is_empty():
		return offset

	# The sun may be pushed to the rim of the chart but no further, so anything
	# inside the system (the ship included) can be brought to the middle.
	var limit := Vector2.ONE * (_chart_radius() * scale_factor) + _chart.size * 0.4
	return Vector2(
		clampf(offset.x, -limit.x, limit.x),
		clampf(offset.y, -limit.y, limit.y)
	)

func _system_radius() -> float:
	var max_distance: float = 0.0
	for planet in planets:
		if planet and is_instance_valid(planet) and (not planet.parent_planet or planet.parent_planet == sun):
			max_distance = max(max_distance, planet.orbital_distance)
	return max_distance

## What the chart has to hold: the outermost orbit, or far enough out that the
## void's hazard band reads as a ring around the system rather than a corner.
func _chart_radius() -> float:
	return maxf(_system_radius() + 1000.0, VoidZone.DEEP_RADIUS * VOID_CHART_MARGIN)

func _zoom_in() -> void:
	zoom_level = clamp(zoom_level * zoom_speed, min_zoom_level, max_zoom_level)
	_calculate_scale()
	_refocus()

func _zoom_out() -> void:
	zoom_level = clamp(zoom_level / zoom_speed, min_zoom_level, max_zoom_level)
	_calculate_scale()
	_refocus()

## Fully zoomed out frames the whole system; any closer follows the ship.
func _refocus() -> void:
	if is_equal_approx(zoom_level, min_zoom_level):
		pan_offset = Vector2.ZERO
	else:
		_center_on_player()

func _center_on_player() -> void:
	# Pan so the ship sits at the middle of the chart; fall back to the sun
	if ship and is_instance_valid(ship) and sun:
		pan_offset = _clamp_pan_offset(-(ship.global_position - sun.global_position) * scale_factor)
	else:
		pan_offset = Vector2.ZERO

func _calculate_scale() -> void:
	if planets.is_empty():
		base_scale_factor = 0.1
		scale_factor = base_scale_factor * zoom_level
		return

	# Fit the outermost orbit and the edge of the void inside the padded chart at zoom 1
	var span = _chart_radius()
	var available_size = min(_chart.size.x, _chart.size.y) - padding * 2.0
	base_scale_factor = available_size / (span * 2.0)
	scale_factor = base_scale_factor * zoom_level

# --- Chart -------------------------------------------------------------------

func _sun_pos() -> Vector2:
	return sun.global_position if sun and is_instance_valid(sun) else Vector2.ZERO

## World position -> chart-local pixel position.
func _map_pos(world_pos: Vector2) -> Vector2:
	return map_center + pan_offset + (world_pos - _sun_pos()) * scale_factor

func draw_chart(c: Control) -> void:
	var rect := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(rect, background_color)
	_draw_starfield(c)

	if not sun or not is_instance_valid(sun):
		return

	_draw_void(c, rect)
	_draw_range_rings(c, rect)
	_draw_orbits(c, rect)
	_draw_child_orbits(c, rect)
	_draw_sun(c)
	_draw_planets(c, rect)
	_draw_stations(c, rect)
	_draw_nav_target(c, rect)
	_draw_ship(c)
	_draw_scanlines(c)

func _draw_starfield(c: Control) -> void:
	# One multiline for the whole field: a star per 1px segment
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in range(_stars.size()):
		var p := Vector2(_stars[i].x * c.size.x, _stars[i].y * c.size.y).floor()
		points.append(p)
		points.append(p + Vector2.RIGHT)
		colors.append(Color(Colors.STAR, _star_alpha[i]))
	c.draw_multiline_colors(points, colors, 1.0)

func _draw_scanlines(c: Control) -> void:
	# Faint CRT banding over the chart, matching the rest of the terminal UI
	var points := PackedVector2Array()
	var y := 0.0
	while y < c.size.y:
		points.append(Vector2(0.0, y))
		points.append(Vector2(c.size.x, y))
		y += 3.0
	c.draw_multiline(points, Color(Colors.SPACE_BG, 0.12), 1.0)

## Everything past the last orbit, struck through with hazard hatching: one set of
## diagonals from the edge out, a second set crossing them past DEEP_RADIUS where
## there is nothing left to see by. The boundary itself pulses once the ship is in it.
func _draw_void(c: Control, rect: Rect2) -> void:
	var center := _map_pos(_sun_pos())
	var edge := VoidZone.EDGE_RADIUS * scale_factor
	var deep := VoidZone.DEEP_RADIUS * scale_factor
	var alarm := VoidZone.shroud
	# Two passes at the same angle, the second offset half a step, so the hatching
	# simply doubles in density past DEEP_RADIUS instead of changing character.
	_draw_hatching(c, rect, center, edge, 0.0, Color(void_color, 0.11 + 0.07 * alarm))
	_draw_hatching(c, rect, center, deep, HATCH_SPACING_PX / 2.0, Color(void_color, 0.09 + 0.07 * alarm))

	# The boundary: a hairline normally, breathing red while the ship is past it.
	var boundary := Color(void_color, lerpf(0.3, 0.75, alarm * (0.6 + 0.4 * sin(_time * 4.0))))
	_draw_void_arc(c, rect, center, edge, boundary)
	_draw_void_arc(c, rect, center, deep, Color(void_color, boundary.a * 0.4))

	_draw_void_label(c, rect, center, maxf(edge, deep))

## One set of parallel diagonals across the chart, clipped to the outside of a
## circle. Each line contributes at most two segments, so the whole band costs a
## single multiline however far out the chart is panned. `phase` shifts the set
## sideways, which is how the deep band doubles its own density.
func _draw_hatching(c: Control, rect: Rect2, center: Vector2, radius: float, phase: float, color: Color) -> void:
	if color.a <= 0.002:
		return
	var direction := Vector2.from_angle(PI / 4.0)
	var normal := direction.orthogonal()
	# Walk the diagonals across the chart's diagonal span, measured from its middle.
	var span := rect.size.length()
	var half := span / 2.0
	var origin := rect.get_center()
	var points := PackedVector2Array()

	var offset := -half + phase
	while offset <= half:
		var line_start := origin + normal * offset - direction * half
		_append_outside_circle(points, line_start, direction, span, center, radius)
		offset += HATCH_SPACING_PX
	if not points.is_empty():
		c.draw_multiline(points, color, 1.0)

## An arc of the void's boundary, drawn only where it crosses the chart.
func _draw_void_arc(c: Control, rect: Rect2, center: Vector2, radius: float, color: Color) -> void:
	var arc := _visible_arc(center, radius, rect)
	if arc.y <= 0.0:
		return
	c.draw_arc(center, radius, arc.x, arc.x + arc.y, clampi(int(radius * arc.y / 5.0), 12, 256), color, 1.0, true)

## Appends the parts of the segment start -> start + direction * length that fall
## outside the circle, as point pairs.
static func _append_outside_circle(points: PackedVector2Array, start: Vector2, direction: Vector2, length: float, center: Vector2, radius: float) -> void:
	var to_center := start - center
	# |start + t*direction - center|^2 = radius^2, with direction normalized.
	var b := to_center.dot(direction)
	var discriminant := b * b - (to_center.length_squared() - radius * radius)
	if discriminant <= 0.0:
		# The line misses the circle entirely, so it's wholly in or wholly out.
		if to_center.length() > radius:
			points.append(start)
			points.append(start + direction * length)
		return

	var root := sqrt(discriminant)
	var t_in := clampf(-b - root, 0.0, length)
	var t_out := clampf(-b + root, 0.0, length)
	if t_in > 0.5:
		points.append(start)
		points.append(start + direction * t_in)
	if t_out < length - 0.5:
		points.append(start + direction * t_out)
		points.append(start + direction * length)

## One "THE VOID", set out in the dark rather than on the boundary — the label
## belongs to the emptiness, not to the line around the system. Sides first,
## since a 16:9 chart has the most room there; whichever way fits wins.
func _draw_void_label(c: Control, rect: Rect2, center: Vector2, inner: float) -> void:
	var text := TerminalWindow.spaced_title("THE VOID")
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
	var inset := rect.grow(-14.0)

	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		# Sit it partway from the deep line out to the rim, so it reads as being
		# well inside the void rather than labelling the edge of it.
		var rim := _rim_distance(center, direction, rect)
		if rim <= inner:
			continue
		var at := center + direction * lerpf(inner, rim, VOID_LABEL_DEPTH) - Vector2(width / 2.0, 0.0)
		if not inset.has_point(at) or not inset.has_point(at + Vector2(width, 0.0)):
			continue
		# Blank the hatching behind the text so it stays readable
		c.draw_rect(Rect2(at - Vector2(3.0, SMALL_SIZE), Vector2(width + 6.0, SMALL_SIZE + 5.0)), Color(Colors.UI_BACKGROUND_SOLID, 0.85))
		c.draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, Color(void_color, 0.55))
		return

## How far the chart reaches from `center` along a cardinal `direction` before
## leaving `rect`. Zero once the center has been panned off that side.
static func _rim_distance(center: Vector2, direction: Vector2, rect: Rect2) -> float:
	if direction.x > 0.0:
		return maxf(rect.end.x - center.x, 0.0)
	if direction.x < 0.0:
		return maxf(center.x - rect.position.x, 0.0)
	if direction.y > 0.0:
		return maxf(rect.end.y - center.y, 0.0)
	return maxf(center.y - rect.position.y, 0.0)

func _draw_range_rings(c: Control, rect: Rect2) -> void:
	# Distance rings from the sun at round intervals, labelled on the way out
	var center := _map_pos(_sun_pos())
	var step := _nice_step(150.0 / scale_factor)
	# Hairline rings: sub-pixel width, antialiased so they stay a whisper
	var ring_color := Color(grid_color, 0.045)
	var label_color := Color(grid_color, 0.14)
	# Keep ring labels out of the border, where the title and hints live
	var label_rect := rect.grow_individual(-10.0, -28.0, -10.0, -28.0)

	for i in range(1, 13):
		var distance := step * float(i)
		var radius := distance * scale_factor
		var arc := _visible_arc(center, radius, rect)
		if arc.y <= 0.0:
			if radius > rect.size.length():
				break
			continue
		var ring_points := clampi(int(radius * arc.y / 6.0), 8, 192)
		c.draw_arc(center, radius, arc.x, arc.x + arc.y, ring_points, ring_color, 0.7, true)
		var label_pos := center + Vector2.from_angle(-PI / 4.0) * (radius + 4.0)
		if label_rect.has_point(label_pos):
			c.draw_string(_font, label_pos, _format_distance(distance), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, label_color)

func _draw_orbits(c: Control, rect: Rect2) -> void:
	var center := _map_pos(_sun_pos())
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		# Moons orbit their parent planet, not the sun
		if planet.parent_planet and planet.parent_planet != sun:
			continue
		_draw_dashed_orbit(c, rect, center, planet.orbital_distance, _eccentricity(planet), orbit_color, 1.0)

func _draw_child_orbits(c: Control, rect: Rect2) -> void:
	# Moons and stations both orbit a parent planet, drawn in the same dashed style
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		if not planet.parent_planet or planet.parent_planet == sun:
			continue
		var center := _map_pos(planet.parent_planet.global_position)
		_draw_dashed_orbit(c, rect, center, planet.orbital_distance, _eccentricity(planet), moon_orbit_color, 1.5, 6.0)

	for node in get_tree().get_nodes_in_group("space_stations"):
		var station := node as SpaceStation
		if not station or not is_instance_valid(station) or not station.parent_planet:
			continue
		var center := _map_pos(station.parent_planet.global_position)
		_draw_dashed_orbit(c, rect, center, station.orbital_distance, _eccentricity(station), space_station_orbit_color, 1.5, 6.0)

func _eccentricity(body: Node) -> float:
	return clamp(body.eccentricity, 0.0, 0.99) if "eccentricity" in body else 0.0

## Dashed ellipse (or circle when e == 0) in chart space. The dashes go out as a
## single multiline, and only the arc that crosses the chart is generated at all:
## a ring 20000px across otherwise costs thousands of draw calls a frame.
func _draw_dashed_orbit(c: Control, rect: Rect2, center: Vector2, a: float, e: float, color: Color, width: float, min_radius: float = 0.0) -> void:
	var radius_px := maxf(a * scale_factor, min_radius)
	if radius_px < 1.5:
		return

	# Eccentric orbits reach further than their semi-major axis, so the window is
	# measured against a rect grown by that slack.
	var arc := _visible_arc(center, radius_px, rect.grow(radius_px * e + 4.0))
	if arc.y <= 0.0:
		return

	var dashes := clampi(int(radius_px * arc.y / DASH_PERIOD_PX), 1, 400)
	var step := arc.y / float(dashes)
	var points := PackedVector2Array()
	for d in range(dashes):
		var from_angle := arc.x + step * float(d)
		var to_angle := from_angle + step * 0.6
		points.append(_orbit_point(center, a, e, from_angle, min_radius))
		points.append(_orbit_point(center, a, e, to_angle, min_radius))
	c.draw_multiline(points, color, width)

func _orbit_point(center: Vector2, a: float, e: float, angle: float, min_radius: float) -> Vector2:
	var r := a if e == 0.0 else a * (1.0 - e * e) / (1.0 + e * cos(angle))
	return center + Vector2.from_angle(angle) * maxf(r * scale_factor, min_radius)

func _draw_sun(c: Control) -> void:
	var pos := _map_pos(_sun_pos())
	var radius := maxf(sun.radius * scale_factor * sun_size_multiplier, 2.0)

	# Layered corona, brightest at the core
	for i in range(4, 0, -1):
		c.draw_circle(pos, radius * (1.0 + 0.5 * float(i)), Color(sun_color, 0.035))
	c.draw_circle(pos, radius, sun.color)
	c.draw_arc(pos, radius + 1.0, 0.0, TAU, 48, Color(sun_color, 0.5), 1.0, true)
	_draw_body_label(c, pos, radius, sun.planet_name, Color(sun_color, 0.7))

func _draw_planets(c: Control, rect: Rect2) -> void:
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue

		var pos := _map_pos(planet.global_position)
		var radius := maxf(planet.radius * scale_factor * planet_size_multiplier, 2.0)
		if not rect.grow(radius + 8.0).has_point(pos):
			continue

		c.draw_circle(pos, radius, planet.color)
		c.draw_arc(pos, radius + 1.5, 0.0, TAU, 40, Color(planet.color, 0.45), 1.0, true)

		# Moons stay unlabelled unless they are big enough to read against
		var is_moon := planet.parent_planet != null and planet.parent_planet != sun
		if not is_moon or radius >= 3.5:
			_draw_body_label(c, pos, radius, planet.planet_name, Color(Colors.PRIMARY, 0.55 if not is_moon else 0.35))

func _draw_body_label(c: Control, pos: Vector2, radius: float, text: String, color: Color) -> void:
	if text.is_empty():
		return
	var leader_start := pos + Vector2(radius + 3.0, 0.0)
	var leader_end := leader_start + Vector2(5.0, 0.0)
	c.draw_line(leader_start, leader_end, Color(color, color.a * 0.5), 1.0)
	c.draw_string(_font, leader_end + Vector2(4.0, 3.0), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, color)

func _draw_stations(c: Control, rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group("space_stations"):
		var station := node as Node2D
		if not station or not is_instance_valid(station):
			continue

		var pos := _map_pos(station.global_position)
		if not rect.grow(16.0).has_point(pos):
			continue

		# Hollow diamond, so stations never read as a planet
		var r := 4.5
		var diamond := PackedVector2Array([
			pos + Vector2(0.0, -r), pos + Vector2(r, 0.0),
			pos + Vector2(0.0, r), pos + Vector2(-r, 0.0),
			pos + Vector2(0.0, -r)
		])
		c.draw_polygon(diamond.slice(0, 4), PackedColorArray([Color(Colors.SPACE_BG, 0.9)]))
		c.draw_polyline(diamond, space_station_color, 1.2, true)
		c.draw_line(pos + Vector2(-r - 3.0, 0.0), pos + Vector2(r + 3.0, 0.0), Color(space_station_color, 0.4), 1.0)

		# Only label it once it has pulled clear of its planet's own label
		var station_body := node as SpaceStation
		if station_body and station_body.orbital_distance * scale_factor > 16.0:
			_draw_body_label(c, pos, r + 2.0, "STATION", Color(space_station_color, 0.6))

func _draw_nav_target(c: Control, rect: Rect2) -> void:
	var target := NavSystem.get_target()
	if target == null or not target.is_valid():
		return

	var pos := _map_pos(target.get_position())
	if not rect.grow(24.0).has_point(pos):
		return

	# Dotted run from the ship to the marker: blue is navigation only. Docked at
	# the target, the two markers coincide, so the leg and label are dropped.
	var ship_pos := _map_pos(ship.global_position) if ship and is_instance_valid(ship) else pos
	var apart := ship_pos.distance_to(pos) > 30.0
	if apart:
		c.draw_dashed_line(ship_pos, pos, Color(nav_color, 0.22), 1.0, 5.0)

	var r := 9.0
	c.draw_arc(pos, r, 0.0, TAU, 32, Color(nav_color, 0.7), 1.0, true)
	var ticks := PackedVector2Array()
	for i in range(4):
		var dir := Vector2.from_angle(TAU * float(i) / 4.0)
		ticks.append(pos + dir * (r - 3.0))
		ticks.append(pos + dir * (r + 4.0))
	c.draw_multiline(ticks, Color(nav_color, 0.7), 1.0)

	if not apart:
		return

	# Below the marker, clear of the body label that shares the spot
	var label := "%s  %s" % [
		target.get_label().to_upper(),
		_format_distance(ship.global_position.distance_to(target.get_position()))
	] if ship and is_instance_valid(ship) else target.get_label().to_upper()
	c.draw_string(_font, pos + Vector2(-r, r + 12.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, Color(nav_color, 0.8))

func _draw_ship(c: Control) -> void:
	if not ship or not is_instance_valid(ship):
		return

	var pos := _map_pos(ship.global_position)

	# Radar ping, so the eye finds the ship immediately
	var ping := fmod(_time, 2.2) / 2.2
	c.draw_arc(pos, lerpf(11.0, 34.0, ping), 0.0, TAU, 40, Color(ship_color, 0.3 * (1.0 - ping)), 1.0, true)

	# Slowly turning bracket reticle
	var spin := _time * 0.5
	var brackets := PackedVector2Array()
	for i in range(4):
		var start := spin + TAU * float(i) / 4.0 + 0.22
		for seg in range(4):
			brackets.append(pos + Vector2.from_angle(start + 0.66 * float(seg) / 4.0) * 13.0)
			brackets.append(pos + Vector2.from_angle(start + 0.66 * float(seg + 1) / 4.0) * 13.0)
	c.draw_multiline(brackets, Color(ship_color, 0.45), 1.0)

	# Heading vector scaled by speed
	var speed := ship.linear_velocity.length()
	if speed > 5.0:
		var heading := ship.linear_velocity.normalized()
		c.draw_line(pos, pos + heading * minf(10.0 + speed * 0.05, 34.0), Color(ship_color, 0.4), 1.0, true)

	# Triangle points UP at angle 0, but ship rotation 0 = RIGHT, so add PI/2
	var angle := ship.global_rotation + PI / 2.0
	var points := PackedVector2Array()
	for point in [Vector2(0, -ship_size), Vector2(-ship_size * 0.7, ship_size * 0.6), Vector2(ship_size * 0.7, ship_size * 0.6)]:
		points.append(pos + point.rotated(angle))
	c.draw_polygon(points, PackedColorArray([ship_color, ship_color, ship_color]))
	var outline := points.duplicate()
	outline.append(points[0])
	c.draw_polyline(outline, Color(Colors.SPACE_BG, 0.8), 1.0, true)

# --- Chrome ------------------------------------------------------------------

func draw_chrome(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var cx := w / 2.0
	var cy := h / 2.0
	var half := BORDER_WIDTH / 2.0

	# The frame draws itself on: horizontals sweep out from the middle first,
	# verticals follow, then the labels fade up.
	var grow_h := _ease_out(clampf(_anim / 0.55, 0.0, 1.0))
	var grow_v := _ease_out(clampf((_anim - 0.15) / 0.6, 0.0, 1.0))
	var text_a := clampf((_anim - 0.45) / 0.55, 0.0, 1.0)

	var span_x := cx * grow_h
	c.draw_line(Vector2(cx - span_x, half), Vector2(cx + span_x, half), border_color, BORDER_WIDTH)
	c.draw_line(Vector2(cx - span_x, h - half), Vector2(cx + span_x, h - half), border_color, BORDER_WIDTH)

	if grow_v > 0.0:
		var span_y := cy * grow_v
		c.draw_line(Vector2(half, cy - span_y), Vector2(half, cy + span_y), border_color, BORDER_WIDTH)
		c.draw_line(Vector2(w - half, cy - span_y), Vector2(w - half, cy + span_y), border_color, BORDER_WIDTH)

	if text_a <= 0.01:
		return

	_draw_corner_brackets(c, text_a)
	_draw_edge_ticks(c, text_a)
	_draw_tab(c, TerminalWindow.spaced_title("SYSTEM MAP"), TITLE_SIZE, Color(Colors.PRIMARY, text_a), false)
	_draw_tab(c, "[ +/- ] ZOOM   [ WASD ] PAN   [ C ] CENTER   [ M ] CLOSE", SMALL_SIZE, Color(Colors.PRIMARY_DIM, text_a), true)
	_draw_readout(c, text_a)
	_draw_scale_bar(c, text_a)

func _draw_corner_brackets(c: Control, alpha: float) -> void:
	var arm := 16.0
	var inset := 7.0
	var points := PackedVector2Array()
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var origin := Vector2(
			lerpf(inset, c.size.x - inset, corner.x),
			lerpf(inset, c.size.y - inset, corner.y)
		)
		var dir := Vector2(1.0 if corner.x == 0 else -1.0, 1.0 if corner.y == 0 else -1.0)
		points.append(origin)
		points.append(origin + Vector2(arm * dir.x, 0.0))
		points.append(origin)
		points.append(origin + Vector2(0.0, arm * dir.y))
	c.draw_multiline(points, Color(Colors.PRIMARY, alpha), 2.0)

func _draw_edge_ticks(c: Control, alpha: float) -> void:
	# Instrument ruler along the top and bottom rails
	var points := PackedVector2Array()
	var x := 72.0
	while x < c.size.x - 72.0:
		points.append(Vector2(x, BORDER_WIDTH))
		points.append(Vector2(x, BORDER_WIDTH + 5.0))
		points.append(Vector2(x, c.size.y - BORDER_WIDTH))
		points.append(Vector2(x, c.size.y - BORDER_WIDTH - 5.0))
		x += 72.0
	c.draw_multiline(points, Color(Colors.PRIMARY, 0.18 * alpha), 1.0)

func _draw_tab(c: Control, text: String, font_size: int, color: Color, bottom: bool) -> void:
	# Notch the label into the border, terminal-window style
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad := 8.0
	var y := c.size.y if bottom else 0.0
	var box := Rect2(
		Vector2(c.size.x - 20.0 - text_size.x - pad * 2.0, y - text_size.y / 2.0),
		Vector2(text_size.x + pad * 2.0, text_size.y)
	)
	c.draw_rect(box, Color(Colors.UI_BACKGROUND_SOLID, color.a))
	var baseline := box.position + Vector2(pad, _font.get_ascent(font_size))
	c.draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_readout(c: Control, alpha: float) -> void:
	var key_color := Color(Colors.PRIMARY, 0.4 * alpha)
	var value_color := Color(Colors.PRIMARY, 0.8 * alpha)
	var rows: Array[Array] = [["ZOOM", "x%.1f" % zoom_level]]

	if ship and is_instance_valid(ship):
		var relative := ship.global_position - _sun_pos()
		rows.append(["SHIP", "%+.1f / %+.1f Mm" % [relative.x / 1000.0, relative.y / 1000.0]])

	var target := NavSystem.get_target()
	if target and target.is_valid() and ship and is_instance_valid(ship):
		rows.append(["NAV", "%s  %s" % [
			target.get_label().to_upper(),
			_format_distance(ship.global_position.distance_to(target.get_position()))
		]])

	var y := READOUT_INSET + _font.get_ascent(TEXT_SIZE)
	for row in rows:
		c.draw_string(_font, Vector2(READOUT_INSET, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, key_color)
		c.draw_string(_font, Vector2(READOUT_INSET + 52.0, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, value_color)
		y += _font.get_height(TEXT_SIZE) + 3.0

	# The chart is the one instrument the void leaves half-working, so the clock
	# lives here rather than on the dashboard that's busy falling apart.
	if VoidZone.is_inside():
		var left := VoidZone.time_left()
		c.draw_string(_font, Vector2(READOUT_INSET, y), "VOID", HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color(void_color, 0.6 * alpha))
		c.draw_string(_font, Vector2(READOUT_INSET + 52.0, y), "%.1f s" % left, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color(void_color, alpha))

func _draw_scale_bar(c: Control, alpha: float) -> void:
	var step := _nice_step(120.0 / scale_factor)
	var length := step * scale_factor
	var color := Color(Colors.PRIMARY, 0.45 * alpha)
	var origin := Vector2(READOUT_INSET, c.size.y - READOUT_INSET)

	c.draw_multiline(PackedVector2Array([
		origin, origin + Vector2(length, 0.0),
		origin + Vector2(0.0, -4.0), origin + Vector2(0.0, 4.0),
		origin + Vector2(length, -4.0), origin + Vector2(length, 4.0)
	]), color, 1.0)
	c.draw_string(_font, origin + Vector2(0.0, -8.0), _format_distance(step), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, Color(Colors.PRIMARY, 0.6 * alpha))

# --- Helpers -----------------------------------------------------------------

static func _ease_out(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

## Round a raw distance up to the nearest 1/2/5 x 10^n, for rings and scale bars.
static func _nice_step(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var magnitude := pow(10.0, floor(log(raw) / log(10.0)))
	var normalized := raw / magnitude
	if normalized <= 1.0:
		return magnitude
	if normalized <= 2.0:
		return 2.0 * magnitude
	if normalized <= 5.0:
		return 5.0 * magnitude
	return 10.0 * magnitude

## World units read as kilometres on the chart.
static func _format_distance(units: float) -> String:
	if units < 1000.0:
		return "%d km" % int(round(units))
	if units < 1_000_000.0:
		return "%.1f Mm" % (units / 1000.0)
	return "%.2f Gm" % (units / 1_000_000.0)

## The slice of a circle that can actually show inside the rect, as
## (start_angle, span). A span of 0 means the ring misses the chart entirely, so
## no geometry is built for it. Keeps cost tied to what is on screen rather than
## to the zoom level.
static func _visible_arc(center: Vector2, radius: float, rect: Rect2) -> Vector2:
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
		rect.end
	]

	var farthest := 0.0
	for corner in corners:
		farthest = maxf(farthest, center.distance_to(corner))
	if radius > farthest + 2.0:
		return Vector2.ZERO

	# Centre inside the chart: every angle is potentially visible
	if rect.has_point(center):
		return Vector2(0.0, TAU)

	var clamped := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	if radius < center.distance_to(clamped) - 2.0:
		return Vector2.ZERO

	# From outside, the rect subtends less than half a turn, so the window is
	# bounded by the most clockwise and counter-clockwise corners.
	var axis := (rect.get_center() - center).angle()
	var lowest := 0.0
	var highest := 0.0
	for corner in corners:
		var offset := angle_difference(axis, (corner - center).angle())
		lowest = minf(lowest, offset)
		highest = maxf(highest, offset)

	return Vector2(axis + lowest, highest - lowest)
