extends RefCounted
class_name IndicatorRenderer

## Composable visual components for drawing indicators.
## All methods are static utility functions that can be reused.

const BRACKET_SIZE: float = 15.0
const BRACKET_THICKNESS: float = 2.0
const BRACKET_PADDING: float = 10.0  # Padding around the item
const LINE_DASH_LENGTH: float = 5.0
const LINE_DASH_GAP: float = 3.0
const INFO_BOX_PADDING: float = 8.0
const INFO_TITLE_FONT_SIZE: int = 12
const INFO_LINE_FONT_SIZE: int = 10

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

## Creates an info box that sizes itself to its content.
## Data keys: "title" (String) and "lines" (Array of {text, color}). See update_info_box().
static func create_info_box(data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Colors.UI_BACKGROUND
	style_box.border_color = Colors.UI_BORDER
	style_box.set_border_width_all(2)
	style_box.set_content_margin_all(INFO_BOX_PADDING)
	panel.add_theme_stylebox_override("panel", style_box)

	var vbox := VBoxContainer.new()
	vbox.name = "Lines"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	# PanelContainer grows on its own but never shrinks back (e.g. once the theme font applies)
	panel.minimum_size_changed.connect(panel.reset_size)

	update_info_box(panel, data)
	return panel

## Syncs an existing info box with fresh data. Cheap to call every frame:
## labels are only touched when their text or color actually changes.
static func update_info_box(panel: Control, data: Dictionary) -> void:
	var vbox := panel.get_node_or_null("Lines") as VBoxContainer
	if not vbox:
		return

	var rows: Array = []
	if data.has("title"):
		var spaced := " ".join(str(data["title"]).to_upper().split(""))
		rows.append({"text": spaced, "color": Colors.PRIMARY, "size": INFO_TITLE_FONT_SIZE})
	rows.append_array(data.get("lines", []))

	while vbox.get_child_count() > rows.size():
		var extra := vbox.get_child(vbox.get_child_count() - 1)
		vbox.remove_child(extra)
		extra.queue_free()
	while vbox.get_child_count() < rows.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

	for i in rows.size():
		var row: Dictionary = rows[i]
		var label := vbox.get_child(i) as Label
		var text := str(row.get("text", ""))
		var color: Color = row.get("color", Colors.TEXT)
		var font_size: int = row.get("size", INFO_LINE_FONT_SIZE)
		if label.text != text:
			label.text = text
		if label.get_theme_color("font_color") != color:
			label.add_theme_color_override("font_color", color)
		if label.get_theme_font_size("font_size") != font_size:
			label.add_theme_font_size_override("font_size", font_size)
