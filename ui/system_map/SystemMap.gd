extends Control
class_name SystemMap

## Fullscreen solar system map showing all planets, sun, and orbital paths.

signal map_closed

@export_group("Colors")
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.9)
@export var border_color: Color = Color(1.0, 0.75, 0.0, 1.0)  # Amber
@export var grid_color: Color = Color(1.0, 0.75, 0.0, 0.15)  # Faded amber
@export var orbit_color: Color = Color(1.0, 0.75, 0.0, 0.4)  # Orbit path color
@export var sun_color: Color = Color(1.0, 0.9, 0.5, 1.0)  # Yellow-ish
@export var ship_color: Color = Color(1.0, 0.75, 0.0, 1.0)  # Amber

@export_group("Display")
@export var padding: float = 80.0  ## Padding from screen edges
@export var min_planet_size: float = 4.0  ## Minimum planet dot size
@export var max_planet_size: float = 20.0  ## Maximum planet dot size
@export var sun_size: float = 25.0  ## Sun dot size
@export var ship_size: float = 8.0  ## Ship indicator size
@export var grid_ring_count: int = 5  ## Number of grid rings

var generator: SolarSystemGenerator = null
var ship: Ship = null
var scale_factor: float = 1.0
var map_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Find references
	generator = get_tree().get_first_node_in_group("solar_system_generator") as SolarSystemGenerator
	ship = get_tree().get_first_node_in_group("ship") as Ship

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Close on M or Escape
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M or event.keycode == KEY_ESCAPE:
			close_map()
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
	
	visible = true

func close_map() -> void:
	visible = false
	map_closed.emit()

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
	
	# Draw orbital paths
	_draw_orbits()
	
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
		scale_factor = 0.1
		return
	
	# Find the outermost planet's orbital distance
	var max_distance: float = 0.0
	for planet in generator.generated_planets:
		if planet and is_instance_valid(planet):
			max_distance = max(max_distance, planet.orbital_distance)
	
	# Add some extra for the planet itself and margin
	max_distance += 1000.0
	
	# Calculate scale to fit in the smaller dimension
	var available_size = min(size.x, size.y) - padding * 2
	scale_factor = available_size / (max_distance * 2.0)

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
	for planet in generator.generated_planets:
		if not planet or not is_instance_valid(planet):
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
			draw_arc(map_center, orbit_radius, angle_start, angle_end, 2, orbit_color, 1.0)

func _draw_sun() -> void:
	var sun = generator.generated_sun
	if not sun or not is_instance_valid(sun):
		return
	
	# Scale sun size based on actual radius, with min/max limits
	var scaled_sun_size = clamp(sun.radius * scale_factor, sun_size * 0.5, sun_size * 2.0)
	
	# Draw sun
	draw_circle(map_center, scaled_sun_size, sun.color)

func _draw_planets() -> void:
	for planet in generator.generated_planets:
		if not planet or not is_instance_valid(planet):
			continue
		
		# Calculate planet position on orbit circle (ignoring eccentricity for display)
		# Use the orbital_distance and current orbital_angle
		var orbit_radius = planet.orbital_distance * scale_factor
		var angle = planet.orbital_angle if "orbital_angle" in planet else atan2(planet.position.y, planet.position.x)
		var map_pos = map_center + Vector2(cos(angle), sin(angle)) * orbit_radius
		
		# Calculate planet size (scaled but clamped)
		var planet_size = clamp(planet.radius * scale_factor * 0.5, min_planet_size, max_planet_size)
		
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
	var map_pos = map_center + relative_pos * scale_factor
	
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
	
	# Draw hint
	var hint = "Press M or ESC to close"
	var hint_pos = Vector2(size.x / 2 - 80, size.y - 20)
	draw_string(font, hint_pos, hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(border_color, 0.6))
