extends Node

## The Void: the dark past the last orbit. Nothing orbits out there, nothing
## reflects, nothing answers. Crossing EDGE_RADIUS starts a clock the player
## can't stop, only outrun.
##
## Two numbers drive the whole effect:
##   depth — how far past the edge the ship is (0 at EDGE_RADIUS, 1 at DEEP_RADIUS)
##   dread — how much of the clock is spent (exposure / SURVIVAL_TIME)
##
## `shroud` is the worse of the two, and it's what the starfield, the HUD glitch
## and the overlay read. So a deep crossing goes dark immediately, and loitering
## on the fringe goes dark slowly — either way it ends in the same nothing.

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
## Where there is nothing left to see. Past here the sky is already gone.
const DEEP_RADIUS := 380_000.0
## Once past the edge, the ship has to come back this far inside before the void
## lets go. Without it a ship flying the boundary flickers in and out of the dark
## and retriggers the warning every few frames.
const RE_ENTRY_MARGIN := 4_000.0
## Seconds of exposure at the very fringe before the ship is taken.
const SURVIVAL_TIME := 30.0
## The clock runs this much faster at full depth (so ~12s deep, 30s at the edge).
const DEPTH_URGENCY := 1.5
## Exposure bleeds off this much faster than it built, once the ship is back in.
const RECOVERY_RATE := 2.5

## 0 inside the system, 1 at DEEP_RADIUS and beyond.
var depth: float = 0.0
## 0 to 1 as the survival clock runs down.
var dread: float = 0.0
## What the visuals read: max(depth, dread).
var shroud: float = 0.0
## Seconds spent in the dark, out of SURVIVAL_TIME.
var exposure: float = 0.0

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

## The survival clock, one step. Inside the void it runs forward faster the
## deeper the ship is; outside it winds back at RECOVERY_RATE.
static func step_exposure(seconds: float, delta: float, at_depth: float, inside: bool) -> float:
	if inside:
		return minf(seconds + delta * (1.0 + at_depth * DEPTH_URGENCY), SURVIVAL_TIME)
	return maxf(seconds - delta * RECOVERY_RATE, 0.0)

## Seconds of real time left at this depth before the clock runs out.
static func seconds_left(seconds: float, at_depth: float) -> float:
	return maxf(SURVIVAL_TIME - seconds, 0.0) / (1.0 + at_depth * DEPTH_URGENCY)

## True while the ship is past the edge.
func is_inside() -> bool:
	return _inside

## Seconds left before the dark takes the ship, or INF outside it.
func time_left() -> float:
	return seconds_left(exposure, depth) if _inside else INF

## Back to a clean sky: called on respawn, and by tests.
func reset() -> void:
	exposure = 0.0
	depth = 0.0
	dread = 0.0
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
	var was_inside := _inside
	_inside = inside_at(distance, was_inside)

	exposure = step_exposure(exposure, delta, depth, _inside)
	dread = clampf(exposure / SURVIVAL_TIME, 0.0, 1.0)
	shroud = maxf(depth, dread)

	if _inside and not was_inside:
		entered.emit()
		if _edge_warning == null:
			_edge_warning = load("res://entities/Robot/radio/messages/void_edge.tres")
		EventBus.radio_message_requested.emit(_edge_warning)
	elif was_inside and not _inside:
		exited.emit()

	if _inside and not _taken and exposure >= SURVIVAL_TIME:
		_taken = true
		consumed.emit()

## Docked, destroyed or on a menu: the void lets go, but not instantly, so a
## respawn doesn't snap the sky back on.
func _relax(delta: float) -> void:
	if exposure <= 0.0 and shroud <= 0.0:
		return
	exposure = maxf(exposure - delta * RECOVERY_RATE, 0.0)
	depth = 0.0
	dread = clampf(exposure / SURVIVAL_TIME, 0.0, 1.0)
	shroud = dread
	if _inside:
		_inside = false
		exited.emit()

## Menus and game overs don't run the clock. The dark hangs on through the
## robot's call, though — `_relax` only bleeds it off slowly.
func _playing() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	return main != null and main.current_game_state == main.MainGameState.PLAYING

func _is_flying() -> bool:
	var sm: StateMachine = _ship.state_machine
	return sm != null and (sm.current_state is FlyingState or sm.current_state is HarvestingState)

func _distance_from_sun() -> float:
	return _ship.global_position.distance_to(_sun_position())

func _sun_position() -> Vector2:
	if not is_instance_valid(_sun):
		_sun = null
		for node in get_tree().get_nodes_in_group("planets"):
			var planet := node as Planet
			if planet and planet.planet_type == Planet.PlanetType.SUN:
				_sun = planet
				break
	return _sun.global_position if _sun else Vector2.ZERO
