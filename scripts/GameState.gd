extends Node
class_name GameState

signal cargo_changed
signal credits_changed
signal landed(at_home: bool)
signal fuel_changed(new_fuel: float)

var credits: int = 0 :
	set(value):
		credits = value
		credits_changed.emit()

var cargo := {
	"Scrap": 0
}

var hull: int = 10
var max_hull: int = 10
var fuel: float = 100.0
var max_fuel: float = 100.0
var has_drone_bay: bool = false
var drones_active: int = 0

func _ready() -> void:
	add_to_group("game_state")

func add_cargo(kind: String, amount: int) -> void:
	cargo[kind] = (cargo.get(kind, 0) as int) + amount
	cargo_changed.emit()

func clear_cargo() -> void:
	for k in cargo.keys():
		cargo[k] = 0
	cargo_changed.emit()

func consume_fuel(amount: float) -> bool:
	# Only consume fuel if we have fuel available
	if fuel <= 0.0:
		return false
	
	var old_fuel = fuel
	fuel = max(0.0, fuel - amount)
	fuel_changed.emit(fuel)
	return fuel < old_fuel  # Return true if fuel was actually consumed
