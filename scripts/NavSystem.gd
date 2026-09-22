extends Node

## Player navigation. Owns the player's Tracker (one target at a time) and
## falls back to tracking home base whenever nothing else is selected - including the
## moment the ship reaches a waypoint, which has done its job.
##
##   NavSystem.track_point(pos, "WAYPOINT")
##   NavSystem.track(NodeTrackingTarget.new(planet))
##   NavSystem.track_home()

const HOME_LABEL := "HOME"

var player_tracker: Tracker
var _home: NodeTrackingTarget = null

func _ready() -> void:
	player_tracker = Tracker.new()
	player_tracker.name = "PlayerTracker"
	add_child(player_tracker)

func _process(_delta: float) -> void:
	if not player_tracker.has_target():
		track_home()
		return
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	if ship and waypoint_reached(player_tracker.target, ship.global_position):
		track_home()

## A waypoint (a bare point in space, not a body) is done with once the ship is inside
## its arrival radius. Bodies, stations and Freight stay tracked until something else is.
static func waypoint_reached(target: TrackingTarget, ship_position: Vector2) -> bool:
	return target is PointTrackingTarget \
		and ship_position.distance_to(target.get_position()) <= target.get_arrival_radius()

func get_target() -> TrackingTarget:
	return player_tracker.target if player_tracker.has_target() else null

## Track something new. Passing null returns to home base.
func track(target: TrackingTarget) -> void:
	if target == null:
		track_home()
	else:
		player_tracker.track(target)

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
