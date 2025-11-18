extends Node
class_name Economy

const PRICES := {
	"Scrap": 2
}

static func get_cost(upgrade_name: String) -> int:
	match upgrade_name:
		"FuelTank_I":
			return 40
		"Hull_I":
			return 30
		"DroneBay_I":
			return 60
		_:
			return 0

static func apply_upgrade(upgrade_name: String, gs) -> void:
	match upgrade_name:
		"FuelTank_I":
			gs.max_fuel *= 1.25
		"Hull_I":
			gs.max_hull += 5
		"DroneBay_I":
			gs.has_drone_bay = true
		_:
			pass

func _ready() -> void:
	add_to_group("economy")
