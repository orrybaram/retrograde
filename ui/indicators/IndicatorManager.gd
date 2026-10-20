extends Control
class_name IndicatorManager

## The current action prompt (EventBus.action_message_changed), just below the ship. Which
## piece of scrap a harvest press will cut is marked by its lock (ReadoutLock), not here.
## With a full hold the harvest prompt gives way to HOLD FULL: gems knocked loose would only
## wait in space.

const PROMPT_FONT_SIZE := 8
const PROMPT_SHIP_OFFSET := 26.0  # below the ship's center, in screen px
const PROMPT_ALPHA := 0.7
const PROMPT_OUTLINE := 4  # dark halo so the hint reads over the landing bay stripes
const HOLD_FULL := "HOLD FULL"

var ship: Ship = null
var camera: Camera2D = null

var _prompt: Label
var _prompt_text := ""

func _ready() -> void:
	add_to_group("indicator_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS  # the prompt keeps its place while paused
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prompt = Label.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_font_size_override("font_size", PROMPT_FONT_SIZE)
	_prompt.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	_prompt.add_theme_constant_override("outline_size", PROMPT_OUTLINE)
	# Prompts are the word over its key: centre each line so the key sits under the word
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)
	EventBus.action_message_changed.connect(_on_action_message_changed)
	if EventBus.is_harvest_available():
		_on_action_message_changed(EventBus.harvest_prompt())

func _on_action_message_changed(message: String) -> void:
	_prompt_text = message

func _process(_delta: float) -> void:
	if not ship:
		ship = get_tree().get_first_node_in_group("ship") as Ship
	if not camera and ship:
		camera = ship.get_node_or_null("Camera2D") as Camera2D
	_place_prompt()

## What the prompt says right now: the action, or HOLD FULL in place of a harvest prompt.
func prompt_text() -> String:
	if _prompt_text == EventBus.harvest_prompt() and is_instance_valid(ship) and ship.is_cargo_full():
		return HOLD_FULL
	return _prompt_text

func _place_prompt() -> void:
	var text := prompt_text()
	var shown := text != "" and camera != null and is_instance_valid(ship) and not get_tree().paused
	_prompt.visible = shown
	if not shown:
		return
	if _prompt.text != text:
		_prompt.text = text
		_prompt.reset_size()
	_prompt.add_theme_color_override("font_color", Colors.DANGER if text == HOLD_FULL else Colors.PRIMARY)
	# Soft breathing so it reads as a hint, not a banner
	_prompt.modulate.a = PROMPT_ALPHA * (0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.6))
	var viewport_size := get_viewport_rect().size
	var ship_screen := (ship.global_position - camera.global_position) * camera.zoom + viewport_size / 2.0
	var pos := ship_screen + Vector2(-_prompt.size.x / 2.0, PROMPT_SHIP_OFFSET)
	_prompt.position = pos.clamp(Vector2.ZERO, (viewport_size - _prompt.size).max(Vector2.ZERO)).round()
