extends Node2D
class_name Item

## Base class for all inventory items.
## Each item type should extend this class and provide a visual representation for UI display.

@export var item_name: String = ""
## Display name of the item

@export var description: String = ""
## Description of the item

@export var item_id: String = ""
## Unique identifier for the item (e.g., "scrap")

@onready var _visual_node: Node2D = null

func _ready() -> void:
	# Find the visual representation node
	_find_visual_node()

func _find_visual_node() -> void:
	# Look for common visual node types (Sprite2D, Polygon2D, ColorRect, etc.)
	for child in get_children():
		if child is Sprite2D or child is Polygon2D or child is ColorRect:
			_visual_node = child as Node2D
			return
		# Also check for nodes with "Visual" in their name
		if child.name.contains("Visual") or child.name.contains("Sprite") or child.name.contains("Icon"):
			_visual_node = child as Node2D
			return

## Get a visual representation of this item for UI display.
## Returns a duplicate of the visual node, or null if no visual is found.
func get_ui_visual() -> Node2D:
	if not _visual_node:
		_find_visual_node()
	
	if _visual_node:
		# Return a duplicate that can be used in UI
		return _visual_node.duplicate() as Node2D
	
	return null

## Get the visual node directly (for inspection, not for UI use)
func get_visual_node() -> Node2D:
	if not _visual_node:
		_find_visual_node()
	return _visual_node

