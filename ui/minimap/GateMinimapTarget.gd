extends MinimapTarget
class_name GateMinimapTarget

## MinimapTarget for a Gate: a medium echo, and nothing to say whether it is powered.
## Not shown at all until it has been found: its planet scanned (PlanetScanner), or the Gate
## itself reached and named (Gate.identify). A Gate is discovered, never pointed at, and it
## does not pin to the rim (docs/adr/0002).

## Roughly a Gate's reach, world px.
const ECHO_RADIUS := 220.0

var gate: Gate

func _init(g: Gate) -> void:
	gate = g

func get_minimap_position() -> Vector2:
	if gate and is_instance_valid(gate):
		return gate.global_position
	return Vector2.ZERO

func echo_world_radius() -> float:
	return ECHO_RADIUS

func is_minimap_visible() -> bool:
	if gate == null or not is_instance_valid(gate):
		return false
	return gate.is_identified() or (gate.parent_planet != null and gate.parent_planet.is_scanned())

func get_minimap_node() -> Node2D:
	return gate
