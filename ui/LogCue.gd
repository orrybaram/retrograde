extends Control
class_name LogCue

## The only thing on screen that says the ship's log (ShipLog) has a new line: one line in
## the bottom-right corner, `> LOG UPDATED  [I]`, typed in, held, then faded. Silent lines
## (a new game's first ones, the diagnostic's PASS) never raise it. Lines written while it
## can't be seen (the Log or a menu up) wait, and it types once it can. Opening the Log cancels it: the player is reading.

const TEXT_SIZE := BootLog.TEXT_SIZE
const OUTLINE := BootLog.OUTLINE
const TEXT := "> LOG UPDATED"
const TYPE_RATE := BootChecklist.TYPE_RATE
const HOLD := 2.5
const FADE_TIME := 0.8
## Where it sits: the radio panel's corner, a gap above that panel while it is up.
const SCREEN_MARGIN := RadioPanel.SCREEN_MARGIN
const GAP := 10.0

var radio: Control = null
var _label: RichTextLabel
var _pending := false
var _age := -1.0  # seconds into the cue showing now; < 0 when none is


func _ready() -> void:
	name = "LogCue"
	add_to_group("log_cue")
	# Main.clear_screen_effects: a new game, a load or a quit to the menu clears it
	add_to_group("screen_effects")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_label.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	_label.add_theme_constant_override("outline_size", OUTLINE)
	add_child(_label)
	EventBus.ship_log_written.connect(func(_entry: Dictionary, cue: bool) -> void:
		if cue:
			_pending = true)
	visible = false


## Gone, and nothing waiting: a load starts with its log already read.
func clear_now() -> void:
	_pending = false
	_age = -1.0
	visible = false


## Whether it is on screen now, or waiting to be (for scenarios).
func is_showing() -> bool:
	return _age >= 0.0


func is_pending() -> bool:
	return _pending


func text() -> String:
	return _label.get_parsed_text() if visible else ""


## The whole line, `[I]` named for the device in hand.
static func full_text() -> String:
	return "%s  [%s]" % [TEXT, Controls.label(&"open_log")]


func _process(dt: float) -> void:
	var log_ui := get_tree().get_first_node_in_group("log_ui") as Control
	if log_ui and log_ui.visible:
		clear_now()  # reading it now
		return
	if not _can_show():
		visible = false
		return
	if _pending:
		_pending = false
		_age = 0.0
	if _age < 0.0:
		visible = false
		return
	_age += dt
	var line := full_text()
	var typed_for := line.length() / TYPE_RATE
	var gone_at := typed_for + HOLD + FADE_TIME
	if _age >= gone_at:
		_age = -1.0
		visible = false
		return
	visible = true
	modulate.a = clampf((gone_at - _age) / FADE_TIME, 0.0, 1.0)
	var shown := mini(int(_age * TYPE_RATE), line.length())
	var head := line.left(mini(shown, TEXT.length()))
	var tail := line.substr(TEXT.length(), maxi(shown - TEXT.length(), 0))
	_label.text = "[color=#%s]%s[/color][color=#%s]%s[/color]" % [
		Colors.hex(Colors.PRIMARY), head, Colors.hex(Colors.PRIMARY_DIM), tail.replace("[", "[lb]")]
	_place()


func _can_show() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	if main and main.current_game_state != main.MainGameState.PLAYING:
		return false
	if get_tree().paused:
		return false
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	return ship != null and not ship.is_destroyed()


## Bottom right: its bottom edge on the corner's margin, or a gap above UNIT-7's panel.
func _place() -> void:
	var box := _label.get_combined_minimum_size()
	var bottom := get_parent_area_size().y - SCREEN_MARGIN.y
	if radio and radio.visible:
		bottom = radio.position.y - GAP
	_label.size = box
	size = box
	position = Vector2(get_parent_area_size().x - SCREEN_MARGIN.x - box.x, bottom - box.y)
