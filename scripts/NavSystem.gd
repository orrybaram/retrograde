extends Node

## Player navigation. Owns the player's Tracker (one target at a time).
##
## **Nothing is tracked until the player asks for it.** There is no fallback to home base:
## a tracker that always points somewhere is a marker the player never chose, and it parks
## a label over whatever it is aimed at (it sat on SR-7's core). Reaching a waypoint clears
## it, and so does dropping it from the chart. Home is still a target the player can pick -
## it is just never the one they get by default.
##
##   NavSystem.track_point(pos, "WAYPOINT")
##   NavSystem.track(NodeTrackingTarget.new(planet))
##   NavSystem.track_home()
##   NavSystem.clear()

const HOME_LABEL := "HOME"

var player_tracker: Tracker
var _home: NodeTrackingTarget = null

func _ready() -> void:
	player_tracker = Tracker.new()
	player_tracker.name = "PlayerTracker"
	add_child(player_tracker)

func _process(_delta: float) -> void:
	if not player_tracker.has_target():
		return
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	if ship and waypoint_reached(player_tracker.target, ship.global_position):
		clear()

## A waypoint (a bare point in space, not a body) is done with once the ship is inside
## its arrival radius. Bodies, stations and Freight stay tracked until something else is.
static func waypoint_reached(target: TrackingTarget, ship_position: Vector2) -> bool:
	return target is PointTrackingTarget \
		and ship_position.distance_to(target.get_position()) <= target.get_arrival_radius()

func get_target() -> TrackingTarget:
	return player_tracker.target if player_tracker.has_target() else null

## Track something new. Passing null stops tracking.
func track(target: TrackingTarget) -> void:
	player_tracker.track(target)

## Stop tracking. The indicator goes away until the player picks something.
func clear() -> void:
	player_tracker.clear()

## Track a fixed world position (player waypoint, map selection).
func track_point(world_position: Vector2, label: String = "WAYPOINT") -> void:
	track(PointTrackingTarget.new(world_position, label))

func track_home() -> void:
	player_tracker.track(home_target())

func is_tracking_home() -> bool:
	return player_tracker.target != null and player_tracker.target == _home

## Home base: the first space station in the scene. Null when none exists.
func home_target() -> TrackingTarget:
	if _home and _home.is_valid():
		return _home
	var station := get_tree().get_first_node_in_group("space_stations") as Node2D
	_home = NodeTrackingTarget.new(station, HOME_LABEL, 200.0) if station else null
	return _home
