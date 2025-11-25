extends RefCounted
class_name IndicatorRenderer

## Composable visual components for drawing indicators.
## All methods are static utility functions that can be reused.

const BRACKET_SIZE: float = 15.0
const BRACKET_THICKNESS: float = 2.0
const BRACKET_PADDING: float = 10.0  # Padding around the item
const LINE_DASH_LENGTH: float = 5.0
const LINE_DASH_GAP: float = 3.0

## Draws corner brackets around the given bounds
static func draw_bracket(canvas: CanvasItem, bounds: Rect2, color: Color) -> void:
	# Expand bounds with padding
	var padded_bounds = Rect2(
		bounds.position - Vector2(BRACKET_PADDING, BRACKET_PADDING),
		bounds.size + Vector2(BRACKET_PADDING * 2, BRACKET_PADDING * 2)
	)
	
	var top_left = padded_bounds.position
	var top_right = padded_bounds.position + Vector2(padded_bounds.size.x, 0)
	var bottom_left = padded_bounds.position + Vector2(0, padded_bounds.size.y)
	var bottom_right = padded_bounds.position + padded_bounds.size
	
	# Top-left bracket
	canvas.draw_line(top_left, top_left + Vector2(BRACKET_SIZE, 0), color, BRACKET_THICKNESS)
	canvas.draw_line(top_left, top_left + Vector2(0, BRACKET_SIZE), color, BRACKET_THICKNESS)
	
	# Top-right bracket
	canvas.draw_line(top_right, top_right - Vector2(BRACKET_SIZE, 0), color, BRACKET_THICKNESS)
	canvas.draw_line(top_right, top_right + Vector2(0, BRACKET_SIZE), color, BRACKET_THICKNESS)
	
	# Bottom-left bracket
	canvas.draw_line(bottom_left, bottom_left + Vector2(BRACKET_SIZE, 0), color, BRACKET_THICKNESS)
	canvas.draw_line(bottom_left, bottom_left - Vector2(0, BRACKET_SIZE), color, BRACKET_THICKNESS)
	
	# Bottom-right bracket
	canvas.draw_line(bottom_right, bottom_right - Vector2(BRACKET_SIZE, 0), color, BRACKET_THICKNESS)
	canvas.draw_line(bottom_right, bottom_right - Vector2(0, BRACKET_SIZE), color, BRACKET_THICKNESS)

## Draws a dotted line between two points
static func draw_dotted_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	var direction = (to - from).normalized()
	var distance = from.distance_to(to)
	var current_pos = from
	var total_length = LINE_DASH_LENGTH + LINE_DASH_GAP
	
	while current_pos.distance_to(from) < distance:
		var dash_end = current_pos + direction * LINE_DASH_LENGTH
		# Clamp dash_end to not exceed destination
		if dash_end.distance_to(from) > distance:
			dash_end = to
		
		canvas.draw_line(current_pos, dash_end, color, 2.0)
		
		current_pos += direction * total_length
		if current_pos.distance_to(from) >= distance:
			break

## Creates an info box Control node with the given data
static func create_info_box(data: Dictionary) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(150, 80)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	# Title
	if data.has("title"):
		var title_label = Label.new()
		title_label.text = str(data["title"])
		title_label.add_theme_font_size_override("font_size", 16)
		title_label.add_theme_color_override("font_color", Color.WHITE)
		vbox.add_child(title_label)
	
	# Subtitle
	if data.has("subtitle"):
		var subtitle_label = Label.new()
		subtitle_label.text = str(data["subtitle"])
		subtitle_label.add_theme_font_size_override("font_size", 12)
		subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(subtitle_label)
	
	# Details (array of strings)
	if data.has("details") and data["details"] is Array:
		for detail in data["details"]:
			var detail_label = Label.new()
			detail_label.text = str(detail)
			detail_label.add_theme_font_size_override("font_size", 11)
			detail_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			vbox.add_child(detail_label)
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style_box.border_color = Color(0.5, 0.5, 0.5)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style_box)
	
	return panel
