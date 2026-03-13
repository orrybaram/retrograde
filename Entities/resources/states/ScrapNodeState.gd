extends State
class_name ScrapNodeState

## Base state for ScrapNode. Provides typed access to the scrap node entity.

var scrap_node: ScrapNode:
	get:
		return entity as ScrapNode
