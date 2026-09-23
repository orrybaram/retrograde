extends Control
class_name ResonanceMeter

## The Sweep's bar in its other mode (docs/SWEEP.md §3): drawn under the ship, where the
## harvest meter sits, while a Sweep is held near hardware that listens (Resonance) - and
## nowhere else. R E S O N A N C E over six Slots and the marker of the hold; past the end
## of the bar it reads O V E R D R I V E, and letting go there is the Commit.
##
## The bar draws the diagram as you play it: under it, each Mark laid down is a row with a
## dot in its Slot - the same rows of dots printed on the placard.

const BAR_SIZE := HarvestMeter.BAR_SIZE
const OFFSET_Y := HarvestMeter.OFFSET_Y
const FONT_SIZE := HarvestMeter.FONT_SIZE
## One row of the diagram under the bar, px.
const ROW_HEIGHT := 7.0
const ROW_GAP := 2.0
const DOT_RADIUS := 2.0

var _ship: Ship = null
var _alpha := 0.0
var _anchor := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _showing() -> bool:
	if _ship == null or not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("ship") as Ship
	if _ship == null or _ship.sonar == null or _ship.resonance == null:
		return false
	if not (_ship.sonar.charging or not _ship.resonance.marks.is_empty()):
		return false
	return Resonance.available_for(_ship)

func _process(delta: float) -> void:
	var target := 1.0 if _showing() else 0.0
	var prev := _alpha
	_alpha = move_toward(_alpha, target, delta * (10.0 if target > _alpha else 4.0))
	if _alpha > 0.0 or prev > 0.0:
		queue_redraw()

func _draw() -> void:
	if _alpha <= 0.0 or _ship == null or not is_instance_valid(_ship):
		return
	var screen := get_global_transform_with_canvas().affine_inverse() * _ship.get_global_transform_with_canvas().origin
	_anchor = screen + Vector2(-BAR_SIZE.x / 2.0, OFFSET_Y)
	var font := get_theme_default_font()
	var rect := Rect2(_anchor, BAR_SIZE)
	var a := _alpha
	var held := _ship.sonar.held() if _ship.sonar.charging else 0.0
	var over := Resonance.is_commit(held)

	draw_rect(rect, _c(Colors.UI_BACKGROUND, a))
	var header := "O V E R D R I V E" if over else "R E S O N A N C E"
	draw_string(font, _anchor + Vector2(0, -4), header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _c(Colors.PRIMARY, a))
	var p := clampf(held / Resonance.BAR_TIME, 0.0, 1.0)
	if p > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * p, rect.size.y)), _c(Colors.PRIMARY if over else Colors.PRIMARY_SUBTLE, a))
	var slot_w := rect.size.x / Resonance.SLOTS
	for i in range(1, Resonance.SLOTS):
		var x := rect.position.x + i * slot_w
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), _c(Colors.PRIMARY_DIM, a), 1.0)
	if _ship.sonar.charging and not over:
		var mx := rect.position.x + rect.size.x * p
		draw_line(Vector2(mx, rect.position.y - 4), Vector2(mx, rect.end.y + 4), _c(Colors.TEXT, a), 2.0)
	draw_rect(rect, _c(Colors.UI_BORDER, a), false, 1.0)

	# The diagram so far: a row per Mark, a dot in its Slot
	var y := rect.end.y + ROW_GAP + 2.0
	for mark in _ship.resonance.marks:
		for i in Resonance.SLOTS:
			var cell := Rect2(rect.position.x + i * slot_w, y, slot_w, ROW_HEIGHT)
			draw_rect(cell, _c(Colors.PRIMARY_DIM, a * 0.6), false, 1.0)
			if i == mark - 1:
				draw_circle(cell.get_center(), DOT_RADIUS, _c(Colors.PRIMARY, a))
		y += ROW_HEIGHT + ROW_GAP

static func _c(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))
