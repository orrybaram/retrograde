extends Node
class_name GameState

signal cargo_changed
signal credits_changed

var credits: int = 1000 :
	set(value):
		credits = value
		credits_changed.emit()

var cargo := {
	"Scrap": 0
}

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
