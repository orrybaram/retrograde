extends Node
class_name Economy

## Global economy constants and resource pricing.
## Upgrade costs and effects are now handled by UpgradeItem resources.

## Sell prices for resources (item_id -> credits)
const PRICES := {
	"slag": 1,
	"scrap": 5,
	"salvage": 15,
	"component": 40,
	"mil_spec": 100,
	"artifact": 250,
}

## Service costs
const REPAIR_COST_PER_POINT: int = 1  # Credits per hull point
const REFUEL_COST_PER_POINT: float = 0.3  # Credits per fuel point


## Get the sell price for a resource.
## Returns 0 if the resource is not in the price list.
static func get_resource_price(resource_id: String) -> int:
	return PRICES.get(resource_id, 0)


func _ready() -> void:
	add_to_group("economy")
