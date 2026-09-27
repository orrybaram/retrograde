extends Node
class_name Economy

## Global economy constants. Gem values live in GemData. There is no store and nothing
## to buy (docs/adr/0007).

## Service costs
const REPAIR_COST_PER_POINT: int = 3  # Credits per hull point
const REFUEL_COST_PER_POINT: float = 0.3  # Credits per fuel point


func _ready() -> void:
	add_to_group("economy")
