class_name RadioPanel
extends Control

## HUD transmission box for RobotRadio: the robot on the left, its message typed out
## on the right. Continue (SPACE, with TAB/ENTER as aliases) finishes the speech, then
## moves on: next line, confirm, or close. SPACE is also the flight action key, so it
## only continues conversations that pause the game or ask for a confirm; other tips
## take TAB/ENTER and auto-dismiss after RadioLine.read_time(). Paused and confirm lines
## wait for the player. Sits bottom-right, clear of the dashboard and the action message.
## Hidden while a menu is open. Runs while paused. Added to the HUD at runtime.

const PANEL_SIZE := Vector2(600, 202)
const SCREEN_MARGIN := Vector2(16, 72)  # right, bottom (clears action message + save indicator)
const TITLE := "/ I N C O M I N G   T R A N S M I S S I O N /"
const ROBOT_FONT_SIZE := 16
const TEXT_SIZE := 12
const SMALL_SIZE := 10
const CHARS_PER_SECOND := 40.0
const FADE_TIME := 0.15
## Menus that sit in the same CanvasLayer as the HUD but never block the radio.
const NON_BLOCKING := [&"HUD", &"IndicatorManager"]

var robot: RobotView

var _line: RadioLine = null
var _conv: RadioConversation = null
var _message: RichTextLabel
var _speaker: Label
var _counter: Label
var _choice: Label
var _hint: Label
var _timer_bar: ColorRect
var _typewriter: Typewriter
var _beeper: RobotBeeper
var _hold_total := 0.0
var _hold_left := 0.0
var _typed := 0
var _fade: Tween

func _ready() -> void:
	name = "RadioPanel"
	add_to_group("radio_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	_typewriter.typing_finished.connect(_on_typing_finished)
	RobotRadio.line_started.connect(_show_line)
	RobotRadio.transmission_ended.connect(_close)
	if RobotRadio.is_active():
		_show_line(RobotRadio.current_line(), RobotRadio.queue.current)

func is_typing() -> bool:
	return _typewriter.is_typing()

func message_text() -> String:
	return _message.get_parsed_text()

func choice_text() -> String:
	return _choice.text if _choice.visible else ""

# --- Layout ------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -SCREEN_MARGIN.x
	offset_bottom = -SCREEN_MARGIN.y
	offset_left = offset_right - PANEL_SIZE.x
	offset_top = offset_bottom - PANEL_SIZE.y

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Colors.SPACE_BG, 0.95)
	box.border_color = Colors.UI_BORDER
	box.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", box)
	add_child(frame)

	# Auto-dismiss countdown along the bottom edge
	_timer_bar = ColorRect.new()
	_timer_bar.color = Colors.PRIMARY_DIM
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.position = Vector2(2, PANEL_SIZE.y - 5)
	_timer_bar.size = Vector2(0, 3)
	add_child(_timer_bar)

	var title := _label(TITLE, SMALL_SIZE, Colors.PRIMARY)
	var title_bg := StyleBoxFlat.new()
	title_bg.bg_color = Colors.UI_BACKGROUND_SOLID
	title_bg.content_margin_left = 6
	title_bg.content_margin_right = 6
	title.add_theme_stylebox_override("normal", title_bg)
	title.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	title.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	title.offset_right = -16
	title.offset_top = -6
	add_child(title)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	robot = RobotView.new()
	robot.font_size = ROBOT_FONT_SIZE
	robot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(robot)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	row.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_speaker = _label("", SMALL_SIZE, Colors.PRIMARY)
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_speaker)
	_counter = _label("", SMALL_SIZE, Colors.PRIMARY_DIM)
	header.add_child(_counter)

	_message = RichTextLabel.new()
	_message.bbcode_enabled = true
	_message.scroll_active = false
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_message.add_theme_color_override("default_color", Colors.TEXT)
	_message.add_theme_constant_override("line_separation", 6)
	column.add_child(_message)

	_choice = _label("", TEXT_SIZE, Colors.PRIMARY)
	column.add_child(_choice)

	_hint = _label("", SMALL_SIZE, Colors.PRIMARY_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint)

	_typewriter = Typewriter.new()
	_typewriter.chars_per_second = CHARS_PER_SECOND
	_typewriter.setup(_message)
	add_child(_typewriter)

	_beeper = RobotBeeper.new()
	add_child(_beeper)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# --- Playback ----------------------------------------------------------------

func _show_line(line: RadioLine, conv: RadioConversation) -> void:
	var opening := _line == null
	_line = line
	_conv = conv
	_speaker.text = "%s >" % line.speaker_name().to_upper()
	var pending := RobotRadio.queue.pending_count()
	_counter.text = "%d/%d" % [RobotRadio.queue.line_index + 1, conv.lines.size()]
	if pending > 0:
		_counter.text += "  +%d" % pending
	robot.expression = line.expression
	robot.talking = true
	robot.glitch_rate = 2.5 if line.glitch else 0.0
	if line.glitch or opening:
		robot.glitch_burst(0.35)  # tuning-in static
	_hold_left = 0.0
	_hold_total = 0.0
	_typed = 0
	_typewriter.type_text(line.display_text(conv.vars))
	_choice.visible = line.is_confirm()
	_choice.text = ">  %s" % line.confirm_text(conv.vars)
	_choice.add_theme_color_override("font_color", Colors.PRIMARY_DIM)
	_beeper.chirp(line.expression)
	_update_hint()
	if opening:
		visible = not _is_blocked()
		_fade_to(1.0)

func _on_typing_finished() -> void:
	robot.talking = false
	robot.glitch_rate = 0.0
	_choice.add_theme_color_override("font_color", Colors.PRIMARY)
	if _line and _waits_for_player():
		_hold_total = 0.0
		_hold_left = 0.0
	elif _line:
		_hold_total = _line.read_time(_conv.vars)
		_hold_left = _hold_total
	_update_hint()

## Paused or confirm lines never time out.
func _waits_for_player() -> bool:
	return _line.is_confirm() or _conv.pause_game

## SPACE doubles as the flight action key, so it only drives conversations that
## hold the game or ask for a confirm (the ship isn't flying then).
func _space_continues() -> bool:
	return _conv.pause_game or _conv.lines.any(func(l: RadioLine) -> bool: return l.is_confirm())

func _close() -> void:
	_line = null
	_conv = null
	_typewriter.show_immediate(_message.text)
	robot.talking = false
	robot.glitch_rate = 0.0
	_fade_to(0.0)

func _fade_to(alpha: float) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	if alpha > 0.0 and modulate.a >= 1.0:
		modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_TIME)
	if alpha <= 0.0:
		_fade.tween_callback(func() -> void:
			if _line == null:
				visible = false)

func _update_hint() -> void:
	var parts: Array[String] = []
	if _conv and _conv.pause_game:
		parts.append("PAUSED")
	if _line and _space_continues():
		var last := RobotRadio.queue.line_index + 1 >= _conv.lines.size() and RobotRadio.queue.pending_count() == 0
		var word := "NEXT"
		if _typewriter.is_typing():
			word = "SKIP"
		elif _line.is_confirm():
			word = "CONFIRM"
		elif last:
			word = "CLOSE"
		parts.append("%s %s" % [InputUtils.get_action_key_name("action").to_upper(), word])
	_hint.text = "   ".join(parts)

func _process(delta: float) -> void:
	if _line == null:
		return
	var blocked := _is_blocked()
	visible = not blocked
	_typewriter.set_process(not blocked)
	if blocked:
		return
	if _typewriter.is_typing():
		_beep_new_chars()
	elif _hold_left > 0.0:
		_hold_left -= delta
		_timer_bar.size.x = (PANEL_SIZE.x - 4.0) * maxf(_hold_left, 0.0) / _hold_total
		if _hold_left <= 0.0:
			RobotRadio.advance()
	if _hold_left <= 0.0:
		_timer_bar.size.x = 0.0

func _beep_new_chars() -> void:
	var shown := _message.visible_characters
	if shown <= _typed:
		return
	var text := _message.get_parsed_text()
	var ch := text[mini(shown, text.length()) - 1]
	_typed = shown
	if ch != " ":
		_beeper.blip(_line.expression, _line.glitch)

func _input(event: InputEvent) -> void:
	if _line == null or not visible:
		return
	var enter: bool = event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
	var space: bool = event.is_action_pressed("action") and _space_continues()
	if not (space or enter or event.is_action_pressed("radio_next")):
		return
	_continue()
	get_viewport().set_input_as_handled()

## One press: finish the speech, or else move on (confirm / next line / close).
func _continue() -> void:
	if _typewriter.is_typing():
		_typewriter.skip()
	elif _line.is_confirm():
		RobotRadio.confirm()
	else:
		RobotRadio.advance()

## A menu (dock, store, map, inventory, pause, game over) is up: step aside.
func _is_blocked() -> bool:
	var hud := get_parent()
	var layer := hud.get_parent() if hud else null
	if layer == null:
		return false
	for c in layer.get_children():
		if c != hud and c is CanvasItem and c.visible and not (c.name in NON_BLOCKING):
			return true
	return false
