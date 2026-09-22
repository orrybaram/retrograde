extends Node

## The Void: the dark past the last orbit. Nothing orbits out there, nothing
## reflects, nothing answers. There is no clock: how far past EDGE_RADIUS the ship
## is decides everything.
##
##   depth - 0 at EDGE_RADIUS, 1 at DEEP_RADIUS
##
## `shroud` is what the starfield, the HUD glitch, the overlay and the maps read, and
## it is simply the depth: the fringe is eerie, halfway in the sky is going, and at
## DEEP_RADIUS there is nothing left and the ship is taken. Loitering is never what
## kills; going deeper is, and turning back hands everything back at once.

## First entry into the void (once per trip, not once per save).
signal entered()
## Back inside the last orbit, still alive.
signal exited()
## The dark closed over the ship. Main turns this into a game over.
signal consumed()

## Where the system stops being a system. Veld's orbit is 253125, but the home
## station rides Rook around it and swings out to roughly 295000 at apoapsis —
## the edge has to sit well clear of that, or the dock itself is in the dark.
const EDGE_RADIUS := 340_000.0
## Where there is nothing left to see, and the dark takes the ship.
const DEEP_RADIUS := 380_000.0
## Once past the edge, the ship has to come back this far inside before the void
## lets go. Without it a ship flying the boundary flickers in and out of the dark
## and retriggers the warning every few frames.
const RE_ENTRY_MARGIN := 4_000.0

## 0 inside the system, 1 at DEEP_RADIUS and beyond.
var depth: float = 0.0
## What the visuals read: the depth, while the ship is out there to feel it.
var shroud: float = 0.0

var _inside := false
var _taken := false  ## latched so `consumed` only fires once per ship
var _ship: Ship = null
var _sun: Node2D = null
## Loaded on first crossing rather than preloaded: an autoload that pulls in the
## radio at parse time drags RobotRadio's own message preloads into a cycle.
var _edge_warning: Resource = null

func _ready() -> void:
	EventBus.ship_respawned.connect(reset)

## How far past the edge a point is: 0 inside the system, 1 at DEEP_RADIUS and out.
static func depth_at(distance_from_sun: float) -> float:
	return clampf(inverse_lerp(EDGE_RADIUS, DEEP_RADIUS, distance_from_sun), 0.0, 1.0)

## Whether the ship counts as being in the void, given where it already was.
## Crossing in happens at the edge; getting back out takes RE_ENTRY_MARGIN of
## daylight, so the boundary can be flown along without the sky strobing.
static func inside_at(distance_from_sun: float, was_inside: bool) -> bool:
	var threshold := EDGE_RADIUS - RE_ENTRY_MARGIN if was_inside else EDGE_RADIUS
	return distance_from_sun >= threshold

## Whether a ship at this depth has gone too far to come back.
static func consumes_at(at_depth: float) -> bool:
	return at_depth >= 1.0

## True while the ship is past the edge.
func is_inside() -> bool:
	return _inside

## How much further out the ship can go before the dark takes it, or INF inside the system.
func distance_left() -> float:
	if not _inside or _ship == null or not is_instance_valid(_ship):
		return INF
	return maxf(DEEP_RADIUS - _distance_from_sun(), 0.0)

## Back to a clean sky, at once: every screen effect goes with it (Main calls this as
## a relaunch, a load or a new game begins, so the boot screen comes up clean).
func clear_now() -> void:
	reset()

## Back to a clean sky: called on respawn, and by tests.
func reset() -> void:
	depth = 0.0
	shroud = 0.0
	_taken = false
	if _inside:
		_inside = false
		exited.emit()

func _process(delta: float) -> void:
	_ship = _ship if is_instance_valid(_ship) else get_tree().get_first_node_in_group("ship") as Ship
	if _ship == null or not _playing() or not _is_flying():
		_relax(delta)
		return

	var distance := _distance_from_sun()
	depth = depth_at(distance)
	shroud = depth
	var was_inside := _inside
	_inside = inside_at(distance, was_inside)

	if _inside and not was_inside:
		entered.emit()
		if _edge_warning == null:
			_edge_warning = load("res://entities/Robot/radio/messages/void_edge.tres")
		EventBus.radio_message_requested.emit(_edge_warning)
	elif was_inside and not _inside:
		exited.emit()

	if not _taken and consumes_at(depth):
		_taken = true
		consumed.emit()

## Docked, destroyed or on a menu: out of the dark. The overlays ease themselves
## back, so a respawn doesn't snap the sky on. Once the ship has been taken the dark
## holds, through the silence and the robot's call, until the respawn resets it.
func _relax(_delta: float) -> void:
	if _taken:
		depth = 1.0
		shroud = 1.0
		return
	depth = 0.0
	shroud = 0.0
	if _inside:
		_inside = false
		exited.emit()

## Menus and game overs take the ship out of the dark.
func _playing() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	return main != null and main.current_game_state == main.MainGameState.PLAYING

func _is_flying() -> bool:
	var sm: StateMachine = _ship.state_machine
	return sm != null and (sm.current_state is FlyingState or sm.current_state is HarvestingState)

func _distance_from_sun() -> float:
	return _ship.global_position.distance_to(sun_position())

## The middle of the system, which EDGE_RADIUS is measured from (the origin with no sun).
func sun_position() -> Vector2:
	if not is_instance_valid(_sun):
		_sun = null
		for node in get_tree().get_nodes_in_group("planets"):
			var planet := node as Planet
			if planet and planet.planet_type == Planet.PlanetType.SUN:
				_sun = planet
				break
	return _sun.global_position if _sun else Vector2.ZERO
