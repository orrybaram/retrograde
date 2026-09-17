extends ScrapNodeState
class_name ScrapIdleState

## Resting state: node is orbiting, no ship in range.
## Transitions to ScrapInRangeState when a ship enters the harvest area.
## Transitions are driven by ScrapNode._on_harvest_area_entered.
