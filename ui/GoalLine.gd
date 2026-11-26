extends Control
class_name GoalLine

## The current goal (Objectives.current), one line in the HUD's top-left corner with a
## detail under it where there is one: `> WAKE SR-7'S CORE`, or `> POWER VELD'S GATE` over
## `320/600 ST`. When the goal changes, the old line stamps [ OK ] in green and fades, then
## the new one types on with a blinking NEW tag. The first goal after a load just types on.
## It stays dark while the manual diagnostic has the controls, since each section there
## already says what to do.

const MARGIN := Vector2(16.0, 14.0)
const TEXT_SIZE := 12
const DETAIL_SIZE := 10
const OUTLINE := 4
const PREFIX := "> "
const STAMP := "  [ OK ]"
## Characters per second, as the diagnostic types.
const TYPE_RATE := 40.0
## How long the finished line holds its stamp, then fades.
const STAMP_HOLD := 0.8
const STAMP_FADE := 0.4
## How long NEW blinks after a new goal has typed, and how fast.
const NEW_TIME := 3.0
const NEW_HZ := 2.5
## How often the goal is worked out again (s).
const REFRESH := 0.25

var boot_log: BootLog = null

var _line: Label
var _detail: Label
var _tag: Label
## The goal showing, and the finished one stamping out before it.
var _goal := Objectives.NONE
var _finished := ""
var _stamp_t := 0.0
var _type_t := 0.0
var _new_t := -1.0
var _refresh_t := 0.0


func _ready() -> void:
	name = "GoalLine"
	add_to_group("screen_effects")
	mouse_filter = MOUSE_FILTER_IGNORE
	position = MARGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(row)
	_line = _label(TEXT_SIZE, Colors.PRIMARY, row)
	_tag = _label(DETAIL_SIZE, Colors.SPACE_BG, row)
	_tag.text = "NEW"
	_tag.remove_theme_constant_override("outline_size")
	var tag_box := StyleBoxFlat.new()
	tag_box.bg_color = Colors.PRIMARY
	tag_box.set_content_margin_all(3)
	_tag.add_theme_stylebox_override("normal", tag_box)
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# The detail lines up under the goal's words, not under its prompt
	var indent := MarginContainer.new()
	indent.mouse_filter = MOUSE_FILTER_IGNORE
	var font := _line.get_theme_font("font")
	if font:
		indent.add_theme_constant_override("margin_left",
				roundi(font.get_string_size(PREFIX, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x))
	box.add_child(indent)
	_detail = _label(DETAIL_SIZE, Colors.MUSTARD_PALE, indent)
	# Out in the Void the goal goes the way of the rest of the HUD
	add_child(VoidGlitch.new())
	_show(false)


## What the line says right now (for scenarios): the goal's text, or "" when dark.
func goal_text() -> String:
	return _goal["text"] if visible else ""


func goal_detail() -> String:
	return _goal["detail"] if visible else ""


## Whether NEW is up beside the line.
func is_new() -> bool:
	return _new_t >= 0.0 and _new_t < NEW_TIME


## Main.clear_screen_effects: a new game, a load or a quit to the menu starts the line over,
## so the goal it lands on types on fresh, without NEW.
func clear_now() -> void:
	_show(false)
	_goal = Objectives.NONE
	_finished = ""
	_new_t = -1.0
	_refresh_t = 0.0


func _process(delta: float) -> void:
	if not _active():
		clear_now()
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = REFRESH
		_take(_work_out())
	_animate(delta)


func _take(goal: Dictionary) -> void:
	if goal["text"] != _goal["text"]:
		var was: String = _goal["text"]
		_goal = goal
		_type_t = 0.0
		_new_t = -1.0
		_finished = was if visible and was != "" else ""
		_stamp_t = 0.0
		_line.text = PREFIX + goal["text"]
		_detail.text = goal["detail"]
		_line.visible_characters = 0
		_detail.visible_characters = 0
	elif goal["detail"] != _goal["detail"]:
		_goal = goal
		_detail.text = goal["detail"]
	_show(_goal["text"] != "" or _finished != "")


func _animate(delta: float) -> void:
	if _finished != "":
		_stamp_t += delta
		_line.text = PREFIX + _finished + STAMP
		_line.visible_characters = -1
		_line.add_theme_color_override("font_color", Colors.SUCCESS)
		_line.modulate.a = 1.0 - clampf((_stamp_t - STAMP_HOLD) / STAMP_FADE, 0.0, 1.0)
		_detail.visible = false
		_tag.visible = false
		if _stamp_t < STAMP_HOLD + STAMP_FADE:
			return
		# Stamped and gone: the new goal types on, and is new
		_finished = ""
		_new_t = 0.0
		_line.text = PREFIX + _goal["text"]
		_line.modulate.a = 1.0
		_line.add_theme_color_override("font_color", Colors.PRIMARY)
		_type_t = 0.0
	_type_t += delta
	var head := int(_type_t * TYPE_RATE)
	_line.visible_characters = mini(head, _line.text.length())
	var typed := head >= _line.text.length()
	_detail.visible = typed and _detail.text != ""
	_detail.visible_characters = maxi(0, head - _line.text.length())
	if typed and _new_t >= 0.0:
		_new_t += delta
	_tag.visible = typed and is_new() and fmod(_new_t * NEW_HZ, 1.0) < 0.65


func _work_out() -> Dictionary:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if gs == null:
		return Objectives.NONE
	return Objectives.current(gs.progress, gs.cradled, gs.stores,
			Objectives.next_gate(get_tree().get_nodes_in_group("gates")))


func _active() -> bool:
	if boot_log and boot_log.holds_corner():
		return false
	var main := get_tree().get_first_node_in_group("main")
	if main and main.current_game_state != main.MainGameState.PLAYING:
		return false
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	return ship != null and not ship.is_destroyed()


func _show(on: bool) -> void:
	visible = on
	if not on:
		_tag.visible = false


func _label(font_size: int, color: Color, parent: Node) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	label.add_theme_constant_override("outline_size", OUTLINE)
	parent.add_child(label)
	return label
