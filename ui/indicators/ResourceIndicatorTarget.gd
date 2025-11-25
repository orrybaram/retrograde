extends IndicatorTarget
class_name ResourceIndicatorTarget

## Wraps ResourceNode to provide indicator interface for resources.

var resource_node: ResourceNode = null

func _init(node: ResourceNode) -> void:
	resource_node = node

func get_indicator_priority() -> int:
	if not resource_node or not is_instance_valid(resource_node):
		return 0
	# Higher priority for resources with more amount
	return resource_node.amount

func get_indicator_position() -> Vector2:
	if not resource_node or not is_instance_valid(resource_node):
		return Vector2.ZERO
	return resource_node.global_position

func get_indicator_bounds() -> Rect2:
	if not resource_node or not is_instance_valid(resource_node):
		return Rect2()
	
	# Find visual node and get its bounds
	var visual = resource_node._find_visual_node()
	if not visual:
		# Default bounds if no visual found
		return Rect2(-20, -20, 40, 40)
	
	var bounds: Rect2
	
	if visual is ColorRect:
		var color_rect = visual as ColorRect
		var size = color_rect.size
		bounds = Rect2(-size.x / 2, -size.y / 2, size.x, size.y)
	elif visual is Polygon2D:
		var polygon = visual as Polygon2D
		var points = polygon.polygon
		if points.is_empty():
			return Rect2(-20, -20, 40, 40)
		
		# Calculate bounding box from polygon points (in local space of polygon)
		var min_x = INF
		var min_y = INF
		var max_x = -INF
		var max_y = -INF
		
		for point in points:
			var scaled_point = point * polygon.scale
			min_x = min(min_x, scaled_point.x)
			min_y = min(min_y, scaled_point.y)
			max_x = max(max_x, scaled_point.x)
			max_y = max(max_y, scaled_point.y)
		
		# Convert to resource_node local space (accounting for polygon position)
		var polygon_local_pos = polygon.position
		bounds = Rect2(
			polygon_local_pos.x + min_x,
			polygon_local_pos.y + min_y,
			max_x - min_x,
			max_y - min_y
		)
	elif visual is Sprite2D:
		var sprite = visual as Sprite2D
		var texture = sprite.texture
		if texture:
			var size = texture.get_size() * sprite.scale
			bounds = Rect2(-size.x / 2, -size.y / 2, size.x, size.y)
		else:
			bounds = Rect2(-20, -20, 40, 40)
	else:
		# Default bounds
		bounds = Rect2(-20, -20, 40, 40)
	
	return bounds

func get_indicator_info() -> Dictionary:
	if not resource_node or not is_instance_valid(resource_node):
		return {}
	
	var details: Array[String] = []
	details.append("Amount: %d / %d" % [resource_node.amount, resource_node.max_amount])
	details.append("Harvest Rate: %.1f/s" % resource_node.harvest_rate)
	
	return {
		"title": resource_node.kind,
		"subtitle": "Resource",
		"details": details
	}

func is_indicator_visible() -> bool:
	if not resource_node or not is_instance_valid(resource_node):
		return false
	
	# Only show indicator when ship is in range and resource is not depleted
	return resource_node._ship_in_range != null and not resource_node._is_depleted and resource_node.amount > 0

func get_indicator_node() -> Node2D:
	return resource_node
