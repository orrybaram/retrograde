extends Control
class_name PlacardPanel

## The placard on a piece of hardware that listens (docs/SWEEP.md §5, docs/OPENING.md §5),
## read off it as the ship comes close: the Procedure in Notation, drawn from the
## Procedure's own steps so it can never disagree with what the hardware wants. Drawn on
## the HUD beside the hardware - on the far side of it from the ship, so it never covers the
## ship or its bar - with a leader back to it, so it stays legible at any zoom.
##
##   SR-7 / CORE, COLD START
##   ┌───┬───┬───┬───┬───┬───┐
##   │ ● │   │   │   │   │   │   ‹seat›
##   ...
##             ▓▓▓  OVERDRIVE TO COMMIT
##
## The dots are the part to copy; the glyph column is the optional channel.

const FONT_SIZE := 11
const SMALL_SIZE := 9
const CELL := Vector2(18, 14)
const PAD := 10.0
const GLYPH_WIDTH := 62.0
## How far the panel sits from the hardware on screen, px, and from the screen's edges.
const OFFSET := Vector2(110, -40)
const MARGIN := 16.0
## Fully shown this far inside Resonance.REACH, px; fades out over the rest.
const FADE := 120.0
const COMMIT_TEXT := "OVERDRIVE TO COMMIT"

var _alpha := 0.0
var _target: Node2D = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	var want := 0.0
	var near := Resonance.listener_near(get_tree(), ship.global_position) if ship else null
	if near is Node2D and near.has_method("placard") and not ship.is_gone():
		_target = near
		var d := ship.global_position.distance_to(_target.procedure_point())
		want = clampf((Resonance.REACH - d) / FADE, 0.0, 1.0)
	var prev := _alpha
	_alpha = move_toward(_alpha, want, delta * 3.0)
	if _alpha > 0.0 or prev > 0.0:
		queue_redraw()

func panel_size(def: ProcedureDef, font: Font) -> Vector2:
	var rows := def.marks().size()
	var title := font.get_string_size(def.title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var commit := CELL.x * 3.5 + 8 + font.get_string_size(COMMIT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
	var body := CELL.x * Resonance.SLOTS + 10 + GLYPH_WIDTH
	return Vector2(PAD * 2 + maxf(body, maxf(title, commit)), PAD * 2 + 16 + rows * CELL.y + 22)

func _draw() -> void:
	if _alpha <= 0.0 or _target == null or not is_instance_valid(_target):
		return
	var def: ProcedureDef = _target.placard()
	var a := _alpha
	var font := get_theme_default_font()
	var at := get_global_transform_with_canvas().affine_inverse() * _target.get_global_transform_with_canvas().origin
	var size := panel_size(def, font)
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	var ship_at := get_global_transform_with_canvas().affine_inverse() * ship.get_global_transform_with_canvas().origin if ship else at
	var left := ship_at.x >= at.x
	var x := at.x - OFFSET.x - size.x if left else at.x + OFFSET.x
	var box := Rect2(Vector2(x, at.y + OFFSET.y - size.y * 0.5), size)
	var view := get_viewport_rect().size
	box.position = box.position.clamp(Vector2(MARGIN, MARGIN), view - size - Vector2(MARGIN, MARGIN))

	var corner := Vector2(box.end.x if left else box.position.x, clampf(at.y, box.position.y, box.end.y))
	draw_line(at, corner, _c(Colors.PRIMARY_DIM, a), 1.0)
	draw_rect(box, _c(Colors.UI_BACKGROUND, a))
	draw_rect(box, _c(Colors.UI_BORDER, a), false, 1.0)

	var x0 := box.position.x + PAD
	var y := box.position.y + PAD + 10
	draw_string(font, Vector2(x0, y), def.title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, _c(Colors.PRIMARY, a))
	y += 8
	var marks := def.marks()
	for row in marks.size():
		for col in Resonance.SLOTS:
			var cell := Rect2(x0 + col * CELL.x, y + row * CELL.y, CELL.x, CELL.y)
			draw_rect(cell, _c(Colors.PRIMARY_DIM, a), false, 1.0)
			if col == marks[row] - 1:
				draw_circle(cell.get_center(), 3.5, _c(Colors.PRIMARY, a))
		draw_string(font, Vector2(x0 + CELL.x * Resonance.SLOTS + 10, y + row * CELL.y + CELL.y - 3),
			def.glyph(row), HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, _c(Colors.TEXT_SECONDARY, a))
	y += marks.size() * CELL.y + 8
	var bar := Rect2(x0 + CELL.x * 2, y, CELL.x * 1.5, 8)
	draw_rect(bar, _c(Colors.PRIMARY, a))
	draw_string(font, Vector2(bar.end.x + 8, bar.end.y), COMMIT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, _c(Colors.TEXT_SECONDARY, a))

static func _c(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))
