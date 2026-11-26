extends ScrapNodeState
class_name ScrapIdleState

## Resting state: node is orbiting, no ship in range.
## Transitions to ScrapInRangeState when a ship enters the harvest area.
## Transitions are driven by ScrapNode._on_harvest_area_entered.

func enter() -> void:
	super.enter()
	# Walking away forfeits any partial extraction.
	if scrap_node.timing:
		scrap_node.timing.progress = 0.0
		scrap_node.sync_harvest_visual()
