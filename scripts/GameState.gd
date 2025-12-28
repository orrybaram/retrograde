extends Node
class_name GameState

signal credits_changed
signal upgrade_level_changed(path: String, level: int)

var credits: int = 0 :
	set(value):
		credits = value
		credits_changed.emit()

var has_drone_bay: bool = false
var drones_active: int = 0

## Death counter - tracks total number of deaths (not displayed to player)
var death_count: int = 0

## Tracks the player's current upgrade level for each upgrade path.
## Keys are path names (e.g., "hull", "fuel_tank"), values are tier levels (0 = base, 1+ = upgraded)
var upgrade_levels: Dictionary = {}

func _ready() -> void:
	add_to_group("game_state")

## Get the player's current upgrade level for a given path.
## Returns 0 (base state) if no upgrades have been purchased for this path.
func get_upgrade_level(path: String) -> int:
	return upgrade_levels.get(path, 0)

## Set the player's upgrade level for a given path.
## Called when an upgrade is purchased.
func set_upgrade_level(path: String, level: int) -> void:
	upgrade_levels[path] = level
	upgrade_level_changed.emit(path, level)

## Compatibility wrapper for clearing cargo.
## Now delegates to InventoryManager.clear_inventory()
func clear_cargo() -> void:
	InventoryManager.clear_inventory()
