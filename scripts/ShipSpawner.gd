extends Node
class_name ShipSpawner

## Handles ship spawning - unified system for all spawn scenarios.
## All spawns go through spawn_at_dock() for consistent behavior.

signal spawn_complete()

@onready var ship: Ship = get_node("../Ship")

func _ready() -> void:
	pass

## Primary spawn method - spawns ship docked at a dockable entity.
## This is the single entry point for all spawn scenarios.
## @param dockable: The dockable entity to spawn at
## @param instant: If true, skip docking animation (default for spawning)
func spawn_at_dock(dockable: Node2D, instant: bool = true) -> void:
	if not ship or not is_instance_valid(ship):
		push_error("ShipSpawner: No valid ship reference")
		return
	
	if not dockable or not is_instance_valid(dockable):
		push_error("ShipSpawner: No valid dockable provided")
		return
	
	# Wait a frame to ensure everything is initialized
	await get_tree().process_frame
	
	# Get dock properties
	var dock_pos = _get_dock_position(dockable)
	var dock_rotation = _get_dock_rotation(dockable)
	var dock_velocity = _get_dock_velocity(dockable)
	
	# Calculate ship rotation (perpendicular to dock surface)
	var ship_rotation = dock_rotation + PI / -2.0
	
	# Get spawn offset if dockable has a ShipSpawn child
	var spawn_offset = Vector2.ZERO
	var ship_spawn = dockable.get_node_or_null("ShipSpawn") as ShipSpawn
	if ship_spawn:
		# Use ShipSpawn's rotated offset
		spawn_offset = ship_spawn.spawn_offset.rotated(dock_rotation)
	
	# Calculate final spawn position
	var spawn_pos = dock_pos + spawn_offset
	
	# Temporarily unpause for physics if needed
	var was_paused = get_tree().paused
	if was_paused:
		get_tree().paused = false
		await get_tree().physics_frame
		get_tree().paused = true
	
	if not is_instance_valid(ship):
		return
	
	# Set ship transform and velocity to match dock
	ship.global_position = spawn_pos
	ship.rotation = ship_rotation
	ship.linear_velocity = dock_velocity
	ship.angular_velocity = 0.0
	
	# Set metadata for the docked state
	ship.set_meta("pending_dockable", dockable)
	if instant:
		ship.set_meta("instant_dock", true)
	
	# Dock the way flying in would have: a Gate has its own state
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	var docked_state = FlyingState.docked_state_for(dockable)
	if state_machine and state_machine.has_state(docked_state):
		state_machine.change_state(docked_state)
	
	print("Ship spawned at dock: ", dockable.name, " position: ", spawn_pos)
	spawn_complete.emit()

## Where the ship wakes adrift beside SR-7 (docs/OPENING.md §3), in the station's space:
## just off the end of the belly, where the dock would be if its arm were out.
const ADRIFT_OFFSET := Vector2(560, 190)
## Its heading and slow tumble, rad and rad/s, and how it drifts off the station, px/s.
const ADRIFT_ROTATION := 2.3
const ADRIFT_SPIN := 0.32
const ADRIFT_VELOCITY := Vector2(3.0, 2.0)

## A new game, or no dock to come back to: the ship adrift outside `station`, turning slowly
## over among the fine debris it woke in (WakeDrift). `with_drift` false leaves the debris
## out (a respawn: the player has seen it).
func spawn_adrift(station: Node2D, with_drift := true) -> void:
	if not station or not is_instance_valid(station):
		push_error("ShipSpawner: No station to wake beside")
		return
	await get_tree().process_frame
	if not is_instance_valid(station):
		return
	var velocity := Vector2.ZERO
	if station is RigidBody2D:
		velocity = (station as RigidBody2D).linear_velocity
	var pos := station.to_global(ADRIFT_OFFSET)
	await spawn_in_flight(pos, ADRIFT_ROTATION, velocity + ADRIFT_VELOCITY)
	if is_instance_valid(ship):
		ship.drift_spin = ADRIFT_SPIN
	if with_drift:
		for old in station.get_children():
			if old is WakeDrift:
				old.queue_free()
		var drift := WakeDrift.new()
		drift.position = ADRIFT_OFFSET
		station.add_child(drift)

## The station a new game wakes beside: the player's home (group "space_stations").
func find_home_station() -> Node2D:
	await get_tree().process_frame
	return get_tree().get_first_node_in_group("space_stations") as Node2D

## Put the ship back in open flight at `pos`, turned to `rot`, moving at `velocity`:
## a save made away from any dock (with Freight clamped, which no dock takes).
func spawn_in_flight(pos: Vector2, rot: float, velocity: Vector2) -> void:
	if not ship or not is_instance_valid(ship):
		push_error("ShipSpawner: No valid ship reference")
		return
	await get_tree().process_frame
	if not is_instance_valid(ship):
		return
	var state_machine = ship.get_node_or_null("StateMachine") as StateMachine
	if state_machine and state_machine.has_state("FlyingState"):
		state_machine.change_state("FlyingState")
	var rid := ship.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(rot, pos))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	ship.global_position = pos
	ship.rotation = rot
	ship.linear_velocity = velocity
	ship.angular_velocity = 0.0
	spawn_complete.emit()

## Find the default dock for new games.
## Priority: SpaceStation > SpacePort > First dockable
func find_default_dock() -> Node2D:
	# Wait for scene to be ready
	await get_tree().process_frame
	
	var dockables = get_tree().get_nodes_in_group("dockable")
	if dockables.is_empty():
		push_warning("ShipSpawner: No dockable entities found in scene")
		return null
	
	# First priority: SpaceStation
	for dockable in dockables:
		if dockable is SpaceStation:
			return dockable
	
	# Second priority: SpacePort
	for dockable in dockables:
		if dockable is SpacePort:
			return dockable
	
	# Fallback: first dockable
	return dockables[0] as Node2D

## Find the saved dock from the save file.
## Returns null if no save exists or dock not found.
func find_saved_dock() -> Node2D:
	var dockable_key = Save.load_dockable_key()
	if dockable_key == "":
		return null
	
	# Need to wait for planets to update their positions after restore
	await get_tree().physics_frame
	
	var dockable = Save.find_dockable_by_key(get_tree(), dockable_key)
	if dockable and is_instance_valid(dockable):
		# Wait one more frame to ensure dockable's transform is fully updated
		await get_tree().physics_frame
		return dockable
	
	return null

## Helper: Get dock position from dockable
func _get_dock_position(dockable: Node2D) -> Vector2:
	if dockable.has_method("get_dock_position"):
		return dockable.get_dock_position()
	return dockable.global_position

## Helper: Get dock rotation from dockable
func _get_dock_rotation(dockable: Node2D) -> float:
	if dockable.has_method("get_dock_rotation"):
		return dockable.get_dock_rotation()
	return dockable.global_rotation

## Helper: Get dock velocity from dockable
func _get_dock_velocity(dockable: Node2D) -> Vector2:
	if dockable.has_method("get_dock_velocity"):
		return dockable.get_dock_velocity()
	return Vector2.ZERO
