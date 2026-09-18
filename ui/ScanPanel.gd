extends Control
class_name ScanPanel

## HUD readout for the Planetary Scanner, top right. While a scan runs it shows the
## unidentified target and a filling meter. When the scan completes the planet's survey
## data types out, holds for a few seconds, then the panel fades.
## Added to the HUD at runtime.

const PANEL_WIDTH := 300.0
const SCREEN_MARGIN := Vector2(16, 20)  # right, top
const TITLE := "/ S C A N /"
const TEXT_SIZE := 11
const SMALL_SIZE := 10
const METER_CELLS := 16
const HOLD_TIME := 7.0
const FADE_TIME := 0.4
const CHARS_PER_SECOND := 50.0
const UNKNOWN := "? ? ?"

var _panel: PanelContainer
var _body: RichTextLabel
var _typewriter: Typewriter
var _scanner: PlanetScanner = null
var _hold := 0.0

func _ready() -> void:
	name = "ScanPanel"
	add_to_group("scan_panel")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	modulate.a = 0.0
	visible = false
	EventBus.planet_scanned.connect(_on_planet_scanned)

## Plain text on the panel (for playtests).
func body_text() -> String:
	return _body.get_parsed_text()

func is_typing() -> bool:
	return _typewriter.is_typing()

func _build() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -SCREEN_MARGIN.x
	offset_left = offset_right - PANEL_WIDTH
	offset_top = SCREEN_MARGIN.y

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size.x = PANEL_WIDTH
	var box := StyleBoxFlat.new()
	box.bg_color = Colors.UI_BACKGROUND
	box.draw_center = true
	box.border_color = Colors.UI_BORDER
	box.set_border_width_all(2)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 14
	box.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Containers grow on their own but never shrink back.
	_body.minimum_size_changed.connect(_panel.reset_size)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_body.add_theme_color_override("default_color", Colors.PRIMARY)
	_panel.add_child(_body)

	var title := Label.new()
	title.text = TITLE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", SMALL_SIZE)
	title.add_theme_color_override("font_color", Colors.PRIMARY)
	var title_bg := StyleBoxFlat.new()
	title_bg.bg_color = Colors.UI_BACKGROUND_SOLID
	title_bg.content_margin_left = 6
	title_bg.content_margin_right = 6
	title.add_theme_stylebox_override("normal", title_bg)
	title.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	title.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	title.offset_right = -16
	title.offset_top = -7
	add_child(title)

	_typewriter = Typewriter.new()
	_typewriter.chars_per_second = CHARS_PER_SECOND
	_typewriter.setup(_body)
	add_child(_typewriter)

func _process(delta: float) -> void:
	var scanner := _get_scanner()
	var scanning := scanner != null and scanner.is_scanning() and _gameplay_active()
	if scanning:
		_hold = 0.0
		_body.visible_characters = -1
		_typewriter.show_immediate(meter_text(scanner.progress()))
	elif _hold > 0.0 and not _typewriter.is_typing():
		_hold -= delta
	var showing := scanning or _hold > 0.0 or _typewriter.is_typing()
	modulate.a = move_toward(modulate.a, 1.0 if showing else 0.0, delta / FADE_TIME)
	visible = modulate.a > 0.0

func _on_planet_scanned(planet: Planet) -> void:
	var lines := PlanetScan.readout_lines(planet)
	_typewriter.type_text("SURVEY COMPLETE\n\n" + "\n".join(lines))
	_hold = HOLD_TIME
	modulate.a = maxf(modulate.a, 0.01)
	visible = true

## "TARGET  ? ? ?" plus a [####----]  NN% meter.
static func meter_text(progress: float) -> String:
	var filled := clampi(int(progress * METER_CELLS), 0, METER_CELLS)
	return "SCANNING...\n\n%s%s\n[%s%s] %3d%%" % [
		"TARGET".rpad(13), UNKNOWN,
		"#".repeat(filled), "-".repeat(METER_CELLS - filled),
		int(progress * 100.0),
	]

func _get_scanner() -> PlanetScanner:
	if not is_instance_valid(_scanner):
		var ship := get_tree().get_first_node_in_group("ship")
		_scanner = ship.get_node_or_null("PlanetScanner") as PlanetScanner if ship else null
	return _scanner

func _gameplay_active() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	return main == null or main.current_game_state == main.MainGameState.PLAYING
