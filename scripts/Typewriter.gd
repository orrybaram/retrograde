extends Node
class_name Typewriter

## Reusable typewriter effect that types text into a RichTextLabel one character at a time.
## Add as a child node, assign a target label, then call type_text().

signal typing_finished

@export var chars_per_second: float = 60.0

var _target: RichTextLabel = null
var _full_text: String = ""
var _visible_chars: int = 0
var _is_typing: bool = false
var _timer: float = 0.0

func setup(target: RichTextLabel) -> void:
	_target = target

func type_text(text: String) -> void:
	if not _target:
		return

	_full_text = text
	_target.text = text
	_target.visible_characters = 0
	_visible_chars = 0
	_timer = 0.0
	_is_typing = true

func append_text(text: String) -> void:
	if not _target:
		return

	_full_text += text
	_target.text = _full_text
	# Keep already-visible chars, start typing the new portion
	_visible_chars = _target.get_total_character_count() - _count_visible_chars(text)
	_timer = 0.0
	_is_typing = true

func skip() -> void:
	if not _is_typing:
		return
	_is_typing = false
	if _target:
		_target.visible_characters = -1
	typing_finished.emit()

func is_typing() -> bool:
	return _is_typing

func show_immediate(text: String) -> void:
	if not _target:
		return
	_full_text = text
	_target.text = text
	_target.visible_characters = -1
	_is_typing = false

func _process(delta: float) -> void:
	if not _is_typing or not _target:
		return

	_timer += delta
	var interval = 1.0 / chars_per_second
	while _timer >= interval and _is_typing:
		_timer -= interval
		_visible_chars += 1
		_target.visible_characters = _visible_chars

		if _visible_chars >= _target.get_total_character_count():
			_is_typing = false
			_target.visible_characters = -1
			typing_finished.emit()
			break

func _count_visible_chars(text: String) -> int:
	## Count non-BBCode characters in a string.
	var stripped = _strip_bbcode(text)
	return stripped.length()

func _strip_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)
