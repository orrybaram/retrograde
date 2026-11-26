extends Node
class_name GemMagnet

## Small magnetic field on the ship. Pulls loose gems in (harder the closer they are)
## and collects any that touch the hull. Gems that don't fit in the hold are ignored,
## so they keep floating until there is room or they expire. Added by Ship at runtime.

const RADIUS := 70.0
const PICKUP_RADIUS := 14.0
const PULL_SPEED_MIN := 35.0
const PULL_SPEED_MAX := 170.0

@onready var ship: Ship = get_parent() as Ship

## Closing speed for a gem `dist` px away (0 outside the field).
static func pull_speed(dist: float) -> float:
	if dist > RADIUS:
		return 0.0
	return lerpf(PULL_SPEED_MAX, PULL_SPEED_MIN, dist / RADIUS)

static func fits(item_id: String, max_space: float) -> bool:
	return InventoryManager.can_add_item(item_id, 1, max_space)

func _physics_process(delta: float) -> void:
	if not ship or not ship.visible or ship.is_destroyed() or ship.is_locked_to_planet():
		return
	var pos := ship.global_position
	for gem in Gem.active.duplicate():
		if not is_instance_valid(gem) or not fits(gem.item_id, ship.max_cargo_weight):
			continue
		var dist := pos.distance_to(gem.global_position)
		if dist <= PICKUP_RADIUS:
			gem.collect()
		elif dist <= RADIUS:
			gem.pull_toward(pos, ship.linear_velocity, pull_speed(dist), delta)
