extends Node
class_name ShipSpawn

## ShipSpawn is a marker component that can be attached to dockable entities.
## It provides an optional spawn offset from the dock position.
## All actual spawning logic lives in ShipSpawner.

## Position offset relative to parent entity (in local space).
## This offset is rotated by the parent's rotation when calculating world position.
@export var spawn_offset: Vector2 = Vector2(0, -20)

func _ready() -> void:
	add_to_group("ship_spawns")
