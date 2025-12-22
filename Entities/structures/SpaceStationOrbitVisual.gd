extends Node2D
class_name SpaceStationOrbitVisual

## OrbitVisual for SpaceStation entities.

var station: SpaceStation = null
@export var show_orbit: bool = true : set = _set_show_orbit
@export var orbit_color: Color = Color(0.2, 0.5, 1.0, 0.3) : set = _set_orbit_color
@export var orbit_width: float = 2.0 : set = _set_orbit_width

func _ready() -> void:
	# Find parent SpaceStation by traversing up the tree
	var current = get_parent()
	while current:
		if current is SpaceStation:
			station = current as SpaceStation
			break
		current = current.get_parent()
	set_process(true)

func _process(_delta: float) -> void:
	# Redraw orbit as station moves
	if show_orbit and station and station.parent_planet:
		queue_redraw()

func _set_show_orbit(v: bool) -> void:
	show_orbit = v
	queue_redraw()

func _set_orbit_color(c: Color) -> void:
	orbit_color = c
	queue_redraw()

func _set_orbit_width(v: float) -> void:
	orbit_width = max(0.0, v)
	queue_redraw()

func _draw() -> void:
	if not show_orbit or not station:
		return
	
	# Only draw if station is orbiting (has a parent planet)
	if not station.parent_planet:
		return
	
	var orbital_distance = station.orbital_distance
	var eccentricity = station.eccentricity
	
	# Parent planet position in orbiting station's local space
	# Since orbiting station's position is the orbital offset, parent is at -position
	var parent_pos = -station.position
	
	if eccentricity == 0.0:
		# Circular orbit: draw circle
		draw_arc(parent_pos, orbital_distance, 0.0, TAU, 96, orbit_color, orbit_width)
	else:
		# Elliptical orbit: sample points and draw connected arcs
		var a = orbital_distance  # semi-major axis
		var e = clamp(eccentricity, 0.0, 0.99)
		var num_points = 96
		
		var points: PackedVector2Array = []
		for i in range(num_points + 1):
			var angle = (float(i) / float(num_points)) * TAU
			var r = a * (1.0 - e * e) / (1.0 + e * cos(angle))
			var point = parent_pos + Vector2(cos(angle), sin(angle)) * r
			points.append(point)
		
		# Draw the ellipse as connected line segments
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], orbit_color, orbit_width)

