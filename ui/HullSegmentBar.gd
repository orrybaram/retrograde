extends Control
class_name HullSegmentBar

## Segmented hull/HP display. One block per 10 HP.
## Filled blocks use amber gradient based on health %, empty blocks use dark outline.

const HP_PER_SEGMENT: float = 10.0
const SEGMENT_WIDTH: float = 10.0
const SEGMENT_HEIGHT: float = 14.0
const SEGMENT_GAP: float = 2.0

var current_hull: float = 100.0
var max_hull: float = 100.0

func set_value(current: float, max_val: float) -> void:
	current_hull = current
	max_hull = max_val
	custom_minimum_size.x = _total_segments() * (SEGMENT_WIDTH + SEGMENT_GAP) - SEGMENT_GAP
	custom_minimum_size.y = SEGMENT_HEIGHT
	queue_redraw()

func _total_segments() -> int:
	return ceili(max_hull / HP_PER_SEGMENT)

func _draw() -> void:
	var total = _total_segments()
	if total <= 0:
		return

	var filled = ceili(current_hull / HP_PER_SEGMENT)
	filled = clampi(filled, 0, total)
	var hull_percent = (current_hull / max_hull * 100.0) if max_hull > 0 else 0.0
	var fill_color = _hull_color(hull_percent)
	var empty_color = Colors.PRIMARY_DIM

	for i in range(total):
		var x = i * (SEGMENT_WIDTH + SEGMENT_GAP)
		var rect = Rect2(x, 0, SEGMENT_WIDTH, SEGMENT_HEIGHT)
		if i < filled:
			draw_rect(rect, fill_color)
		else:
			draw_rect(rect, empty_color)

func _hull_color(percent: float) -> Color:
	if percent < 10:
		return Colors.FUEL_EMPTY
	elif percent < 30:
		return Colors.FUEL_QUARTER
	elif percent < 60:
		return Colors.FUEL_HALF
	else:
		return Colors.PRIMARY
