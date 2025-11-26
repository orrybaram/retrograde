extends Control

## Draws a square grid background with equal horizontal and vertical lines.

@export var grid_cells: int = 10  # Number of grid cells (creates grid_cells+1 lines in each direction)
var grid_color: Color = Color(1.0, 0.75, 0.0, 0.3)  # Terminal amber, semi-transparent
var background_color: Color = Color(0.1, 0.1, 0.1, 0.8)

func _draw() -> void:
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	
	if grid_cells <= 0:
		return
	
	# Calculate cell size for each dimension to fill the entire container
	var cell_width = size.x / grid_cells
	var cell_height = size.y / grid_cells
	
	# Draw vertical grid lines (1px wide) - fill full height
	for i in range(grid_cells + 1):
		var x = i * cell_width
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	
	# Draw horizontal grid lines (1px wide) - fill full width, equal number to vertical lines
	for i in range(grid_cells + 1):
		var y = i * cell_height
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)

func _ready() -> void:
	# Redraw when size changes
	resized.connect(queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
