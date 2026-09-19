class_name TerminalWindow
extends Control

## Full-screen overlay with a centered, bordered terminal window: dimmed backdrop,
## a spaced title notched into the top border and a key hint in the bottom border.
## Put content in `body`. Shared by the Log and store screens.

const HEADER_SIZE := 12
const TEXT_SIZE := 10
const SMALL_SIZE := 8
const FADE_TIME := 0.15
const SLIDE_PX := 12.0
## The frame's line weight. The tab strip is built around it, so it is shared.
const BORDER_WIDTH := 2

# --- Tab strip ---------------------------------------------------------------
## A tab is a control, not a header, so it carries a plain word rather than the spaced
## letters of a title (.claude/PATTERNS.md). Selection is carried by the notch itself -
## the lit one opens into the window - so the label needs no prefix marker.
const TAB_SELECTED_PREFIX := ""
const TAB_UNSELECTED_PREFIX := ""
const TAB_HEIGHT := 18
const TAB_INSET := 20.0
const TAB_GAP := 6
const TAB_PADDING := 10

var body: MarginContainer
var window_size: Vector2

var _window: Control
var _title: Label
var _hint: Label
var _fade: Tween
var _tab_labels: Array[Label] = []
var _tab_titles: Array[String] = []


func _init(size_px: Vector2, title: String, hint: String) -> void:
	window_size = size_px
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dim := ColorRect.new()
	dim.color = Color(Colors.SPACE_BG, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_window = Control.new()
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(0.0)
	add_child(_window)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", box(Color(Colors.SPACE_BG, 0.96), Colors.UI_BORDER, BORDER_WIDTH))
	_window.add_child(frame)

	_title = _tab(title, TEXT_SIZE, Colors.PRIMARY, false)
	_window.add_child(_title)
	_hint = _tab(hint, SMALL_SIZE, Colors.PRIMARY_DIM, true)
	_window.add_child(_hint)

	body = MarginContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 24)
	_window.add_child(body)


## Tab notches broken into the top border's left corner, laid out left to right. Each
## one sits astride the frame line: an unselected tab closes itself off with a bottom
## edge, so the line reads as running straight through it, while the selected tab leaves
## that edge open into the window. Call `select_tab()` to light one — the notch styling
## belongs to the window, not to the caller.
func add_tabs(titles: Array[String]) -> void:
	_tab_titles = titles.duplicate()
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.offset_left = TAB_INSET
	row.offset_right = window_size.x
	# A tab's bottom edge lands on the inner edge of the frame's border, so a closed
	# tab's own bottom border falls exactly over the line it is sitting on.
	row.offset_top = -(TAB_HEIGHT - BORDER_WIDTH)
	row.offset_bottom = BORDER_WIDTH
	row.add_theme_constant_override("separation", TAB_GAP)
	for title in titles:
		var tab := label("", TEXT_SIZE, Colors.PRIMARY_DIM)
		tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size.y = TAB_HEIGHT
		row.add_child(tab)
		_tab_labels.append(tab)
	_window.add_child(row)
	select_tab(0)

## Light `index`'s tab and close the rest: the selected one is the bright one and its
## notch opens into the window.
func select_tab(index: int) -> void:
	for i in _tab_labels.size():
		var lit := i == index
		var tab := _tab_labels[i]
		tab.text = (TAB_SELECTED_PREFIX if lit else TAB_UNSELECTED_PREFIX) + _tab_titles[i]
		tab.add_theme_color_override("font_color", Colors.PRIMARY if lit else Colors.PRIMARY_DIM)
		tab.add_theme_stylebox_override("normal", _tab_box(lit))

## The notch a tab sits in. Both break the frame line with a solid fill; the lit one
## leaves its bottom open into the window, the unlit one closes itself off.
static func _tab_box(lit: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = Colors.UI_BACKGROUND_SOLID
	b.border_color = Colors.UI_BORDER
	b.border_width_left = BORDER_WIDTH
	b.border_width_top = BORDER_WIDTH
	b.border_width_right = BORDER_WIDTH
	b.border_width_bottom = 0 if lit else BORDER_WIDTH
	b.content_margin_left = TAB_PADDING
	b.content_margin_right = TAB_PADDING
	return b

func set_title(text: String) -> void:
	_title.text = text


func set_hint(text: String) -> void:
	_hint.text = text


## Fade in with a short upward slide.
func animate_in() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	modulate.a = 0.0
	_place(SLIDE_PX)
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_fade.tween_method(_place, SLIDE_PX, 0.0, FADE_TIME * 1.5)


func _place(slide: float) -> void:
	_window.offset_left = -window_size.x / 2.0
	_window.offset_right = window_size.x / 2.0
	_window.offset_top = -window_size.y / 2.0 + slide
	_window.offset_bottom = window_size.y / 2.0 + slide


## A notch anchored into the window's right border, top or bottom.
func _tab(text: String, font_size: int, color: Color, bottom: bool) -> Label:
	var tab := _notch(text, font_size, color)
	tab.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if bottom else Control.PRESET_TOP_RIGHT)
	tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tab.offset_right = -20.0
	if bottom:
		tab.grow_vertical = Control.GROW_DIRECTION_BEGIN
		tab.offset_bottom = 6.0
	else:
		tab.offset_top = -7.0
	return tab


## A label on solid background, so it breaks the border line it sits on.
static func _notch(text: String, font_size: int, color: Color) -> Label:
	var tab := label(text, font_size, color)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Colors.UI_BACKGROUND_SOLID
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	tab.add_theme_stylebox_override("normal", bg)
	return tab


# --- Shared building blocks --------------------------------------------------

## "STORE NAME" -> "/ S T O R E   N A M E /"
static func spaced_title(text: String) -> String:
	return "/ %s /" % spaced(text)


static func spaced(text: String) -> String:
	return " ".join(text.to_upper().split(""))


static func box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(width)
	return b


static func label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func header(text: String) -> Label:
	return label(text, HEADER_SIZE, Colors.PRIMARY)


static func rule(vertical: bool = false) -> Control:
	var line := ColorRect.new()
	line.color = Colors.PRIMARY_DIM
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	return line


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func filler() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
