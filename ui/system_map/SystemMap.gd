extends Control
class_name SystemMap

## Star chart, carried in the Log's MAP tab (ui/log/MapTab.gd): a terminal frame that
## expands open from the middle, and a clipped chart view holding the sun, orbits,
## planets, stations, the ship reticle and the current nav target. It fills whatever
## rect its parent gives it; the Log owns the backdrop, the window and the key hint.
##
## The arrow keys drive a mark across the chart; ENTER hands it to the NavSystem,
## either as the body it has locked onto or as a fixed waypoint out in the black.

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
## How close the mark has to be, on screen, to lock onto a body instead of bare space.
const CURSOR_SNAP_PX := 14.0
## How far the mark stays clear of the chart edge before the view scrolls after it.
const CURSOR_EDGE_MARGIN := 26.0
## Seconds the confirm pulse takes to fade after a tracking point is set.
const MARK_FLASH_TIME := 0.5
## A freshly Charted region draws itself in rather than appearing: how long one piece
## of it takes, and the head start each piece has over the next.
const REVEAL_TIME := 0.9
const REVEAL_STAGGER := 0.15
## The powered Gate's glyph: a small ring with the same mouth the Gate itself leaves open.
const GATE_GLYPH_RADIUS := 5.0
const GATE_MOUTH := deg_to_rad(52.0)
## How far apart two Gates have to read on screen before the link between them is worth drawing.
const GATE_LINK_MIN_PX := 6.0
## How far below its own line a Gate's name sits, clear of the planet's name beside it.
const GATE_LABEL_DROP := 9.0

## The order the pieces of a Charted region arrive in, outwards from the planet.
enum Reveal { PLANET, ORBIT, MOON, STATION, GATE }
## How long a whole region takes to arrive: the last piece's head start plus its own ramp.
const REVEAL_SPAN := REVEAL_TIME + REVEAL_STAGGER * float(Reveal.GATE)

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
@export var gate_color: Color = Colors.TITAN
@export var freight_color: Color = Colors.PRIMARY
@export var void_color: Color = Colors.DANGER

@export_group("Display")
@export var padding: float = 44.0  ## Gap between the frame and the outermost orbit
@export var planet_size_multiplier: float = 1.0  ## Multiplier for planet size (0.5 = half actual size for visibility)
@export var sun_size_multiplier: float = 1.0  ## Multiplier for sun size
@export var ship_size: float = 8.0  ## Ship indicator size

@export_group("Zoom and Pan")
@export var default_zoom_level: float = 25.0  ## Default zoom multiplier
@export var min_zoom_level: float = 1.0  ## Minimum zoom level (1.0 fits the whole system)
@export var max_zoom_level: float = 50.0  ## Maximum zoom level
@export var zoom_speed: float = 1.5  ## Zoom multiplier per key press
@export var pan_speed: float = 500.0  ## Pixels per second panning speed
@export var cursor_speed: float = 420.0  ## Pixels per second the mark travels across the chart

var sun: Planet = null
var planets: Array[Planet] = []
var ship: Ship = null
var base_scale_factor: float = 1.0  ## Original auto-calculated scale
var scale_factor: float = 1.0  ## Current scale (base_scale_factor * zoom_level)
var map_center: Vector2 = Vector2.ZERO  ## Chart-local center of the view
var zoom_level: float = 0.0  ## Current zoom multiplier (0 until the first open; preserved after)
var pan_offset: Vector2 = Vector2.ZERO  ## Current pan offset from center
var cursor_world: Vector2 = Vector2.ZERO  ## World position the mark sits on

var _chart: ChartCanvas
var _chrome: ChromeCanvas
var _font: Font
var _frame_rect: Rect2 = Rect2()
var _anim: float = 0.0  ## 0 = closed, 1 = fully open
var _anim_dir: int = 0  ## +1 opening, 0 settled
var _time: float = 0.0
var _stars: PackedVector2Array = PackedVector2Array()  ## Unit-square star positions
var _star_alpha: PackedFloat32Array = PackedFloat32Array()
var _mark_flash: float = 0.0  ## 1 -> 0 confirm pulse after a tracking point is set
## Regions the chart has already drawn, keyed by the region planet's save_key(), and
## how far into its reveal each newly Charted one is.
var _charted_known: Dictionary = {}
var _reveals: Dictionary = {}
var _primed: bool = false  ## Whether the saved Modules have been taken as already drawn
var _game_state: GameState = null

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("system_map")
	_font = get_theme_default_font()

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
	resized.connect(_on_resized)

	# Find references
	_find_celestial_bodies()
	ship = get_tree().get_first_node_in_group("ship") as Ship

	# Modules already online when the world loads are simply on the chart; only ones
	# powered from here on get the staged reveal.
	EventBus.planets_restored.connect(_prime_charted)

func _build_starfield() -> void:
	# One fixed field so the chart backdrop is stable between openings.
	var rng := RandomNumberGenerator.new()
	rng.seed = STARFIELD_SEED
	for _i in range(STAR_COUNT):
		_stars.append(Vector2(rng.randf(), rng.randf()))
		_star_alpha.append(rng.randf_range(0.05, 0.22))

func _layout() -> void:
	_frame_rect = Rect2(Vector2.ZERO, size.floor())

	_chrome.position = _frame_rect.position
	_chrome.size = _frame_rect.size

	var inset := Vector2.ONE * BORDER_WIDTH
	_chart.position = _frame_rect.position + inset
	_chart.size = _frame_rect.size - inset * 2.0
	_chart.pivot_offset = _chart.size / 2.0
	map_center = _chart.size / 2.0

## The Log's container sizes the chart a beat after the tab first shows, so the fit
## and the centring are taken again once the real size arrives.
func _on_resized() -> void:
	_layout()
	if visible:
		_calculate_scale()
		_refocus()
		_reset_cursor()

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
	if not visible:
		return

	_time += delta
	_advance_anim(delta)
	_handle_panning(delta)
	_calculate_scale()
	_handle_cursor(delta)
	_advance_reveals(delta)
	_mark_flash = maxf(_mark_flash - delta / MARK_FLASH_TIME, 0.0)
	_chart.queue_redraw()
	_chrome.queue_redraw()

func _advance_anim(delta: float) -> void:
	if _anim_dir > 0:
		_anim = minf(_anim + delta / OPEN_TIME, 1.0)
		if is_equal_approx(_anim, 1.0):
			_anim_dir = 0

	# The frame draws itself on first, then the chart fades up and settles into place.
	var chart_t := _ease_out(clampf((_anim - 0.35) / 0.65, 0.0, 1.0))
	_chart.modulate.a = chart_t
	_chart.scale = Vector2.ONE * lerpf(0.965, 1.0, chart_t)

## A key the Log handed over while the chart is up. Returns true when the chart takes
## it. The arrows are claimed but polled each frame, so the mark glides while held.
func handle_key(keycode: int) -> bool:
	if not visible:
		return false
	match keycode:
		KEY_PLUS, KEY_EQUAL:
			_zoom_in()
		KEY_MINUS, KEY_UNDERSCORE:
			_zoom_out()
		# Recenter on the ship, bringing the mark back with the view
		KEY_C:
			_center_on_player()
			_reset_cursor()
		# Hand whatever the mark is sitting on to the nav system
		KEY_ENTER, KEY_KP_ENTER:
			_set_tracking_point()
		# Drop the tracking point and fall back to home base
		KEY_DELETE, KEY_BACKSPACE:
			NavSystem.track_home()
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT:
			pass
		_:
			return false
	return true

func open_map() -> void:
	# Refresh references
	_find_celestial_bodies()
	if not ship:
		ship = get_tree().get_first_node_in_group("ship") as Ship

	# Initialize zoom level on first open, otherwise preserve it
	if zoom_level == 0.0 or zoom_level < min_zoom_level:
		zoom_level = default_zoom_level

	# Calculate scale first (needed for centering calculation)
	_refresh_charted()
	_layout()
	_calculate_scale()
	_refocus()
	_reset_cursor()
	_mark_flash = 0.0

	visible = true
	_anim_dir = 1
	_advance_anim(0.0)

## Put away at once: the Log is closing or another tab is taking its place.
func close_map() -> void:
	visible = false
	_anim = 0.0
	_anim_dir = 0

## True while the chart is on screen.
func is_open() -> bool:
	return visible

func _handle_panning(delta: float) -> void:
	var pan_direction = Vector2.ZERO

	# WASD pans the view; the arrow keys belong to the mark
	if Input.is_key_pressed(KEY_D):
		pan_direction.x -= 1.0
	if Input.is_key_pressed(KEY_A):
		pan_direction.x += 1.0
	if Input.is_key_pressed(KEY_S):
		pan_direction.y -= 1.0
	if Input.is_key_pressed(KEY_W):
		pan_direction.y += 1.0

	# Normalize diagonal movement
	if pan_direction.length() > 0:
		pan_direction = pan_direction.normalized()
		var new_pan_offset = pan_offset + pan_direction * pan_speed * delta
		pan_offset = _clamp_pan_offset(new_pan_offset)
		_clamp_cursor_to_view()

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
	_zoom_to(zoom_level * zoom_speed)

func _zoom_out() -> void:
	_zoom_to(zoom_level / zoom_speed)

## Zoom around the mark: whatever it sits on stays put on screen, so the player
## closes in on what they are looking at instead of being yanked to the ship.
func _zoom_to(level: float) -> void:
	var anchor := _map_pos(cursor_world)
	zoom_level = clamp(level, min_zoom_level, max_zoom_level)
	_calculate_scale()
	if is_equal_approx(zoom_level, min_zoom_level):
		# Fully zoomed out always frames the whole system.
		pan_offset = Vector2.ZERO
	else:
		pan_offset = _clamp_pan_offset(pan_offset + (anchor - _map_pos(cursor_world)))
	_clamp_cursor_to_view()

## Opening frames the view on the ship, where the mark starts.
func _refocus() -> void:
	if is_equal_approx(zoom_level, min_zoom_level):
		pan_offset = Vector2.ZERO
	else:
		_center_on_player()
	_clamp_cursor_to_view()

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
	var available_size = maxf(minf(_chart.size.x, _chart.size.y) - padding * 2.0, 1.0)
	base_scale_factor = available_size / (span * 2.0)
	scale_factor = base_scale_factor * zoom_level

# --- The mark ----------------------------------------------------------------

## Arrow keys drive the mark. It crosses the chart at a steady speed whatever the
## zoom, and shoves the view along once it reaches the edge, so the whole system
## is reachable without touching the pan keys.
func _handle_cursor(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if direction == Vector2.ZERO:
		return

	cursor_world += direction.normalized() * cursor_speed * delta / maxf(scale_factor, 0.0001)
	cursor_world = _clamp_cursor_world(cursor_world)
	_scroll_to_cursor()
	_clamp_cursor_to_view()

## The mark starts on the ship, where the player is already looking.
func _reset_cursor() -> void:
	cursor_world = ship.global_position if ship and is_instance_valid(ship) else _sun_pos()
	_clamp_cursor_to_view()

## The mark stays within the charted disc. That still reaches into the void — a
## waypoint out there is a legitimate, if unwise, thing to want.
func _clamp_cursor_world(world_pos: Vector2) -> Vector2:
	var origin := _sun_pos()
	return origin + (world_pos - origin).limit_length(_chart_radius())

## Drag the view after the mark once it runs into the edge of the chart.
func _scroll_to_cursor() -> void:
	var bounds := _cursor_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var at := _map_pos(cursor_world)
	var inside := at.clamp(bounds.position, bounds.end)
	if not at.is_equal_approx(inside):
		pan_offset = _clamp_pan_offset(pan_offset + (inside - at))

## Keep the mark on the chart when the view moves out from under it.
func _clamp_cursor_to_view() -> void:
	var bounds := _cursor_bounds()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var at := _map_pos(cursor_world)
	var inside := at.clamp(bounds.position, bounds.end)
	if not at.is_equal_approx(inside):
		cursor_world = _unmap_pos(inside)

func _cursor_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, _chart.size).grow(-CURSOR_EDGE_MARGIN)

## ENTER: hand the mark to the nav system. A body under it is tracked as a body,
## so the marker rides the orbit; bare space becomes a fixed waypoint.
func _set_tracking_point() -> void:
	var body := _snap_body()
	if body == null:
		NavSystem.track_point(cursor_world)
	else:
		cursor_world = body.global_position
		if body == _home_station():
			NavSystem.track_home()
		else:
			NavSystem.track(NodeTrackingTarget.new(body, _body_label(body), _arrival_radius(body)))
	_mark_flash = 1.0

## The body under the mark, when one is close enough on screen to be what the
## player means by it. Nearest wins, so crowded orbits still resolve.
func _snap_body() -> Node2D:
	var best: Node2D = null
	var best_distance := CURSOR_SNAP_PX
	var at := _map_pos(cursor_world)
	for body in _snap_candidates():
		var distance := _map_pos(body.global_position).distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best

## Everything the mark can lock onto: whatever the chart has Charted, plus the powered
## Gates. An uncharted planet is not on the chart, so the mark passes straight over it —
## the position is still bare space, and a waypoint can be set on it like any other.
func _snap_candidates() -> Array[Node2D]:
	var bodies: Array[Node2D] = []
	if sun and is_instance_valid(sun) and _charted(sun):
		bodies.append(sun)
	for planet in planets:
		if planet and is_instance_valid(planet) and _charted(planet):
			bodies.append(planet)
	for node in get_tree().get_nodes_in_group("space_stations"):
		var station := node as SpaceStation
		if station and is_instance_valid(station) and _charted(station.parent_planet):
			bodies.append(station)
	for gate in _powered_gates():
		bodies.append(gate)
	return bodies

func _body_label(body: Node2D) -> String:
	if body is Planet:
		return (body as Planet).planet_name.to_upper()
	if body is Gate:
		return _gate_label(body as Gate)
	return NavSystem.HOME_LABEL if body == _home_station() else "STATION"

func _home_station() -> Node2D:
	return get_tree().get_first_node_in_group("space_stations") as Node2D

## Close enough to count as arrived: clear of a planet's own bulk, or the same
## short hop home base uses for a station.
static func _arrival_radius(body: Node2D) -> float:
	if body is Planet:
		return maxf((body as Planet).radius * 1.5, 200.0)
	if body is Gate:
		return Gate.RADIUS * 1.5
	return 200.0

# --- Charted regions ---------------------------------------------------------

## The chart is the Titan's own map, handed over one region at a time: powering a
## planet's Gate charts that planet, its orbit, its moons and their orbits, its station
## and the Gate itself (docs/adr/0002). Nothing else is drawn, however close the ship
## has flown to it — the minimap is what covers "what is near me".
##
## Home is the exception. The player's own planet and its station are on the chart from
## the first minute; the orbit that carries them around their planet is not, and arrives
## with that planet's Gate like the rest of the region.

func _game_state_node() -> GameState:
	if _game_state == null or not is_instance_valid(_game_state):
		_game_state = get_tree().get_first_node_in_group("game_state") as GameState
	return _game_state

## The planet whose Gate charts a body: a moon belongs to its planet's region.
static func region_planet(body: Planet, sun_body: Planet) -> Planet:
	if body and body.parent_planet and body.parent_planet != sun_body:
		return body.parent_planet
	return body

## True once a region's Gate is powered, which is what puts its orbits on the chart.
static func is_region_charted(body: Planet, sun_body: Planet, gs: GameState) -> bool:
	var root := region_planet(body, sun_body)
	return root != null and gs != null and gs.is_gate_powered(root.save_key())

## True when the chart draws the body itself: its region is Charted, or it is home.
static func is_charted(body: Planet, sun_body: Planet, home: Planet, gs: GameState) -> bool:
	if body == null:
		return false
	if home != null and body == home:
		return true
	return is_region_charted(body, sun_body, gs)

func _charted(body: Planet) -> bool:
	return is_charted(body, sun, _home_planet(), _game_state_node())

func _region_charted(body: Planet) -> bool:
	return is_region_charted(body, sun, _game_state_node())

## The planet the player's base orbits. Its region is on the chart from the start.
func _home_planet() -> Planet:
	var station := _home_station() as SpaceStation
	return station.parent_planet if station and is_instance_valid(station) else null

func _region_key(body: Planet) -> String:
	var root := region_planet(body, sun)
	return root.save_key() if root else ""

## Every Gate whose Module is online.
func _powered_gates() -> Array[Gate]:
	var powered: Array[Gate] = []
	for node in get_tree().get_nodes_in_group("gates"):
		var gate := node as Gate
		if gate and is_instance_valid(gate) and gate.is_powered():
			powered.append(gate)
	return powered

# --- Reveal ------------------------------------------------------------------

## Take the Modules already online as regions the chart has always held, so loading a
## save does not replay every reveal the player has already been given.
func _prime_charted() -> void:
	_primed = true
	_reveals.clear()
	for gate in _powered_gates():
		_charted_known[gate.save_key()] = true

## Anything charted since the chart was last open draws itself in on this opening.
func _refresh_charted() -> void:
	if not _primed:
		_prime_charted()
		return
	for gate in _powered_gates():
		var key := gate.save_key()
		if key != "" and not _charted_known.has(key):
			_charted_known[key] = true
			_reveals[key] = 0.0

## The reveal waits for the frame to finish drawing itself on, then hands the region
## over piece by piece rather than switching it on.
func _advance_reveals(delta: float) -> void:
	if _reveals.is_empty() or _anim < 1.0:
		return
	for key in _reveals.keys():
		var elapsed: float = _reveals[key] + delta
		if elapsed >= REVEAL_SPAN:
			_reveals.erase(key)
		else:
			_reveals[key] = elapsed

## How far into its reveal one piece of a region is; 1.0 for a region the chart has
## held all along.
func _reveal(key: String, stage: int) -> float:
	return _reveal_stage(_reveals[key], stage) if _reveals.has(key) else 1.0

## Bodies that were already on the chart before their region was Charted — home and its
## station — never draw themselves in again. The orbits under them still do.
func _body_reveal(body: Planet, stage: int) -> float:
	if body != null and body == _home_planet():
		return 1.0
	return _reveal(_region_key(body), stage)

## Each piece of the region starts a beat after the one before it.
static func _reveal_stage(elapsed: float, stage: int) -> float:
	return _ease_out(clampf((elapsed - REVEAL_STAGGER * float(stage)) / REVEAL_TIME, 0.0, 1.0))

# --- Chart -------------------------------------------------------------------

func _sun_pos() -> Vector2:
	return sun.global_position if sun and is_instance_valid(sun) else Vector2.ZERO

## World position -> chart-local pixel position.
func _map_pos(world_pos: Vector2) -> Vector2:
	return map_center + pan_offset + (world_pos - _sun_pos()) * scale_factor

## Chart-local pixel position -> world position. The inverse of _map_pos.
func _unmap_pos(chart_pos: Vector2) -> Vector2:
	return _sun_pos() + (chart_pos - map_center - pan_offset) / maxf(scale_factor, 0.0001)

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
	# The sun holds the Core, and the Core's own Gate is the last thing to take power,
	# so the middle of the chart stays empty for the whole game.
	if _charted(sun):
		_draw_sun(c)
	_draw_planets(c, rect)
	_draw_stations(c, rect)
	_draw_gates(c, rect)
	_draw_freight_marks(c, rect)
	_draw_nav_target(c, rect)
	_draw_ship(c)
	_draw_cursor(c)
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
		if not _region_charted(planet):
			continue
		var reveal := _reveal(_region_key(planet), Reveal.ORBIT)
		if reveal <= 0.0:
			continue
		_draw_dashed_orbit(c, rect, center, planet.orbital_distance, _eccentricity(planet), Color(orbit_color, orbit_color.a * reveal), 1.0)

func _draw_child_orbits(c: Control, rect: Rect2) -> void:
	# Moons and stations both orbit a parent planet, drawn in the same dashed style
	for planet in planets:
		if not planet or not is_instance_valid(planet):
			continue
		if not planet.parent_planet or planet.parent_planet == sun:
			continue
		# A moon's orbit belongs to its planet's region, home's moon included: the path
		# the base rides round is drawn only once that planet's Gate is powered.
		if not _region_charted(planet):
			continue
		var reveal := _reveal(_region_key(planet), Reveal.MOON)
		if reveal <= 0.0:
			continue
		var center := _map_pos(planet.parent_planet.global_position)
		_draw_dashed_orbit(c, rect, center, planet.orbital_distance, _eccentricity(planet), Color(moon_orbit_color, moon_orbit_color.a * reveal), 1.5, 6.0)

	for node in get_tree().get_nodes_in_group("space_stations"):
		var station := node as SpaceStation
		if not station or not is_instance_valid(station) or not station.parent_planet:
			continue
		if not _charted(station.parent_planet):
			continue
		var reveal := _body_reveal(station.parent_planet, Reveal.STATION)
		if reveal <= 0.0:
			continue
		var center := _map_pos(station.parent_planet.global_position)
		_draw_dashed_orbit(c, rect, center, station.orbital_distance, _eccentricity(station), Color(space_station_orbit_color, space_station_orbit_color.a * reveal), 1.5, 6.0)

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
		if not _charted(planet):
			continue

		var pos := _map_pos(planet.global_position)
		var radius := maxf(planet.radius * scale_factor * planet_size_multiplier, 2.0)
		if not rect.grow(radius + 8.0).has_point(pos):
			continue

		var is_moon := planet.parent_planet != null and planet.parent_planet != sun
		var reveal := _body_reveal(planet, Reveal.MOON if is_moon else Reveal.PLANET)
		if reveal <= 0.0:
			continue

		c.draw_circle(pos, radius, Color(planet.color, planet.color.a * reveal))
		c.draw_arc(pos, radius + 1.5, 0.0, TAU, 40, Color(planet.color, 0.45 * reveal), 1.0, true)

		# Moons stay unlabelled unless they are big enough to read against
		if not is_moon or radius >= 3.5:
			var label_alpha := (0.55 if not is_moon else 0.35) * reveal
			_draw_body_label(c, pos, radius, planet.planet_name, Color(Colors.PRIMARY, label_alpha))

## `drop` sets the label below the body's own line, so a Gate sitting on top of its
## planet at full zoom-out doesn't write over the planet's name.
func _draw_body_label(c: Control, pos: Vector2, radius: float, text: String, color: Color, drop: float = 0.0) -> void:
	if text.is_empty():
		return
	var leader_start := pos + Vector2(radius + 3.0, 0.0)
	var leader_end := leader_start + Vector2(5.0, drop)
	c.draw_line(leader_start, leader_end, Color(color, color.a * 0.5), 1.0)
	c.draw_string(_font, leader_end + Vector2(4.0, 3.0), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, color)

func _draw_stations(c: Control, rect: Rect2) -> void:
	for node in get_tree().get_nodes_in_group("space_stations"):
		var station := node as SpaceStation
		if not station or not is_instance_valid(station):
			continue
		if not _charted(station.parent_planet):
			continue

		var pos := _map_pos(station.global_position)
		if not rect.grow(16.0).has_point(pos):
			continue

		var reveal := _body_reveal(station.parent_planet, Reveal.STATION)
		if reveal <= 0.0:
			continue

		# Hollow diamond, so stations never read as a planet
		var r := 4.5
		var diamond := PackedVector2Array([
			pos + Vector2(0.0, -r), pos + Vector2(r, 0.0),
			pos + Vector2(0.0, r), pos + Vector2(-r, 0.0),
			pos + Vector2(0.0, -r)
		])
		c.draw_polygon(diamond.slice(0, 4), PackedColorArray([Color(Colors.SPACE_BG, 0.9 * reveal)]))
		c.draw_polyline(diamond, Color(space_station_color, space_station_color.a * reveal), 1.2, true)
		c.draw_line(pos + Vector2(-r - 3.0, 0.0), pos + Vector2(r + 3.0, 0.0), Color(space_station_color, 0.4 * reveal), 1.0)

		# Only label it once it has pulled clear of its planet's own label
		if station.orbital_distance * scale_factor > 16.0:
			_draw_body_label(c, pos, r + 2.0, "STATION", Color(space_station_color, 0.6 * reveal))

## Powered Gates, and the Titan's links between every pair of them. The network is the
## thing the player is putting back together, so it is drawn as it grows.
func _draw_gates(c: Control, rect: Rect2) -> void:
	var powered := _powered_gates()
	if powered.is_empty():
		return

	_draw_gate_links(c, rect, powered)

	for gate in powered:
		var pos := _map_pos(gate.global_position)
		if not rect.grow(20.0).has_point(pos):
			continue
		var reveal := _reveal(gate.save_key(), Reveal.GATE)
		if reveal <= 0.0:
			continue

		# The glyph is the Gate seen from above: a ring with the cradle's mouth in it
		var start := PI / 2.0 + GATE_MOUTH / 2.0
		var span := TAU - GATE_MOUTH
		c.draw_arc(pos, GATE_GLYPH_RADIUS + 2.0, start, start + span, 24, Color(gate_color, 0.18 * reveal), 3.0, true)
		c.draw_arc(pos, GATE_GLYPH_RADIUS, start, start + span, 24, Color(gate_color, 0.9 * reveal), 1.4, true)
		c.draw_circle(pos, 1.4, Color(gate_color, reveal))
		_draw_body_label(c, pos, GATE_GLYPH_RADIUS + 2.0, _gate_label(gate), Color(gate_color, 0.7 * reveal), GATE_LABEL_DROP)

## A line between every pair of powered Gates: what one Module can reach from another.
func _draw_gate_links(c: Control, rect: Rect2, powered: Array[Gate]) -> void:
	for i in range(powered.size()):
		for j in range(i + 1, powered.size()):
			var from := _map_pos(powered[i].global_position)
			var to := _map_pos(powered[j].global_position)
			if from.distance_to(to) < GATE_LINK_MIN_PX:
				continue
			var leg := _clip_segment(from, to, rect.grow(8.0))
			if leg.size() != 2:
				continue
			var reveal := minf(_reveal(powered[i].save_key(), Reveal.GATE), _reveal(powered[j].save_key(), Reveal.GATE))
			c.draw_line(leg[0], leg[1], Color(gate_color, 0.3 * reveal), 1.0, true)

## A Gate is named for the Module it powers.
func _gate_label(gate: Gate) -> String:
	var planet := gate.parent_planet
	return "%s GATE" % (planet.planet_name if planet else gate.save_key()).to_upper()

## The ship's own marks (docs/adr/0012): Freight it has handled and let go of, and hulls
## abandoned with Freight still clamped, labelled with what they hold. Each is
## {"position", "label", "hull"}. They are the ship's, not the Titan's, so they are drawn
## over uncharted space too. Untouched Freight and empty derelicts have none.
static func freight_marks(tree: SceneTree) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for node in tree.get_nodes_in_group("freight"):
		var f := node as Freight
		if f and f.is_marked() and not f.is_queued_for_deletion():
			marks.append({"position": f.global_position, "label": f.label, "hull": false})
	for node in tree.get_nodes_in_group("derelicts"):
		var d := node as DerelictShip
		if d and d.is_holding_freight() and not d.is_queued_for_deletion():
			marks.append({"position": d.global_position, "label": d.chart_label(), "hull": true})
	return marks

## A hollow square for a piece of Freight; a hull holding one gets a chevron over it.
func _draw_freight_marks(c: Control, rect: Rect2) -> void:
	for mark in freight_marks(get_tree()):
		var pos := _map_pos(mark["position"])
		if not rect.grow(20.0).has_point(pos):
			continue
		var r := 3.5
		var box := Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0)
		c.draw_rect(box, Color(Colors.SPACE_BG, 0.9))
		c.draw_rect(box, freight_color, false, 1.2)
		if mark["hull"]:
			c.draw_polyline(PackedVector2Array([
				pos + Vector2(-r - 2.0, -r - 2.0), pos + Vector2(0.0, -r - 5.0), pos + Vector2(r + 2.0, -r - 2.0)
			]), freight_color, 1.2, true)
		_draw_body_label(c, pos, r + 2.0, mark["label"], Color(freight_color, 0.8))

func _draw_nav_target(c: Control, rect: Rect2) -> void:
	var target := NavSystem.get_target()
	if target == null or not target.is_valid():
		return

	var pos := _map_pos(target.get_position())
	var ship_pos := _map_pos(ship.global_position) if ship and is_instance_valid(ship) else pos
	var apart := ship_pos.distance_to(pos) > 30.0

	# Dotted run from the ship to the marker: blue is navigation only. Docked at
	# the target, the two markers coincide, so the leg and label are dropped.
	# Zoomed in, either end can sit a long way off the chart, so only the stretch
	# that crosses it is dashed — the leg still points the way out.
	if apart:
		var leg := _clip_segment(ship_pos, pos, rect.grow(8.0))
		if leg.size() == 2:
			c.draw_dashed_line(leg[0], leg[1], Color(nav_color, 0.22), 1.0, 5.0)

	if not rect.grow(24.0).has_point(pos):
		return

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

## The mark: a broken crosshair the arrow keys drive around, ringed once it has
## locked onto a body. Blue, because all of it is navigation.
func _draw_cursor(c: Control) -> void:
	var body := _snap_body()
	var at := _map_pos(body.global_position if body else cursor_world)
	var gap := 4.0
	var arm := 7.0

	var ticks := PackedVector2Array()
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		ticks.append(at + direction * gap)
		ticks.append(at + direction * (gap + arm))
	c.draw_multiline(ticks, Color(nav_color, 0.85), 1.0)

	if body:
		c.draw_arc(at, gap + 2.0, 0.0, TAU, 24, Color(nav_color, 0.45), 1.0, true)
	else:
		c.draw_rect(Rect2(at - Vector2.ONE, Vector2(2.0, 2.0)), Color(nav_color, 0.85))

	# A ring going out from the mark confirms the point was taken
	if _mark_flash > 0.0:
		c.draw_arc(at, lerpf(26.0, 6.0, _mark_flash), 0.0, TAU, 32, Color(nav_color, _mark_flash * 0.6), 1.0, true)

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
	_draw_readout(c, text_a)
	_draw_scale_bar(c, text_a)

## The chart's own keys, for the Log's bottom border. Dropping the point is only
## offered once there is one to drop.
func hint_text() -> String:
	var hint := "[ +/- ] ZOOM   [ WASD ] PAN   [ ARROWS ] MARK   [ ENTER ] TRACK"
	if NavSystem.get_target() != null and not NavSystem.is_tracking_home():
		hint += "   [ DEL ] CLEAR"
	return hint + "   [ C ] CENTER"

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

func _draw_readout(c: Control, alpha: float) -> void:
	var key_color := Color(Colors.PRIMARY, 0.4 * alpha)
	var value_color := Color(Colors.PRIMARY, 0.8 * alpha)
	var rows: Array[Array] = [["ZOOM", "x%.1f" % zoom_level]]

	if ship and is_instance_valid(ship):
		var relative := ship.global_position - _sun_pos()
		rows.append(["SHIP", "%+.1f / %+.1f Mm" % [relative.x / 1000.0, relative.y / 1000.0]])

	var marked := _snap_body()
	if marked:
		rows.append(["MARK", _body_label(marked)])
	else:
		var offset := cursor_world - _sun_pos()
		rows.append(["MARK", "%+.1f / %+.1f Mm" % [offset.x / 1000.0, offset.y / 1000.0]])

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

## The part of the segment a -> b that lies inside `rect`, as [start, end], or
## empty when the segment misses it altogether. Liang-Barsky, so a leg running
## clear across the chart costs the same whether its ends are on it or not.
static func _clip_segment(a: Vector2, b: Vector2, rect: Rect2) -> PackedVector2Array:
	var d := b - a
	var edge := PackedFloat32Array([-d.x, d.x, -d.y, d.y])
	var room := PackedFloat32Array([
		a.x - rect.position.x, rect.end.x - a.x,
		a.y - rect.position.y, rect.end.y - a.y
	])
	var enter := 0.0
	var exit := 1.0
	for i in range(4):
		if is_zero_approx(edge[i]):
			if room[i] < 0.0:
				return PackedVector2Array()
			continue
		var t := room[i] / edge[i]
		if edge[i] < 0.0:
			enter = maxf(enter, t)
		else:
			exit = minf(exit, t)
	if enter > exit:
		return PackedVector2Array()
	return PackedVector2Array([a + d * enter, a + d * exit])

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
