extends Control
class_name SystemMap

## Fullscreen solar system map showing all planets, sun, and orbital paths.

signal map_closed

@export_group("Colors")
@export var background_color: Color = Colors.UI_BACKGROUND
@export var border_color: Color = Colors.UI_BORDER
@export var grid_color: Color = Colors.PRIMARY_SUBTLE
@export var orbit_color: Color = Colors.PRIMARY_FADED
@export var moon_orbit_color: Color = Colors.MOON_ORBIT
@export var space_station_orbit_color: Color = Colors.MOON_ORBIT
@export var sun_color: Color = Colors.SUN
@export var ship_color: Color = Colors.PRIMARY
@export var space_station_color: Color = Color(0.6, 0.6, 0.7, 1.0)

@export_group("Display")
@export var padding: float = 80.0  ## Padding from screen edges
@export var planet_size_multiplier: float = 1.0  ## Multiplier for planet size (0.5 = half actual size for visibility)
@export var sun_size_multiplier: float = 1.0  ## Multiplier for sun size
@export var ship_size: float = 8.0  ## Ship indicator size
@export var grid_ring_count: int = 5  ## Number of grid rings

@export_group("Zoom and Pan")
@export var default_zoom_level: float = 5.0  ## Default zoom multiplier (1.5x = zoomed in)
@export var min_zoom_level: float = 3.0  ## Minimum zoom level
@export var max_zoom_level: float = 50.0  ## Maximum zoom level
@export var zoom_speed: float = 1.5  ## Zoom multiplier per key press
@export var pan_speed: float = 500.0  ## Pixels per second panning speed

var sun: Planet = null
var planets: Array[Planet] = []
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
	_find_celestial_bodies()
	ship = get_tree().get_first_node_in_group("ship") as Ship

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
	# Refresh references
	_find_celestial_bodies()
	if not ship:
		ship = get_tree().get_first_node_in_group("ship") as Ship
	
	# Initialize zoom level on first open, otherwise preserve it
	if zoom_level == 0.0 or zoom_level < min_zoom_level:
		zoom_level = default_zoom_level
	
	# Calculate scale first (needed for centering calculation)
	map_center = size / 2.0
	_calculate_scale()
	
	# Center on player ship
	if ship and is_instance_valid(ship) and sun:
		var sun_pos = sun.global_position
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
	if planets.is_empty():
		return offset
	
	# Calculate system bounds
	var max_distance: float = 0.0
	for planet in planets:
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
	# Re-center on player after zoom change
	_center_on_player()

func _zoom_out() -> void:
	zoom_level = clamp(zoom_level / zoom_speed, min_zoom_level, max_zoom_level)
	scale_factor = base_scale_factor * zoom_level
	# Re-center on player after zoom change
	_center_on_player()

func _center_on_player() -> void:
	# Center on player ship
	if ship and is_instance_valid(ship) and sun:
		var sun_pos = sun.global_position
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

func _draw() -> void:
	if not sun:
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
	
	# Draw space station orbital paths (stations around planets)
	_draw_space_station_orbits()
	
	# Draw sun
	_draw_sun()
	
	# Draw planets
	_draw_planets()
	
	# Draw space stations
	_draw_space_stations()
	
	# Draw ship
	_draw_ship()
	
	# Draw title
	_draw_title()

func _calculate_scale() -> void:
	if planets.is_empty():
		base_scale_factor = 0.1
		scale_factor = base_scale_factor * zoom_level
		return
	
	# Find the outermost planet's orbital distance
	var max_distance: float = 0.0
	for planet in planets:
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
	if planets.is_empty():
		return
	
	# Find max distance for grid
	var max_distance: float = 0.0
	for planet in planets:
		if planet and is_instance_valid(planet):
			max_distance = max(max_distance, planet.orbital_distance)
	
	# Draw concentric rings
	for i in range(1, grid_ring_count + 1):
		var ring_distance = max_distance * (float(i) / float(grid_ring_count))
		var ring_radius = ring_distance * scale_factor
		draw_arc(map_center, ring_radius, 0, TAU, 64, grid_color, 1.0)

func _draw_orbits() -> void:
	var orbit_center = map_center + pan_offset
	
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		# Only draw orbits for planets orbiting the sun
		# Planets orbiting the sun have parent_planet == sun (or null for backwards compatibility)
		# Moons have parent_planet == a planet (not the sun)
		if planet.parent_planet and planet.parent_planet != sun:
			continue
		
		var a = planet.orbital_distance  # semi-major axis
		var e = clamp(planet.eccentricity, 0.0, 0.99) if "eccentricity" in planet else 0.0
		
		# Draw orbit path (dotted effect using segments)
		var segments = 64
		var segment_gap = 4  # Every nth segment is skipped for dotted effect
		
		for j in range(segments):
			if j % segment_gap == 0:
				continue
			
			var angle_start = (float(j) / float(segments)) * TAU
			var angle_end = (float(j + 1) / float(segments)) * TAU
			
			if e == 0.0:
				# Circular orbit - use simple arc
				var orbit_radius = a * scale_factor
				draw_arc(orbit_center, orbit_radius, angle_start, angle_end, 2, orbit_color, 1.0)
			else:
				# Elliptical orbit - draw line segment following the ellipse
				# r = a * (1 - e²) / (1 + e * cos(θ))
				var r_start = a * (1.0 - e * e) / (1.0 + e * cos(angle_start))
				var r_end = a * (1.0 - e * e) / (1.0 + e * cos(angle_end))
				
				var pos_start = orbit_center + Vector2(cos(angle_start), sin(angle_start)) * r_start * scale_factor
				var pos_end = orbit_center + Vector2(cos(angle_end), sin(angle_end)) * r_end * scale_factor
				
				draw_line(pos_start, pos_end, orbit_color, 1.0)

func _draw_moon_orbits() -> void:
	var sun_pos = sun.global_position if sun else Vector2.ZERO
	
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		# Only draw orbits for moons (planets with a parent that is not the sun)
		if not planet.parent_planet or planet.parent_planet == sun:
			continue
		
		# Get parent planet's actual position on the map
		var parent_relative_pos = planet.parent_planet.global_position - sun_pos
		var parent_map_pos = map_center + pan_offset + parent_relative_pos * scale_factor
		
		var a = planet.orbital_distance  # semi-major axis
		var e = clamp(planet.eccentricity, 0.0, 0.99) if "eccentricity" in planet else 0.0
		
		# Ensure minimum visibility
		var min_visible_radius = 5.0  # Minimum pixels for visibility
		
		# Draw dashed orbit (dash pattern: draw 3 segments, skip 2)
		var segments = 96  # More segments for smoother dashed effect
		var dash_length = 3  # Number of segments per dash
		var gap_length = 2   # Number of segments per gap
		
		if e == 0.0:
			# Circular orbit - draw dashed arc
			var moon_orbit_radius = a * scale_factor
			if moon_orbit_radius < min_visible_radius:
				moon_orbit_radius = min_visible_radius
			
			var segment_angle = TAU / float(segments)
			var dash_angle = segment_angle * dash_length
			var gap_angle = segment_angle * gap_length
			
			var current_angle = 0.0
			while current_angle < TAU:
				var dash_end_angle = min(current_angle + dash_angle, TAU)
				draw_arc(parent_map_pos, moon_orbit_radius, current_angle, dash_end_angle, 8, moon_orbit_color, 1.5)
				current_angle += dash_angle + gap_angle
		else:
			# Elliptical orbit - draw dashed line segments following the ellipse
			var segment_angle = TAU / float(segments)
			var dash_angle = segment_angle * dash_length
			var gap_angle = segment_angle * gap_length
			
			var current_angle = 0.0
			while current_angle < TAU:
				var dash_end_angle = min(current_angle + dash_angle, TAU)
				
				# Draw dash segment
				var dash_segments = int((dash_end_angle - current_angle) / segment_angle) + 1
				for j in range(dash_segments):
					var angle_start = current_angle + (float(j) / float(dash_segments)) * (dash_end_angle - current_angle)
					var angle_end = current_angle + (float(j + 1) / float(dash_segments)) * (dash_end_angle - current_angle)
					
					if angle_end > TAU:
						angle_end = TAU
					if angle_start >= TAU:
						break
					
					var r_start = a * (1.0 - e * e) / (1.0 + e * cos(angle_start))
					var r_end = a * (1.0 - e * e) / (1.0 + e * cos(angle_end))
					
					# Scale to screen space with minimum visibility
					var screen_r_start = max(r_start * scale_factor, min_visible_radius)
					var screen_r_end = max(r_end * scale_factor, min_visible_radius)
					
					var pos_start = parent_map_pos + Vector2(cos(angle_start), sin(angle_start)) * screen_r_start
					var pos_end = parent_map_pos + Vector2(cos(angle_end), sin(angle_end)) * screen_r_end
					
					draw_line(pos_start, pos_end, moon_orbit_color, 1.5)
				
				current_angle += dash_angle + gap_angle

func _draw_space_station_orbits() -> void:
	var sun_pos = sun.global_position if sun else Vector2.ZERO
	
	# Get all space stations from the scene tree
	var space_stations = get_tree().get_nodes_in_group("space_stations")
	
	for station in space_stations:
		if not station or not is_instance_valid(station):
			continue
		
		var station_node = station as SpaceStation
		if not station_node:
			continue
		
		# Only draw orbits for stations that have a parent planet
		if not station_node.parent_planet:
			continue
		
		# Get parent planet's actual position on the map
		var parent_relative_pos = station_node.parent_planet.global_position - sun_pos
		var parent_map_pos = map_center + pan_offset + parent_relative_pos * scale_factor
		
		var a = station_node.orbital_distance  # semi-major axis
		var e = clamp(station_node.eccentricity, 0.0, 0.99) if "eccentricity" in station_node else 0.0
		
		# Ensure minimum visibility
		var min_visible_radius = 5.0  # Minimum pixels for visibility
		
		# Draw dashed orbit (same style as moon orbits)
		var segments = 96  # More segments for smoother dashed effect
		var dash_length = 3  # Number of segments per dash
		var gap_length = 2   # Number of segments per gap
		
		if e == 0.0:
			# Circular orbit - draw dashed arc
			var station_orbit_radius = a * scale_factor
			if station_orbit_radius < min_visible_radius:
				station_orbit_radius = min_visible_radius
			
			var segment_angle = TAU / float(segments)
			var dash_angle = segment_angle * dash_length
			var gap_angle = segment_angle * gap_length
			
			var current_angle = 0.0
			while current_angle < TAU:
				var dash_end_angle = min(current_angle + dash_angle, TAU)
				draw_arc(parent_map_pos, station_orbit_radius, current_angle, dash_end_angle, 8, space_station_orbit_color, 1.5)
				current_angle += dash_angle + gap_angle
		else:
			# Elliptical orbit - draw dashed line segments following the ellipse
			var segment_angle = TAU / float(segments)
			var dash_angle = segment_angle * dash_length
			var gap_angle = segment_angle * gap_length
			
			var current_angle = 0.0
			while current_angle < TAU:
				var dash_end_angle = min(current_angle + dash_angle, TAU)
				
				# Draw dash segment
				var dash_segments = int((dash_end_angle - current_angle) / segment_angle) + 1
				for j in range(dash_segments):
					var angle_start = current_angle + (float(j) / float(dash_segments)) * (dash_end_angle - current_angle)
					var angle_end = current_angle + (float(j + 1) / float(dash_segments)) * (dash_end_angle - current_angle)
					
					if angle_end > TAU:
						angle_end = TAU
					if angle_start >= TAU:
						break
					
					var r_start = a * (1.0 - e * e) / (1.0 + e * cos(angle_start))
					var r_end = a * (1.0 - e * e) / (1.0 + e * cos(angle_end))
					
					# Scale to screen space with minimum visibility
					var screen_r_start = max(r_start * scale_factor, min_visible_radius)
					var screen_r_end = max(r_end * scale_factor, min_visible_radius)
					
					var pos_start = parent_map_pos + Vector2(cos(angle_start), sin(angle_start)) * screen_r_start
					var pos_end = parent_map_pos + Vector2(cos(angle_end), sin(angle_end)) * screen_r_end
					
					draw_line(pos_start, pos_end, space_station_orbit_color, 1.5)
				
				current_angle += dash_angle + gap_angle

func _draw_space_stations() -> void:
	var sun_pos = sun.global_position if sun else Vector2.ZERO
	
	# Get all space stations from the scene tree
	var space_stations = get_tree().get_nodes_in_group("space_stations")
	
	for station in space_stations:
		if not station or not is_instance_valid(station):
			continue
		
		var station_node = station as SpaceStation
		if not station_node:
			continue
		
		# Use actual global_position relative to sun (same as ship positioning)
		var relative_pos = station_node.global_position - sun_pos
		var map_pos = map_center + pan_offset + relative_pos * scale_factor
		
		# Calculate station size (use a fixed size since stations don't have a radius property)
		# Stations are moon-sized, so use a reasonable size
		var station_size = 1200.0 * scale_factor * planet_size_multiplier
		
		# Draw station as a square/diamond shape to distinguish from planets
		var points = PackedVector2Array([
			Vector2(0, -station_size),  # Top
			Vector2(station_size, 0),   # Right
			Vector2(0, station_size),   # Bottom
			Vector2(-station_size, 0)   # Left
		])
		
		# Rotate 45 degrees to make it a diamond
		var rotated_points = PackedVector2Array()
		for point in points:
			rotated_points.append(map_pos + point.rotated(PI / 4))
		
		draw_polygon(rotated_points, PackedColorArray([space_station_color, space_station_color, space_station_color, space_station_color]))
		
		# Draw station outline
		draw_polyline(rotated_points, border_color, 1.0, true)

func _draw_sun() -> void:
	if not sun or not is_instance_valid(sun):
		return
	
	# Scale sun size based on actual radius and zoom level, with adjustable multiplier
	var scaled_sun_size = sun.radius * scale_factor * sun_size_multiplier
	
	# Draw sun at center with pan offset
	var sun_pos = map_center + pan_offset
	draw_circle(sun_pos, scaled_sun_size, sun.color)

func _draw_planets() -> void:
	var sun_pos = sun.global_position if sun else Vector2.ZERO
	
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		# Use actual global_position relative to sun (same as ship positioning)
		var relative_pos = planet.global_position - sun_pos
		var map_pos = map_center + pan_offset + relative_pos * scale_factor
		
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
	var sun_pos = sun.global_position if sun else Vector2.ZERO
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
