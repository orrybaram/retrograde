extends Node
class_name Economy

## Global economy constants. Gem values live in GemData. There is no store and nothing
## to buy (docs/adr/0007).

## Service costs (docs/OPENING.md §9). A full hold of ordinary gems (about 300 ST, see
## EconomyTest) buys about a full tank from empty: 150 fuel at 2 ST. A full hull from
## nothing costs the same.
const REPAIR_COST_PER_POINT: int = 3  # Stores per hull point
const REFUEL_COST_PER_POINT: float = 2.0  # Stores per fuel point


func _ready() -> void:
	add_to_group("economy")
