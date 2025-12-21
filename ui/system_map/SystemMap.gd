extends Control
class_name SystemMap

## Fullscreen solar system map showing all planets, sun, and orbital paths.

signal map_closed

@export_group("Colors")
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.9)
@export var border_color: Color = Color(1.0, 0.75, 0.0, 1.0)  # Amber
@export var grid_color: Color = Color(1.0, 0.75, 0.0, 0.15)  # Faded amber
@export var orbit_color: Color = Color(1.0, 0.75, 0.0, 0.4)  # Planet orbit path color
@export var moon_orbit_color: Color = Color(0.5, 0.75, 1.0, 0.5)  # Moon orbit path color (more visible)
@export var sun_color: Color = Color(1.0, 0.9, 0.5, 1.0)  # Yellow-ish
@export var ship_color: Color = Color(1.0, 0.75, 0.0, 1.0)  # Amber

@export_group("Display")
@export var padding: float = 80.0  ## Padding from screen edges
@export var planet_size_multiplier: float = 1.0  ## Multiplier for planet size (0.5 = half actual size for visibility)
@export var sun_size_multiplier: float = 1.0  ## Multiplier for sun size
@export var ship_size: float = 8.0  ## Ship indicator size
@export var grid_ring_count: int = 5  ## Number of grid rings

@export_group("Zoom and Pan")
@export var default_zoom_level: float = 5.0  ## Default zoom multiplier (1.5x = zoomed in)
@export var min_zoom_level: float = 3.0  ## Minimum zoom level
@export var max_zoom_level: float = 15.0  ## Maximum zoom level
@export var zoom_speed: float = 1.5  ## Zoom multiplier per key press
@export var pan_speed: float = 500.0  ## Pixels per second panning speed

var generator: SolarSystemGenerator = null
var ship: Ship = null
var base_scale_factor: float = 1.0  ## Original auto-calculated scale
var scale_factor: float = 1.0  ## Current scale (base_scale_factor * zoom_level)
var map_center: Vector2 = Vector2.ZERO
var zoom_level: float = 5.0  ## Current zoom multiplier (preserved between map sessions)
var pan_offset: Vector2 = Vector2.ZERO  ## Current pan offset from center

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("system_map")
	
	# Find references
	generator = get_tree().get_first_node_in_group("solar_system_generator") as SolarSystemGenerator
	ship = get_tree().get_first_node_in_group("ship") as Ship

func _process(delta: float) -> void:
	if visible:
		_handle_panning(delta)
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
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

func _gui_input(event: InputEvent) -> void:
	# Close on click
	if event is InputEventMouseButton and event.pressed:
		close_map()

func open_map() -> void:
	# Find references if not set
	if not generator:
		generator = get_tree().get_first_node_in_group("solar_system_generator") as SolarSystemGenerator
	if not ship:
		ship = get_tree().get_first_node_in_group("ship") as Ship
	
	# Initialize zoom level on first open, otherwise preserve it
	if zoom_level == 0.0 or zoom_level < min_zoom_level:
		zoom_level = default_zoom_level
	
	# Calculate scale first (needed for centering calculation)
	map_center = size / 2.0
	_calculate_scale()
	
	# Center on player ship
	if ship and is_instance_valid(ship) and generator and generator.generated_sun:
		var sun_pos = generator.generated_sun.global_position
		var relative_pos = ship.global_position - sun_pos
		# Pan offset should position ship at map center
		# Ship map pos = map_center + pan_offset + relative_pos * scale_factor
		# To center ship: map_center = map_center + pan_offset + relative_pos * scale_factor
		# Therefore: pan_offset = -relative_pos * scale_factor
		pan_offset = -relative_pos * scale_factor
		# Clamp pan offset to valid bounds
		pan_offset = _clamp_pan_offset(pan_offset)
	else:
		# Fallback: center on sun if ship not available
		pan_offset = Vector2.ZERO
	
	visible = true

func close_map() -> void:
	visible = false
	map_closed.emit()

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
	if not generator or generator.generated_planets.is_empty():
		return offset
	
	# Calculate system bounds
	var max_distance: float = 0.0
	for planet in generator.generated_planets:
		if planet and is_instance_valid(planet):
			max_distance = max(max_distance, planet.orbital_distance)
	
	# Add margin for planet size
	max_distance += 20000.0
	
	# Calculate system radius in screen space at current zoom
	var system_radius = max_distance * scale_factor
	
	# Calculate screen half-size
	var half_size = size / 2.0
	
	# Calculate maximum pan offset
	# Pan offset is clamped so system edges don't go past screen edges
	# System extends from (map_center + pan_offset) - system_radius to (map_center + pan_offset) + system_radius
	# Screen extends from 0 to size
	# Constraint: (map_center + pan_offset) - system_radius >= 0  and  (map_center + pan_offset) + system_radius <= size
	# Since map_center = size/2: pan_offset >= system_radius - size/2  and  pan_offset <= size/2 - system_radius
	# So: -max_pan <= pan_offset <= max_pan where max_pan = size/2 - system_radius
	
	var max_pan_x = half_size.x - system_radius
	var max_pan_y = half_size.y - system_radius
	
	# Only clamp if system is larger than screen (max_pan would be negative)
	if max_pan_x < 0.0 or max_pan_y < 0.0:
		return Vector2(
			clamp(offset.x, max_pan_x, -max_pan_x),
			clamp(offset.y, max_pan_y, -max_pan_y)
		)
	
	# System fits on screen, allow free panning (though it won't move much)
	return offset

func _zoom_in() -> void:
	zoom_level = clamp(zoom_level * zoom_speed, min_zoom_level, max_zoom_level)
	scale_factor = base_scale_factor * zoom_level
	# Reclamp pan offset after zoom change
	pan_offset = _clamp_pan_offset(pan_offset)

func _zoom_out() -> void:
	zoom_level = clamp(zoom_level / zoom_speed, min_zoom_level, max_zoom_level)
	scale_factor = base_scale_factor * zoom_level
	# Reclamp pan offset after zoom change
	pan_offset = _clamp_pan_offset(pan_offset)

func _draw() -> void:
	if not generator or not generator.generated_sun:
		return
	
	# Calculate map center and scale
	map_center = size / 2.0
	_calculate_scale()
	
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	
	# Draw border
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 2.0)
	
	# Draw grid rings
	# _draw_grid()
	
	# Draw orbital paths (planets around sun)
	_draw_orbits()
	
	# Draw moon orbital paths (moons around planets)
	_draw_moon_orbits()
	
	# Draw sun
	_draw_sun()
	
	# Draw planets
	_draw_planets()
	
	# Draw ship
	_draw_ship()
	
	# Draw title
	_draw_title()

func _calculate_scale() -> void:
	if generator.generated_planets.is_empty():
		base_scale_factor = 0.1
		scale_factor = base_scale_factor * zoom_level
		return
	
	# Find the outermost planet's orbital distance
	var max_distance: float = 0.0
	for planet in generator.generated_planets:
		if planet and is_instance_valid(planet):
			max_distance = max(max_distance, planet.orbital_distance)
	
	# Add some extra for the planet itself and margin
	max_distance += 1000.0
	
	# Calculate base scale to fit in the smaller dimension
	var available_size = min(size.x, size.y) - padding * 2
	base_scale_factor = available_size / (max_distance * 2.0)
	
	# Apply zoom level
	scale_factor = base_scale_factor * zoom_level

func _draw_grid() -> void:
	if generator.generated_planets.is_empty():
		return
	
	# Find max distance for grid
	var max_distance: float = 0.0
	for planet in generator.generated_planets:
		if planet and is_instance_valid(planet):
			max_distance = max(max_distance, planet.orbital_distance)
	
	# Draw concentric rings
	for i in range(1, grid_ring_count + 1):
		var ring_distance = max_distance * (float(i) / float(grid_ring_count))
		var ring_radius = ring_distance * scale_factor
		draw_arc(map_center, ring_radius, 0, TAU, 64, grid_color, 1.0)

func _draw_orbits() -> void:
	var orbit_center = map_center + pan_offset
	
	for planet in generator.generated_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		# Only draw orbits for planets orbiting the sun
		# Planets orbiting the sun have parent_planet == generated_sun (or null for backwards compatibility)
		# Moons have parent_planet == a planet (not the sun)
		if planet.parent_planet and planet.parent_planet != generator.generated_sun:
			continue
		
		var orbit_radius = planet.orbital_distance * scale_factor
		
		# Draw orbit path (dotted effect using segments)
		var segments = 64
		var segment_gap = 4  # Every nth segment is skipped for dotted effect
		for j in range(segments):
			if j % segment_gap == 0:
				continue
			var angle_start = (float(j) / float(segments)) * TAU
			var angle_end = (float(j + 1) / float(segments)) * TAU
			draw_arc(orbit_center, orbit_radius, angle_start, angle_end, 2, orbit_color, 1.0)

func _draw_moon_orbits() -> void:
	var orbit_center = map_center + pan_offset
	var moon_count = 0
	
	for planet in generator.generated_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		# Only draw orbits for moons (planets with a parent that is not the sun)
		if not planet.parent_planet or planet.parent_planet == generator.generated_sun:
			continue
		
		moon_count += 1
		
		# Calculate parent planet's current position (same logic as _draw_planets)
		var parent_orbit_radius = planet.parent_planet.orbital_distance * scale_factor
		var parent_angle = planet.parent_planet.orbital_angle if "orbital_angle" in planet.parent_planet else atan2(planet.parent_planet.position.y, planet.parent_planet.position.x)
		var parent_map_pos = orbit_center + Vector2(cos(parent_angle), sin(parent_angle)) * parent_orbit_radius
		
		# Draw moon orbit around parent planet
		var moon_orbit_radius = planet.orbital_distance * scale_factor
		
		# Ensure minimum visibility - if too small, use a minimum radius
		var min_visible_radius = 5.0  # Minimum pixels for visibility
		if moon_orbit_radius < min_visible_radius:
			moon_orbit_radius = min_visible_radius
		
		# Draw orbit path as a full circle (moons are small so use solid circle)
		draw_arc(parent_map_pos, moon_orbit_radius, 0.0, TAU, 64, moon_orbit_color, 1.5)

func _draw_sun() -> void:
	var sun = generator.generated_sun
	if not sun or not is_instance_valid(sun):
		return
	
	# Scale sun size based on actual radius and zoom level, with adjustable multiplier
	var scaled_sun_size = sun.radius * scale_factor * sun_size_multiplier
	
	# Draw sun at center with pan offset
	var sun_pos = map_center + pan_offset
	draw_circle(sun_pos, scaled_sun_size, sun.color)

func _draw_planets() -> void:
	var orbit_center = map_center + pan_offset
	
	for planet in generator.generated_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		var map_pos: Vector2
		
		# Check if this is a moon (has a parent planet that is not the sun)
		if planet.parent_planet and planet.parent_planet != generator.generated_sun:
			# Moon: calculate position relative to parent planet
			# First get parent planet's current position
			var parent_orbit_radius = planet.parent_planet.orbital_distance * scale_factor
			var parent_angle = planet.parent_planet.orbital_angle if "orbital_angle" in planet.parent_planet else atan2(planet.parent_planet.position.y, planet.parent_planet.position.x)
			var parent_map_pos = orbit_center + Vector2(cos(parent_angle), sin(parent_angle)) * parent_orbit_radius
			
			# Then add moon's orbital offset relative to parent
			var moon_orbit_radius = planet.orbital_distance * scale_factor
			var moon_angle = planet.orbital_angle if "orbital_angle" in planet else atan2(planet.position.y, planet.position.x)
			map_pos = parent_map_pos + Vector2(cos(moon_angle), sin(moon_angle)) * moon_orbit_radius
		else:
			# Planet orbiting sun: use actual orbital_angle for alignment with orbit path
			var orbit_radius = planet.orbital_distance * scale_factor
			var angle = planet.orbital_angle if "orbital_angle" in planet else atan2(planet.position.y, planet.position.x)
			map_pos = orbit_center + Vector2(cos(angle), sin(angle)) * orbit_radius
		
		# Calculate planet size based on actual radius and zoom level, with adjustable multiplier
		var planet_size = planet.radius * scale_factor * planet_size_multiplier
		
		# Draw planet
		draw_circle(map_pos, planet_size, planet.color)
		
		# Draw planet outline
		draw_arc(map_pos, planet_size, 0, TAU, 32, border_color, 1.0)

func _draw_ship() -> void:
	if not ship or not is_instance_valid(ship):
		return
	
	# Get ship position relative to sun (which is at origin)
	var sun_pos = generator.generated_sun.global_position if generator.generated_sun else Vector2.ZERO
	var relative_pos = ship.global_position - sun_pos
	var map_pos = map_center + pan_offset + relative_pos * scale_factor
	
	# Draw ship as triangle
	var points = PackedVector2Array()
	# Triangle points UP at angle 0, but ship rotation 0 = RIGHT, so add PI/2
	var angle = ship.global_rotation + PI/2
	var base_points = [
		Vector2(0, -ship_size),
		Vector2(-ship_size * 0.7, ship_size * 0.5),
		Vector2(ship_size * 0.7, ship_size * 0.5)
	]
	
	for point in base_points:
		points.append(map_pos + point.rotated(angle))
	
	draw_polygon(points, PackedColorArray([ship_color, ship_color, ship_color]))

func _draw_title() -> void:
	var font = ThemeDB.fallback_font
	var font_size = 16
	var title = "SYSTEM MAP"
	var title_pos = Vector2(size.x / 2 - 50, 30)
	draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, border_color)
	
	# Draw hints
	var hint_color = Color(border_color, 0.6)
	var hint_y = size.y - 50
	var hint_font_size = 12
	
	# Zoom controls
	var zoom_hint = "+/-: Zoom"
	var zoom_hint_pos = Vector2(size.x / 2 - 100, hint_y)
	draw_string(font, zoom_hint_pos, zoom_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, hint_font_size, hint_color)
	
	# Pan controls
	var pan_hint = "Arrow Keys/WASD: Pan"
	var pan_hint_pos = Vector2(size.x / 2 - 100, hint_y + 18)
	draw_string(font, pan_hint_pos, pan_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, hint_font_size, hint_color)
	
	# Close controls
	var close_hint = "M/ESC: Close"
	var close_hint_pos = Vector2(size.x / 2 - 50, hint_y + 36)
	draw_string(font, close_hint_pos, close_hint, HORIZONTAL_ALIGNMENT_CENTER, -1, hint_font_size, hint_color)
