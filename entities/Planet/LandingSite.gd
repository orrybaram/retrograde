extends Node2D
class_name LandingSite

## A spot on a planet's surface where the ship can touch down and drill for gems.
## Sits on the rim at `angle_degrees` as a child of its Planet, so it rides the orbit.
## Drawn as a pad bracket with a blinking beacon mast, pointing out of the surface.
## Hidden (on the map, minimap and tracking too) until the Planetary Scanner maps its
## planet. `rich` sites (moons) drill deeper, better gems.
## A dig spends the site: its beacon dims to PRIMARY_DIM and it can't be drilled until it
## regrows (REGROW_TIME of play, RICH_REGROW_TIME for rich sites; timers in GameState).

const PAD_WIDTH := 120.0  # along the surface
const PAD_LIP := 10.0  # bracket upright height
const PAD_LIFT := 3.0  # gap between surface and pad line
const MAST_HEIGHT := 34.0
const BEACON_SIZE := 5.0
const BLINK_PERIOD := 1.2
const REVEAL_TIME := 0.8
const PING_RADIUS := 140.0
const LINE_WIDTH := 4.0
const REGROW_TIME := 300.0
const RICH_REGROW_TIME := 450.0

## Where on the rim, in degrees (0 = the planet's +x side).
@export_range(0.0, 360.0) var angle_degrees: float = 0.0
## Richer sites (moons) roll better gems deeper down.
@export var rich: bool = false

var planet: Planet = null
var minimap_target: LandingSiteMinimapTarget = null

var _revealed := false
var _reveal_time := 0.0  # counts up after reveal, for the ping
var _tracking: LandingSiteTrackingTarget = null
var _gs: GameState = null
var _was_spent := false

func _ready() -> void:
	add_to_group("landing_sites")
	planet = get_parent() as Planet
	z_index = 1  # over the planet disc, under the ship
	if planet:
		var normal_angle := deg_to_rad(angle_degrees)
		position = Vector2.from_angle(normal_angle) * surface_radius()
		rotation = normal_angle
	EventBus.planet_scanned.connect(_on_planet_scanned)
	EventBus.planets_restored.connect(refresh)
	EventBus.ship_respawned.connect(refresh)
	refresh()
	_register_with_minimap.call_deferred()

func _exit_tree() -> void:
	if minimap_target:
		var minimap := Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

## Planet key + node name, stable across sessions (for saves).
func site_id() -> String:
	return "%s#%s" % [planet.save_key(), name]

func surface_radius() -> float:
	return planet.radius * planet.collision_radius_ratio

## Outward surface normal (world space).
func normal() -> Vector2:
	return Vector2.from_angle(global_rotation)

## Half the pad's width as an angle on the planet's surface.
func pad_half_angle() -> float:
	return PAD_WIDTH / 2.0 / surface_radius()

## World velocity of the pad (the planet's orbital velocity).
func velocity() -> Vector2:
	return planet.linear_velocity if planet else Vector2.ZERO

func is_revealed() -> bool:
	return _revealed

func regrow_time() -> float:
	return RICH_REGROW_TIME if rich else REGROW_TIME

## Seconds until a dug-out site can be drilled again (0 when it can).
func regrow_left() -> float:
	var gs := _game_state()
	return gs.site_regrow_left(site_id()) if gs else 0.0

func is_spent() -> bool:
	return regrow_left() > 0.0

## A dig finished here: dim the beacon and start the regrow timer.
func spend() -> void:
	var gs := _game_state()
	if not gs:
		return
	gs.spend_site(site_id(), regrow_time())
	_was_spent = true
	queue_redraw()

func _game_state() -> GameState:
	if not is_instance_valid(_gs) and is_inside_tree():
		_gs = get_tree().get_first_node_in_group("game_state") as GameState
	return _gs if is_instance_valid(_gs) else null

func tracking_target() -> LandingSiteTrackingTarget:
	if not _tracking:
		_tracking = LandingSiteTrackingTarget.new(self)
	return _tracking

## Show or hide to match whether the planet has been scanned.
func refresh() -> void:
	_set_revealed(planet != null and planet.is_scanned(), false)

func _on_planet_scanned(scanned: Planet) -> void:
	if scanned == planet:
		_set_revealed(true, true)

func _set_revealed(value: bool, animate: bool) -> void:
	_revealed = value
	_was_spent = is_spent()
	visible = value
	_reveal_time = 0.0 if animate else REVEAL_TIME
	queue_redraw()

func _process(delta: float) -> void:
	if not _revealed:
		return
	var spent := is_spent()
	if _was_spent and not spent:
		_reveal_time = 0.0  # regrown: ping again
	_was_spent = spent
	_reveal_time += delta
	queue_redraw()

func beacon_color() -> Color:
	return Colors.PRIMARY_DIM if is_spent() else Colors.PRIMARY

func _draw() -> void:
	var t := clampf(_reveal_time / REVEAL_TIME, 0.0, 1.0)
	var grow := ease(t, 0.4)
	var color := Color(beacon_color(), t)
	var half := PAD_WIDTH / 2.0 * grow
	# Local +x points out of the surface; the pad runs along y.
	var base := PAD_LIFT
	draw_line(Vector2(base, -half), Vector2(base, half), color, LINE_WIDTH)
	draw_line(Vector2(base, -half), Vector2(base + PAD_LIP, -half), color, LINE_WIDTH)
	draw_line(Vector2(base, half), Vector2(base + PAD_LIP, half), color, LINE_WIDTH)
	# Beacon mast off to one side of the pad, so a landed ship doesn't cover it
	var mast := Vector2(0, -half - 12.0)
	var top := mast + Vector2(MAST_HEIGHT * grow, 0)
	draw_line(mast, top, Color(Colors.HULL_LIGHT, t), 2.0)
	# A spent beacon glows dim and steady
	var lit := _was_spent or fmod(_reveal_time, BLINK_PERIOD) < BLINK_PERIOD * 0.55
	draw_circle(top, BEACON_SIZE * 2.2, Color(color, color.a * (0.25 if lit else 0.08)))
	draw_circle(top, BEACON_SIZE, color if lit else Color(color, color.a * 0.4))
	# Reveal ping
	if _reveal_time < REVEAL_TIME:
		draw_arc(top, PING_RADIUS * t, 0.0, TAU, 48, Color(beacon_color(), 1.0 - t), 2.0)

func _register_with_minimap() -> void:
	var minimap := Minimap.get_instance(get_tree())
	if minimap:
		minimap_target = LandingSiteMinimapTarget.new(self)
		minimap.register_target(minimap_target)
