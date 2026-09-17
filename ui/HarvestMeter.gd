extends Control
class_name HarvestMeter

## Terminal-style extraction meter drawn just under the ship while harvesting.
## Shows the HarvestTiming sweep: sweet zone, PERFECT slice, and the moving marker,
## then flashes the grade when a hit lands. Added to the HUD at runtime.

const BAR_SIZE := Vector2(150, 10)
const OFFSET_Y := 46.0
const FONT_SIZE := 10
const RESULT_HOLD := 0.9

const GRADE_TEXT := {
	HarvestTiming.Grade.PERFECT: "P E R F E C T",
	HarvestTiming.Grade.GOOD: "C L E A N",
	HarvestTiming.Grade.LATE: "T O O   L A T E",
	HarvestTiming.Grade.OVERLOAD: "O V E R L O A D",
}

var _scrap: ScrapNode = null
var _ship: Node2D = null
var _alpha := 0.0
var _result_text := ""
var _result_color := Colors.PRIMARY
var _result_time := 0.0
var _anchor := Vector2.ZERO  # last bar position, kept while the result lingers

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.harvest_began.connect(_on_harvest_began)
	EventBus.harvest_hit.connect(_on_harvest_hit)

func _on_harvest_began(scrap: ScrapNode) -> void:
	_scrap = scrap
	_result_text = ""
	_result_time = 0.0

func _on_harvest_hit(scrap: ScrapNode, grade: HarvestTiming.Grade, gem_ids: Array[String], final: bool) -> void:
	if scrap != _scrap:
		return
	_result_text = GRADE_TEXT.get(grade, "")
	if final:
		_result_text += "   B R E A K"
	var botched := grade == HarvestTiming.Grade.LATE or grade == HarvestTiming.Grade.OVERLOAD
	_result_color = Colors.DANGER if botched else GemData.color_of(GemData.best_of(gem_ids))
	_result_time = RESULT_HOLD
	_scrap = null

func _active() -> bool:
	return _scrap != null and is_instance_valid(_scrap) and _scrap.timing != null \
		and not _scrap._is_depleted and (_scrap.is_harvesting() or _scrap.timing.progress > 0.0)

func _process(delta: float) -> void:
	if _result_time > 0.0:
		_result_time -= delta
	var target := 1.0 if _active() or _result_time > 0.0 else 0.0
	var prev := _alpha
	_alpha = move_toward(_alpha, target, delta * (10.0 if target > _alpha else 4.0))
	# Redraw on the frame alpha reaches 0 too, or the last faint frame stays on screen.
	if _alpha > 0.0 or prev > 0.0:
		queue_redraw()

func _draw() -> void:
	if _alpha <= 0.0:
		return
	if not _ship or not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("ship") as Node2D
	if _ship:
		var screen := get_global_transform_with_canvas().affine_inverse() * _ship.get_global_transform_with_canvas().origin
		_anchor = screen + Vector2(-BAR_SIZE.x / 2.0, OFFSET_Y)

	var font := get_theme_default_font()
	var rect := Rect2(_anchor, BAR_SIZE)
	var a := _alpha

	draw_rect(rect, _c(Colors.UI_BACKGROUND, a))

	if _active():
		var t := _scrap.timing
		draw_string(font, _anchor + Vector2(0, -4), "E X T R A C T", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _c(Colors.PRIMARY, a))

		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0) if t.in_zone() else 0.0
		draw_rect(Rect2(rect.position, Vector2(BAR_SIZE.x * t.progress, BAR_SIZE.y)), _c(Colors.PRIMARY_SUBTLE, a))
		draw_rect(_span(rect, t.zone_start, t.zone_end), _c(Colors.PRIMARY_MEDIUM, a * (1.0 + pulse)))
		draw_rect(_span(rect, t.perfect_start(), t.perfect_end()), _c(Colors.PRIMARY, a * (0.55 + 0.45 * pulse)))

		var x := rect.position.x + BAR_SIZE.x * t.progress
		var marker_color := Colors.TEXT
		if t.progress > t.zone_end:
			marker_color = Colors.DANGER
		draw_line(Vector2(x, rect.position.y - 4), Vector2(x, rect.end.y + 4), _c(marker_color, a), 2.0)
	elif _result_text != "":
		var fade := clampf(_result_time / 0.3, 0.0, 1.0)
		draw_string(font, _anchor + Vector2(0, -4), _result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _c(_result_color, a * fade))
		draw_rect(rect, _c(_result_color, a * 0.35 * fade))

	draw_rect(rect, _c(Colors.UI_BORDER, a), false, 1.0)

func _span(rect: Rect2, from: float, to: float) -> Rect2:
	return Rect2(rect.position + Vector2(rect.size.x * from, 0), Vector2(rect.size.x * (to - from), rect.size.y))

func _c(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))
