extends Node
class_name Economy

const PRICES := {
	"scrap": 2
}

const REPAIR_COST_PER_POINT: int = 1  # Credits per hull point
const REFUEL_COST_PER_POINT: int = 1  # Credits per fuel point

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

static func apply_upgrade(upgrade_name: String, gs, ship: Ship = null) -> void:
	match upgrade_name:
		"FuelTank_I":
			if ship:
				ship.max_fuel *= 1.25
				ship.fuel = ship.max_fuel  # Refill to new max
		"Hull_I":
			if ship:
				ship.max_hull += 5
				ship.hull_strength = ship.max_hull  # Heal to new max
		"DroneBay_I":
			gs.has_drone_bay = true
		_:
			pass

func _ready() -> void:
	add_to_group("economy")
