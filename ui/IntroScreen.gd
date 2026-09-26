extends Control
class_name IntroScreen

## The first thing a new game shows, before the boot terminal: three lines typed out on a
## screen so close the scanlines show, with a block cursor blinking after them. It holds
## on the finished text until the player presses ENTER.
##
## Where you are, that something has just happened, and that everything is failing - in
## the flat voice of a record nobody signs. It never says what happened
## (docs/OPENING.md §2, "Why it is broken"), and it never mentions the player.

const LINES: Array[String] = [
	"KSD-78 SYSTEM, OUTER REGION.",
	"0 CYCLES SINCE EVENT.",
	"ALL FUNCTIONS CRITICAL.",
]

## Close up, but never so close a sentence wraps: _fit() sizes the text so the longest
## line (and its cursor) just fills the width between the margins.
const MAX_TEXT_SIZE := 28
const SEPARATOR := "\n"
const CURSOR := "█"
const CURSOR_HZ := 1.6
const MARGIN := 0.08  # side inset, as a fraction of the screen width

## The beat: the cursor blinks on its own before each line is typed. After a line it
## rests where it stopped, then drops to the next line and waits there again.
const LEAD_IN := 1.6
const LINE_END_PAUSE := 0.5
const LINE_BEAT := 1.2
const CHARS_PER_SEC := 26.0
## Once the text is up, the way on shows, dim, after a moment.
const PROMPT := "PRESS ENTER"
const PROMPT_DELAY := 1.0
const PROMPT_FADE := 0.6
## Punctuation holds the typing for a moment, like whoever is typing thought about it.
const COMMA_PAUSE := 0.18
## ENTER that started the game mustn't also skip the typing.
const SKIP_GUARD := 0.35

## Close-up scanlines: every row is a fat band of dark, the way a CRT looks up close.
const SCANLINE_STEP := 4
const SCANLINE_ALPHA := 0.35
## The whole picture creeps closer while it plays, so it never sits dead still.
const PUSH_IN := 0.035

signal finished

var _text: RichTextLabel = null
var _prompt: Label = null
var _scanlines: Control = null
var _body: Control = null
var _elapsed := 0.0
var _playing := false
var _done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the game is paused at the menu
	_build()
	resized.connect(_fit)
	visible = false

## Types the lines out and returns once the player presses ENTER on them.
func play() -> void:
	_elapsed = 0.0
	_done = false
	_playing = true
	visible = true
	_fit()
	_render()
	await finished
	_playing = false
	visible = false

## When each line shows up (the cursor dropping onto it) and when its typing starts.
static func _schedule() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var appear := 0.0
	for i in LINES.size():
		var start := appear + (LEAD_IN if i == 0 else LINE_BEAT)
		out.append(Vector2(appear, start))
		appear = start + _type_time(LINES[i]) + LINE_END_PAUSE
	return out

## When the last character is down, with nothing skipped.
static func typed_by() -> float:
	var last := _schedule()[-1]
	return last.y + _type_time(LINES[-1])

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_render()
	_scanlines.queue_redraw()
	if _done:
		_playing = false
		finished.emit()

## ENTER while it types finishes the text at once; ENTER on the finished text moves on.
func _input(event: InputEvent) -> void:
	if not _playing or _elapsed < SKIP_GUARD:
		return
	if not (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if _elapsed < typed_by():
		_elapsed = typed_by()
	else:
		_done = true

# --- Layout ------------------------------------------------------------------

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var backdrop := ColorRect.new()
	backdrop.color = Colors.SPACE_BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# Everything that zooms lives in here, so the push-in scales text and glass together.
	_body = Control.new()
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_color_override("default_color", Colors.PRIMARY)
	# Phosphor bleed: a soft halo of the same mustard around every glyph.
	_text.add_theme_color_override("font_shadow_color", Color(Colors.PRIMARY, 0.28))
	_text.add_theme_constant_override("shadow_offset_x", 0)
	_text.add_theme_constant_override("shadow_offset_y", 0)
	_text.anchor_left = MARGIN
	_text.anchor_right = 1.0 - MARGIN
	_text.anchor_top = 0.5
	_text.anchor_bottom = 0.5
	_text.grow_vertical = Control.GROW_DIRECTION_BOTH
	_body.add_child(_text)

	_prompt = TerminalWindow.label(PROMPT, 12, Colors.PRIMARY_DIM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.82
	_prompt.anchor_bottom = 0.82
	_body.add_child(_prompt)

	var vignette := TextureRect.new()
	vignette.texture = _vignette_texture()
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(vignette)

	_scanlines = Control.new()
	_scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scanlines.draw.connect(_draw_glass)
	_body.add_child(_scanlines)

## The largest size, up to MAX_TEXT_SIZE, at which the longest line fits on one line.
func _fit() -> void:
	var font := _text.get_theme_font("normal_font")
	if font == null or size.x <= 0.0:
		return
	var longest := ""
	for line in LINES:
		if line.length() > longest.length():
			longest = line
	var wide := font.get_string_size(
		longest + CURSOR, HORIZONTAL_ALIGNMENT_LEFT, -1, MAX_TEXT_SIZE).x
	var room := size.x * (1.0 - MARGIN * 2.0)
	var font_size := int(MAX_TEXT_SIZE * minf(1.0, room / wide))
	_text.add_theme_font_size_override("normal_font_size", font_size)
	_text.add_theme_constant_override("line_separation", int(font_size * 0.6))
	_text.add_theme_constant_override("shadow_outline_size", int(font_size * 0.35))

## Dark at the rim, clear in the middle: the curve of the tube, seen from an inch away.
static func _vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Colors.SPACE_BG, 0.0))
	gradient.set_color(1, Color(Colors.SPACE_BG, 0.85))
	gradient.set_offset(0, 0.45)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	return tex

# --- Typing ------------------------------------------------------------------

## How long a line takes to type, pauses included.
static func _type_time(line: String) -> float:
	return line.length() / CHARS_PER_SEC + _pauses_in(line, line.length())

## Punctuation pauses among the first `count` characters of `line`.
static func _pauses_in(line: String, count: int) -> float:
	var t := 0.0
	for i in mini(count, line.length()):
		if line[i] in [",", ".", ";", ":"] and i < line.length() - 1:
			t += COMMA_PAUSE
	return t

## How many characters of `line` are on screen `t` seconds after it started typing.
static func _typed(line: String, t: float) -> int:
	var shown := 0
	var clock := 0.0
	while shown < line.length():
		clock += 1.0 / CHARS_PER_SEC
		if clock > t:
			break
		shown += 1
		if line[shown - 1] in [",", ".", ";", ":"] and shown < line.length():
			clock += COMMA_PAUSE
	return shown

## The text as it stands `elapsed` seconds in: finished lines, the one being typed or
## waited on (empty until its typing starts), and nothing after. Plain text, so tests
## can read it.
static func text_at(elapsed: float) -> String:
	var out := PackedStringArray()
	var schedule := _schedule()
	for i in LINES.size():
		if elapsed < schedule[i].x:
			break
		var line: String = LINES[i]
		out.append(line.substr(0, _typed(line, elapsed - schedule[i].y)))
	return SEPARATOR.join(out)

func _render() -> void:
	var shown := text_at(_elapsed)
	var rest := SEPARATOR.join(LINES).substr(shown.length())
	# The cursor is solid while it types and blinks while it waits, like a real one.
	var lit := _is_typing(_elapsed) or fmod(_elapsed * CURSOR_HZ, 1.0) < 0.55
	# The whole text is always laid out and only the typed part drawn, so the block never
	# recentres as it grows.
	# The cursor stands on the next cell; at a line's end it gets a cell of its own.
	if rest != "" and not rest.begins_with("\n"):
		rest = rest.substr(1)
	_text.text = (shown + CURSOR + rest).replace("[", "[lb]")
	_text.visible_characters = shown.length() + (1 if lit else 0)

	var since := _elapsed - typed_by() - PROMPT_DELAY
	_prompt.modulate.a = clampf(since / PROMPT_FADE, 0.0, 1.0)

	var zoom := 1.0 + PUSH_IN * clampf(_elapsed / typed_by(), 0.0, 1.0)
	_body.pivot_offset = size / 2.0
	_body.scale = Vector2(zoom, zoom)

static func _is_typing(elapsed: float) -> bool:
	var schedule := _schedule()
	for i in LINES.size():
		var t := elapsed - schedule[i].y
		if t >= 0.0 and t < _type_time(LINES[i]):
			return true
	return false

# --- Glass -------------------------------------------------------------------

## Thick scanlines, fat enough to count: the tube up close.
func _draw_glass() -> void:
	var view := _scanlines.size
	var dark := Color(Colors.SPACE_BG, SCANLINE_ALPHA)
	for y in range(0, int(view.y), SCANLINE_STEP):
		_scanlines.draw_rect(Rect2(0, y, view.x, SCANLINE_STEP / 2.0), dark)
	# A faint band rolling down, as on the boot screen.
	var band_height := 140.0
	var roll := fmod(_elapsed * 90.0, view.y + band_height) - band_height
	_scanlines.draw_rect(Rect2(0, roll, view.x, band_height), Color(Colors.PRIMARY, 0.018))
