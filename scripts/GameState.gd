extends Node
class_name GameState

signal credits_changed

var credits: int = 1000 :
	set(value):
		credits = value
		credits_changed.emit()

var has_drone_bay: bool = false
var drones_active: int = 0

func _ready() -> void:
	add_to_group("game_state")

## Compatibility wrapper for clearing cargo.
## Now delegates to InventoryManager.clear_inventory()
func clear_cargo() -> void:
	InventoryManager.clear_inventory()
