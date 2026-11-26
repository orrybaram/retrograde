extends RefCounted
class_name Dockable

## What anything the ship can dock at presents: a Gate's berth, a space port. GDScript
## has no interfaces, so a dockable is a Node2D in group `GROUP` that has every method in
## `METHODS`; flight and spawning ask this class, never the node, whether one qualifies.
##
##   get_dock_position() -> Vector2   where the docked ship sits, world space
##   get_dock_rotation() -> float     the berth's surface; the ship lies across it
##   get_dock_distance() -> float     how close counts as docked
##   get_dock_velocity() -> Vector2   how the berth is moving
##   accepts_docking() -> bool        whether a ship can dock there right now

const GROUP := "dockable"
const METHODS: Array[StringName] = [
	&"get_dock_position", &"get_dock_rotation", &"get_dock_distance",
	&"get_dock_velocity", &"accepts_docking",
]

## Is `node` something the ship can dock at (whether or not it takes a ship right now)?
static func is_dockable(node: Object) -> bool:
	if node == null or not is_instance_valid(node) or not node is Node2D:
		return false
	for method in METHODS:
		if not node.has_method(method):
			return false
	return true

## Would `node` take a ship right now?
static func accepts(node: Object) -> bool:
	return is_dockable(node) and node.accepts_docking()

## Every dockable in `tree`, open or not.
static func all(tree: SceneTree) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node in tree.get_nodes_in_group(GROUP):
		if is_dockable(node):
			found.append(node as Node2D)
	return found

## The closest dockable taking ships whose dock is within its own reach of `at`, or null.
static func nearest(tree: SceneTree, at: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in all(tree):
		if not node.accepts_docking():
			continue
		var dist: float = at.distance_to(node.get_dock_position())
		if dist < node.get_dock_distance() and dist < best_dist:
			best_dist = dist
			best = node
	return best

## The heading a ship docked at `node` has: across the berth's surface.
static func ship_rotation(node: Node2D) -> float:
	return node.get_dock_rotation() + PI / -2.0

## Is a ship turned to `rotation` and moving at `velocity` slow and square enough to dock
## at `node` - under 50 px/s relative to it, within `max_angle` rad of its heading?
static func approach_ok(node: Node2D, rotation: float, velocity: Vector2, max_angle: float) -> bool:
	var slow: bool = (velocity - node.get_dock_velocity()).length() < 50.0
	var angle := absf(wrapf(rotation - ship_rotation(node), -PI, PI))
	return slow and angle <= max_angle

## Which of the ship's states docking at `node` puts it in: a Gate has its own,
## everything else docks like a port.
static func docked_state_for(node: Node2D) -> String:
	return "GateDockedState" if node.is_in_group("gates") else "LandedState"
