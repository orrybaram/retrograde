extends Control
class_name DrillMeter

## HUD bar for the ore drill, just under the landed ship: the current layer's timing
## sweep with a depth gauge, then the grade of each layer as it breaks. Mirrors
## HarvestMeter (and shares its drawing). Added to the HUD at runtime.

const BAR_SIZE := Vector2(150, 10)
const OFFSET_Y := 46.0
const RESULT_HOLD := 0.9
const PIP := 6.0

const GRADE_TEXT := {
	HarvestTiming.Grade.PERFECT: "P E R F E C T",
	HarvestTiming.Grade.GOOD: "C L E A N",
	HarvestTiming.Grade.LATE: "C R A C K E D",
	HarvestTiming.Grade.OVERLOAD: "K I C K B A C K",
}

var _alpha := 0.0
var _result_text := ""
var _result_color := Colors.PRIMARY
var _result_time := 0.0
var _anchor := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.drill_struck.connect(_on_drill_struck)
	EventBus.dig_ended.connect(_on_dig_ended)

func _drill() -> OreDrill:
	var ship := get_tree().get_first_node_in_group("ship")
	return ship.get_node_or_null("OreDrill") as OreDrill if ship else null

func _on_drill_struck(_ore: OreDeposit, grade: HarvestTiming.Grade, gem_ids: Array[String], _layer: int, final: bool) -> void:
	_show_result(GRADE_TEXT.get(grade, ""), Colors.DANGER if grade == HarvestTiming.Grade.LATE else GemData.color_of(GemData.best_of(gem_ids)))
	if final:
		_result_text += "   B E D R O C K"

func _on_dig_ended(_ore: OreDeposit, reason: String, _layers: int) -> void:
	match reason:
		"overload":
			_show_result(GRADE_TEXT[HarvestTiming.Grade.OVERLOAD], Colors.DANGER)
		"bank":
			_show_result("B A N K E D", Colors.PRIMARY)

func _show_result(text: String, color: Color) -> void:
	_result_text = text
	_result_color = color
	_result_time = RESULT_HOLD

func _active(drill: OreDrill) -> bool:
	return drill != null and drill.phase == OreDrill.Phase.DIGGING and drill.timing != null

func _process(delta: float) -> void:
	if _result_time > 0.0:
		_result_time -= delta
	var target := 1.0 if _active(_drill()) or _result_time > 0.0 else 0.0
	var prev := _alpha
	_alpha = move_toward(_alpha, target, delta * (10.0 if target > _alpha else 4.0))
	if _alpha > 0.0 or prev > 0.0:
		queue_redraw()

func _draw() -> void:
	if _alpha <= 0.0:
		return
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	if ship:
		var screen := get_global_transform_with_canvas().affine_inverse() * ship.get_global_transform_with_canvas().origin
		_anchor = screen + Vector2(-BAR_SIZE.x / 2.0, OFFSET_Y)
	var font := get_theme_default_font()
	var rect := Rect2(_anchor, BAR_SIZE)
	var a := _alpha
	var drill := _drill()

	draw_rect(rect, HarvestMeter._c(Colors.UI_BACKGROUND, a))
	if _result_time > 0.0 and (not _active(drill) or not drill.is_holding()):
		HarvestMeter.draw_result(self, rect, font, _result_text, _result_color, a * clampf(_result_time / 0.3, 0.0, 1.0))
	elif _active(drill):
		var title := "D R I L L   %d / %d" % [drill.layer + 1, drill.layer_count()]
		draw_string(font, _anchor + Vector2(0, -4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, HarvestMeter.FONT_SIZE, HarvestMeter._c(Colors.PRIMARY, a))
		HarvestMeter.draw_sweep(self, rect, drill.timing, a)
	draw_rect(rect, HarvestMeter._c(Colors.UI_BORDER, a), false, 1.0)

	# Depth gauge: one pip per layer, filled once broken
	if drill:
		for i in drill.layer_count():
			var pip := Rect2(rect.position + Vector2(i * (PIP + 3.0), BAR_SIZE.y + 5.0), Vector2(PIP, PIP))
			var broken := i < drill.layer
			draw_rect(pip, HarvestMeter._c(Colors.PRIMARY if broken else Colors.PRIMARY_DIM, a), broken, -1.0 if broken else 1.0)
