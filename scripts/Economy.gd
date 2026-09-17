extends Node
class_name Economy

## Global economy constants. Gem values live in GemData; upgrade costs and
## effects are handled by UpgradeItem resources.

## Service costs
const REPAIR_COST_PER_POINT: int = 1  # Credits per hull point
const REFUEL_COST_PER_POINT: float = 0.3  # Credits per fuel point


func _ready() -> void:
	add_to_group("economy")
