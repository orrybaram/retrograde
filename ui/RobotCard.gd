class_name RobotCard
extends VBoxContainer

## Left-hand card for UNIT-7, the Automaton stationed at SR-7: its portrait, name, a
## status tag, a typed-out line of dialogue and the credits balance. It belongs to the
## store screen, where the player is docked at SR-7 and talking to it in person -
## UNIT-7 is not crew and is never carried around in a menu.

const WIDTH := 244.0
const ROBOT_FONT_SIZE := 16
const CHARS_PER_SECOND := 45.0

var robot: RobotView

var _status: Label
var _line: RichTextLabel
var _typewriter: Typewriter
var _credits: Label


func _init(heading: String, role: String) -> void:
	custom_minimum_size.x = WIDTH
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(TerminalWindow.header(heading))

	var portrait := PanelContainer.new()
	var inset := TerminalWindow.box(Color(Colors.NEBULA, 0.3), Colors.PRIMARY_GHOST, 1)
	inset.set_content_margin_all(16)
	portrait.add_theme_stylebox_override("panel", inset)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	robot = RobotView.new()
	robot.font_size = ROBOT_FONT_SIZE
	robot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.add_child(robot)
	add_child(portrait)

	var id_row := HBoxContainer.new()
	id_row.add_child(TerminalWindow.label(RobotRadio.SPEAKER_NAME, TerminalWindow.TEXT_SIZE, Colors.PRIMARY))
	id_row.add_child(TerminalWindow.spacer())
	_status = TerminalWindow.label("", TerminalWindow.SMALL_SIZE, Colors.SUCCESS)
	id_row.add_child(_status)
	add_child(id_row)
	add_child(TerminalWindow.label(role, TerminalWindow.SMALL_SIZE, Colors.PRIMARY_DIM))

	_line = RichTextLabel.new()
	_line.bbcode_enabled = true
	_line.scroll_active = false
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_line.add_theme_font_size_override("normal_font_size", TerminalWindow.TEXT_SIZE)
	_line.add_theme_color_override("default_color", Colors.TEXT)
	_line.add_theme_constant_override("line_separation", 6)
	add_child(_line)

	_typewriter = Typewriter.new()
	_typewriter.chars_per_second = CHARS_PER_SECOND
	_typewriter.setup(_line)
	_typewriter.typing_finished.connect(func() -> void: robot.talking = false)
	add_child(_typewriter)

	add_child(TerminalWindow.rule())
	var wallet := HBoxContainer.new()
	wallet.add_child(TerminalWindow.label("CREDITS", TerminalWindow.TEXT_SIZE, Colors.PRIMARY_DIM))
	wallet.add_child(TerminalWindow.spacer())
	_credits = TerminalWindow.label("", TerminalWindow.HEADER_SIZE, Colors.PRIMARY)
	wallet.add_child(_credits)
	add_child(wallet)


## Type out `text` with the robot's mouth moving. Skips if it's already saying it.
func say(text: String, expression: StringName = &"") -> void:
	if expression != &"":
		robot.expression = expression
	if text == _line.text and (_typewriter.is_typing() or _line.visible_characters == -1):
		return
	if text.is_empty():
		_typewriter.show_immediate("")
		robot.talking = false
		return
	robot.talking = true
	_typewriter.type_text(text)


func hush() -> void:
	_typewriter.skip()
	robot.talking = false


func set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func set_credits(amount: int) -> void:
	_credits.text = "%d CR" % amount


func said() -> String:
	return _line.get_parsed_text()
