extends MinimapTarget
class_name OreMinimapTarget

## MinimapTarget for a revealed OreDeposit: a small echo on its planet's rim. It leaves the
## map once the seam is spent and comes back when the seam refills.

## A seam's reach, world px, when full; it shrinks as the seam is worked down.
const ECHO_RADIUS := 60.0

var ore: OreDeposit

func _init(deposit: OreDeposit) -> void:
	ore = deposit

func get_minimap_position() -> Vector2:
	return ore.global_position if is_instance_valid(ore) else Vector2.ZERO

func echo_world_radius() -> float:
	return ECHO_RADIUS * ore.remaining() if is_instance_valid(ore) else ECHO_RADIUS

func is_minimap_visible() -> bool:
	return is_instance_valid(ore) and ore.is_revealed() and not ore.is_spent()

func get_minimap_node() -> Node2D:
	return ore
