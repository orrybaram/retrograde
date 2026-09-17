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

@export_group("Colors")
@export var background_color: Color = Colors.UI_BACKGROUND
@export var border_color: Color = Colors.UI_BORDER
@export var grid_color: Color = Colors.PRIMARY_SUBTLE
@export var orbit_color: Color = Colors.PRIMARY_MEDIUM
@export var moon_orbit_color: Color = Colors.MOON_ORBIT
@export var space_station_orbit_color: Color = Colors.MOON_ORBIT
@export var sun_color: Color = Colors.SUN
@export var ship_color: Color = Colors.PRIMARY
@export var space_station_color: Color = Colors.HULL_LIGHT
@export var nav_color: Color = Colors.NAV

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
	var limit := Vector2.ONE * (_system_radius() * scale_factor) + _chart.size * 0.4
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

	# Fit the outermost orbit (plus a margin) inside the padded chart at zoom 1
	var span = _system_radius() + 1000.0
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
	for i in range(_stars.size()):
		var p := Vector2(_stars[i].x * c.size.x, _stars[i].y * c.size.y)
		c.draw_rect(Rect2(p.floor(), Vector2.ONE), Color(Colors.STAR, _star_alpha[i]))

func _draw_scanlines(c: Control) -> void:
	# Faint CRT banding over the chart, matching the rest of the terminal UI
	var line_color := Color(Colors.SPACE_BG, 0.22)
	var y := 0.0
	while y < c.size.y:
		c.draw_line(Vector2(0.0, y), Vector2(c.size.x, y), line_color, 1.0)
		y += 3.0

func _draw_range_rings(c: Control, rect: Rect2) -> void:
	# Distance rings from the sun at round intervals, labelled on the way out
	var center := _map_pos(_sun_pos())
	var step := _nice_step(150.0 / scale_factor)
	var ring_color := Color(grid_color, 0.09)
	var label_color := Color(grid_color, 0.22)
	# Keep ring labels out of the border, where the title and hints live
	var label_rect := rect.grow_individual(-10.0, -28.0, -10.0, -28.0)

	for i in range(1, 13):
		var distance := step * float(i)
		var radius := distance * scale_factor
		if not _ring_touches_rect(center, radius, rect):
			if radius > rect.size.length():
				break
			continue
		c.draw_arc(center, radius, 0.0, TAU, 128, ring_color, 1.0, true)
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

## Dashed ellipse (or circle when e == 0) in chart space.
func _draw_dashed_orbit(c: Control, rect: Rect2, center: Vector2, a: float, e: float, color: Color, width: float, min_radius: float = 0.0) -> void:
	var radius_px := maxf(a * scale_factor, min_radius)
	if radius_px < 1.5 or not _ring_touches_rect(center, radius_px, rect.grow(radius_px * e + 4.0)):
		return

	# Dashes are spaced by arc length, so they read the same at every orbit size,
	# and offscreen ones are skipped instead of drawn.
	var cull := rect.grow(24.0)
	var groups := clampi(int(TAU * radius_px / DASH_PERIOD_PX), 12, 2000)
	var step := TAU / float(groups)
	for g in range(groups):
		var points := PackedVector2Array()
		var on_screen := false
		for j in range(4):
			var angle := step * (float(g) + 0.6 * float(j) / 3.0)
			var r := a if e == 0.0 else a * (1.0 - e * e) / (1.0 + e * cos(angle))
			var point := center + Vector2(cos(angle), sin(angle)) * maxf(r * scale_factor, min_radius)
			points.append(point)
			on_screen = on_screen or cull.has_point(point)
		if on_screen:
			c.draw_polyline(points, color, width, true)

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
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / 4.0)
		c.draw_line(pos + dir * (r - 3.0), pos + dir * (r + 4.0), Color(nav_color, 0.7), 1.0)

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
	for i in range(4):
		var start := spin + TAU * float(i) / 4.0 + 0.22
		c.draw_arc(pos, 13.0, start, start + 0.66, 10, Color(ship_color, 0.45), 1.0, true)

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
	var color := Color(Colors.PRIMARY, alpha)
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var origin := Vector2(
			lerpf(inset, c.size.x - inset, corner.x),
			lerpf(inset, c.size.y - inset, corner.y)
		)
		var dir := Vector2(1.0 if corner.x == 0 else -1.0, 1.0 if corner.y == 0 else -1.0)
		c.draw_line(origin, origin + Vector2(arm * dir.x, 0.0), color, 2.0)
		c.draw_line(origin, origin + Vector2(0.0, arm * dir.y), color, 2.0)

func _draw_edge_ticks(c: Control, alpha: float) -> void:
	# Instrument ruler along the top and bottom rails
	var color := Color(Colors.PRIMARY, 0.18 * alpha)
	var x := 72.0
	while x < c.size.x - 72.0:
		c.draw_line(Vector2(x, BORDER_WIDTH), Vector2(x, BORDER_WIDTH + 5.0), color, 1.0)
		c.draw_line(Vector2(x, c.size.y - BORDER_WIDTH), Vector2(x, c.size.y - BORDER_WIDTH - 5.0), color, 1.0)
		x += 72.0

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

func _draw_scale_bar(c: Control, alpha: float) -> void:
	var step := _nice_step(120.0 / scale_factor)
	var length := step * scale_factor
	var color := Color(Colors.PRIMARY, 0.45 * alpha)
	var origin := Vector2(READOUT_INSET, c.size.y - READOUT_INSET)

	c.draw_line(origin, origin + Vector2(length, 0.0), color, 1.0)
	c.draw_line(origin + Vector2(0.0, -4.0), origin + Vector2(0.0, 4.0), color, 1.0)
	c.draw_line(origin + Vector2(length, -4.0), origin + Vector2(length, 4.0), color, 1.0)
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

## Does a circle cross the rect at all? Keeps offscreen orbits and rings cheap.
static func _ring_touches_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var corners := [
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
		rect.end
	]
	var farthest := 0.0
	for corner in corners:
		farthest = maxf(farthest, center.distance_to(corner))

	var nearest := 0.0
	if not rect.has_point(center):
		var clamped := Vector2(
			clampf(center.x, rect.position.x, rect.end.x),
			clampf(center.y, rect.position.y, rect.end.y)
		)
		nearest = center.distance_to(clamped)

	return radius >= nearest - 2.0 and radius <= farthest + 2.0
