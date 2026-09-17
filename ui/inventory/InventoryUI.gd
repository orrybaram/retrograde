extends Control
class_name InventoryUI

## Inventory screen: UNIT-7 on the left with a status readout, ship gauges, the hold
## and upgrade tiers on the right. Opens/closes with "I" (ESC also closes; see Main).
## Built in code like RadioPanel; the .tscn is just the root.

signal dialogue_closed

const WINDOW_SIZE := Vector2(880, 440)
const CARD_WIDTH := 244.0
const TITLE := "/ I N V E N T O R Y /"
const ROBOT_FONT_SIZE := 16
const HEADER_SIZE := 12
const TEXT_SIZE := 10
const SMALL_SIZE := 8
const STAT_LABEL_WIDTH := 64.0
const STAT_VALUE_WIDTH := 96.0
const FADE_TIME := 0.15
const SLIDE_PX := 12.0
const QUIP_CHARS_PER_SECOND := 45.0
const MAX_TIER := 3
## Known upgrade tracks in display order. Paths bought but not listed here still show.
const UPGRADE_TRACKS := [
	["hull", "HULL PLATING"],
	["fuel_tank", "FUEL TANK"],
	["cargo", "CARGO HOLD"],
]

var ship: Ship = null
var gs: GameState = null
var inventory_manager: InventoryManager = null
var robot: RobotView

var _window: Control
var _status: Label
var _quip: RichTextLabel
var _typewriter: Typewriter
var _credits: Label
var _hull_gauge: Gauge
var _hull_value: Label
var _fuel_gauge: Gauge
var _fuel_value: Label
var _hold_gauge: Gauge
var _hold_value: Label
var _flight_stats: Label
var _cargo_rows: VBoxContainer
var _hold_total: Label
var _upgrade_rows: VBoxContainer
var _fade: Tween


func _ready() -> void:
	visible = false
	add_to_group("inventory_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	ship = get_tree().get_first_node_in_group("ship") as Ship
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	inventory_manager = get_node_or_null("/root/InventoryManager") as InventoryManager

	# Live updates while open
	if gs:
		gs.credits_changed.connect(_update_display)
		gs.upgrade_level_changed.connect(_update_display)
	if ship and ship.has_signal("fuel_changed"):
		ship.fuel_changed.connect(_update_display)
	if inventory_manager:
		inventory_manager.inventory_changed.connect(_update_display)


func open_inventory() -> void:
	# The ship respawns on death, so re-resolve it each time.
	var current := get_tree().get_first_node_in_group("ship") as Ship
	if current and current != ship:
		ship = current
		if ship.has_signal("fuel_changed") and not ship.fuel_changed.is_connected(_update_display):
			ship.fuel_changed.connect(_update_display)
	visible = true
	_update_display()
	_greet()
	_animate_in()


func close_inventory() -> void:
	visible = false
	_typewriter.skip()
	robot.talking = false
	dialogue_closed.emit()


func _process(_delta: float) -> void:
	if visible and not _typewriter.is_typing():
		robot.talking = false


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Colors.SPACE_BG, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_window = Control.new()
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.offset_left = -WINDOW_SIZE.x / 2.0
	_window.offset_right = WINDOW_SIZE.x / 2.0
	_window.offset_top = -WINDOW_SIZE.y / 2.0
	_window.offset_bottom = WINDOW_SIZE.y / 2.0
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _box(Color(Colors.SPACE_BG, 0.96), Colors.UI_BORDER, 2))
	_window.add_child(frame)

	_window.add_child(_tab(TITLE, Control.PRESET_TOP_RIGHT, -20.0, -7.0))
	_window.add_child(_tab("[I] / [ESC]  CLOSE", Control.PRESET_BOTTOM_RIGHT, -20.0, -6.0, Colors.PRIMARY_DIM))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_window.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	row.add_child(_build_card())
	row.add_child(_rule(true))
	row.add_child(_build_readout())


## Left column: the robot and what it thinks of the situation.
func _build_card() -> Control:
	var card := VBoxContainer.new()
	card.custom_minimum_size.x = CARD_WIDTH
	card.add_theme_constant_override("separation", 10)

	card.add_child(_header("C R E W"))

	var portrait := PanelContainer.new()
	var inset := _box(Color(Colors.NEBULA, 0.3), Colors.PRIMARY_GHOST, 1)
	inset.set_content_margin_all(16)
	portrait.add_theme_stylebox_override("panel", inset)
	robot = RobotView.new()
	robot.font_size = ROBOT_FONT_SIZE
	robot.antenna = RobotView.Antenna.NONE
	robot.faceplate = RobotView.Faceplate.SPEAKER
	robot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.add_child(robot)
	card.add_child(portrait)

	var id_row := HBoxContainer.new()
	id_row.add_child(_label(RobotRadio.SPEAKER_NAME, TEXT_SIZE, Colors.PRIMARY))
	id_row.add_child(_spacer())
	_status = _label("", SMALL_SIZE, Colors.SUCCESS)
	id_row.add_child(_status)
	card.add_child(id_row)
	card.add_child(_label("SALVAGE ASSIST UNIT", SMALL_SIZE, Colors.PRIMARY_DIM))

	_quip = RichTextLabel.new()
	_quip.bbcode_enabled = true
	_quip.fit_content = true
	_quip.scroll_active = false
	_quip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quip.custom_minimum_size.y = 64
	_quip.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_quip.add_theme_color_override("default_color", Colors.TEXT)
	_quip.add_theme_constant_override("line_separation", 6)
	card.add_child(_quip)

	_typewriter = Typewriter.new()
	_typewriter.chars_per_second = QUIP_CHARS_PER_SECOND
	_typewriter.setup(_quip)
	add_child(_typewriter)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(fill)

	card.add_child(_rule(false))
	var wallet := HBoxContainer.new()
	wallet.add_child(_label("CREDITS", TEXT_SIZE, Colors.PRIMARY_DIM))
	wallet.add_child(_spacer())
	_credits = _label("", HEADER_SIZE, Colors.PRIMARY)
	wallet.add_child(_credits)
	card.add_child(wallet)
	return card


## Right column: gauges, the hold, upgrades.
func _build_readout() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)

	col.add_child(_header("S Y S T E M S"))
	var hull := _gauge_row("HULL")
	_hull_gauge = hull[0]
	_hull_value = hull[1]
	col.add_child(hull[2])
	var fuel := _gauge_row("FUEL")
	_fuel_gauge = fuel[0]
	_fuel_value = fuel[1]
	col.add_child(fuel[2])
	var hold := _gauge_row("HOLD")
	_hold_gauge = hold[0]
	_hold_value = hold[1]
	col.add_child(hold[2])
	_flight_stats = _label("", SMALL_SIZE, Colors.PRIMARY_DIM)
	col.add_child(_flight_stats)

	col.add_child(_gap(6))
	col.add_child(_header("C A R G O"))
	_cargo_rows = VBoxContainer.new()
	_cargo_rows.add_theme_constant_override("separation", 6)
	col.add_child(_cargo_rows)
	var total := HBoxContainer.new()
	total.add_child(_label("HOLD VALUE", TEXT_SIZE, Colors.PRIMARY_DIM))
	total.add_child(_spacer())
	_hold_total = _label("", TEXT_SIZE, Colors.PRIMARY)
	total.add_child(_hold_total)
	col.add_child(_rule(false))
	col.add_child(total)

	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	col.add_child(_header("U P G R A D E S"))
	_upgrade_rows = VBoxContainer.new()
	_upgrade_rows.add_theme_constant_override("separation", 6)
	col.add_child(_upgrade_rows)
	return col


## [gauge, value label, row]
func _gauge_row(title: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := _label(title, TEXT_SIZE, Colors.PRIMARY)
	name_label.custom_minimum_size.x = STAT_LABEL_WIDTH
	row.add_child(name_label)
	var gauge := Gauge.new()
	gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gauge)
	var value := _label("", TEXT_SIZE, Colors.TEXT)
	value.custom_minimum_size.x = STAT_VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return [gauge, value, row]


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	return box


## A label notched into the window border.
func _tab(text: String, preset: int, x: float, y: float, color: Color = Colors.PRIMARY) -> Label:
	var tab := _label(text, TEXT_SIZE if color == Colors.PRIMARY else SMALL_SIZE, color)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Colors.UI_BACKGROUND_SOLID
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	tab.add_theme_stylebox_override("normal", bg)
	tab.set_anchors_preset(preset)
	tab.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tab.offset_right = x
	if preset == Control.PRESET_BOTTOM_RIGHT:
		tab.grow_vertical = Control.GROW_DIRECTION_BEGIN
		tab.offset_bottom = -y
	else:
		tab.offset_top = y
	return tab


func _header(text: String) -> Label:
	return _label(text, HEADER_SIZE, Colors.PRIMARY)


func _rule(vertical: bool) -> Control:
	var line := ColorRect.new()
	line.color = Colors.PRIMARY_DIM
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1)
	return line


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _animate_in() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	modulate.a = 0.0
	var rest_y := -WINDOW_SIZE.y / 2.0
	_window.offset_top = rest_y + SLIDE_PX
	_window.offset_bottom = _window.offset_top + WINDOW_SIZE.y
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_fade.tween_property(_window, "offset_top", rest_y, FADE_TIME * 1.5)
	_fade.tween_property(_window, "offset_bottom", rest_y + WINDOW_SIZE.y, FADE_TIME * 1.5)
	robot.glitch_burst(0.3)


# --- Content -----------------------------------------------------------------

func _update_display(_a: Variant = null, _b: Variant = null) -> void:
	# Signal args vary; ignore them.
	if not visible or not is_instance_valid(ship) or not gs:
		return
	_update_systems()
	_update_cargo()
	_update_upgrades()
	_credits.text = "%d CR" % gs.credits


func _update_systems() -> void:
	var hull_ratio := ship.hull_strength / ship.max_hull if ship.max_hull > 0 else 0.0
	_hull_gauge.set_fill(hull_ratio, _hull_color(hull_ratio), int(ceil(ship.max_hull / 10.0)))
	_hull_value.text = "%d / %d" % [ceili(ship.hull_strength), int(ship.max_hull)]

	var fuel_ratio := ship.fuel / ship.max_fuel if ship.max_fuel > 0 else 0.0
	var fuel_level := LowFuelEffect.level_for(ship.fuel, ship.max_fuel)
	_fuel_gauge.set_fill(fuel_ratio, _fuel_color(fuel_ratio), 20, fuel_level != LowFuelEffect.Level.OK)
	_fuel_value.text = "%d / %d" % [int(ship.fuel), int(ship.max_fuel)]

	var weight := inventory_manager.get_total_weight() if inventory_manager else 0.0
	var hold_ratio := weight / ship.max_cargo_weight if ship.max_cargo_weight > 0 else 0.0
	_hold_gauge.set_fill(hold_ratio, _hold_color(hold_ratio), 20, hold_ratio >= 1.0)
	_hold_value.text = "%d / %d" % [int(weight), int(ship.max_cargo_weight)]

	_flight_stats.text = "THRUST %d   TURN %.1f   BOOST %.1fx   BURN %.1f/s" % [
		ship.thrust_power, ship.turn_speed, ship.boost_power_multiplier, ship.fuel_consumption_rate]


func _update_cargo() -> void:
	_clear(_cargo_rows)
	var items := inventory_manager.get_all_items() if inventory_manager else {}
	for tier in GemData.TIERS:
		var item_id := GemData.item_id(tier)
		var qty := int(items.get(item_id, 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var color := _gem_color(tier) if qty > 0 else Colors.PRIMARY_DIM
		var icon := GemIcon.new()
		icon.color = color
		row.add_child(icon)
		var name_label := _label(GemData.display_name(item_id).to_upper(), TEXT_SIZE, color if qty > 0 else Colors.PRIMARY_DIM)
		name_label.custom_minimum_size.x = STAT_LABEL_WIDTH + 24
		row.add_child(name_label)
		row.add_child(_label("x%d" % qty, TEXT_SIZE, Colors.TEXT if qty > 0 else Colors.PRIMARY_DIM))
		row.add_child(_spacer())
		var each := _label("%d CR ea" % GemData.value_of(item_id), SMALL_SIZE, Colors.PRIMARY_DIM)
		row.add_child(each)
		var worth := _label("%d CR" % (qty * GemData.value_of(item_id)), TEXT_SIZE, Colors.PRIMARY if qty > 0 else Colors.PRIMARY_DIM)
		worth.custom_minimum_size.x = STAT_VALUE_WIDTH
		worth.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(worth)
		_cargo_rows.add_child(row)
	_hold_total.text = "%d CR" % GemData.hold_value(items)


func _update_upgrades() -> void:
	_clear(_upgrade_rows)
	var tracks := UPGRADE_TRACKS.duplicate()
	for path in gs.upgrade_levels:
		if not UPGRADE_TRACKS.any(func(t: Array) -> bool: return t[0] == path):
			tracks.append([path, String(path).capitalize().to_upper()])
	for track in tracks:
		var level := gs.get_upgrade_level(track[0])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := _label(track[1], TEXT_SIZE, Colors.PRIMARY if level > 0 else Colors.PRIMARY_DIM)
		name_label.custom_minimum_size.x = STAT_LABEL_WIDTH + 60
		row.add_child(name_label)
		var pips := Gauge.new()
		pips.custom_minimum_size.x = 60
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.set_fill(float(level) / MAX_TIER, Colors.PRIMARY, MAX_TIER)
		row.add_child(pips)
		row.add_child(_spacer())
		var tier_text := "STOCK" if level == 0 else ("MAX" if level >= MAX_TIER else "TIER %s" % "I".repeat(level))
		var tier_label := _label(tier_text, SMALL_SIZE, Colors.PRIMARY if level > 0 else Colors.PRIMARY_DIM)
		tier_label.custom_minimum_size.x = STAT_VALUE_WIDTH
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(tier_label)
		_upgrade_rows.add_child(row)


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## The robot sizes up the ship and says one thing about it.
func _greet() -> void:
	var line := _assessment()
	robot.expression = line[0]
	_status.text = line[1]
	_status.add_theme_color_override("font_color", line[2])
	robot.talking = true
	_typewriter.type_text(line[3])


## [expression, status, status color, quip]
func _assessment() -> Array:
	if not is_instance_valid(ship):
		return [&"sleep", "OFFLINE", Colors.PRIMARY_DIM, "..."]
	var fuel_level := LowFuelEffect.level_for(ship.fuel, ship.max_fuel)
	var weight := inventory_manager.get_total_weight() if inventory_manager else 0.0
	var hull_ratio := ship.hull_strength / ship.max_hull if ship.max_hull > 0 else 1.0
	if fuel_level == LowFuelEffect.Level.CRITICAL:
		return [&"worried", "ALERT", Colors.DANGER, "Tank's nearly dry, pilot. Head for a port now."]
	if hull_ratio < 0.3:
		return [&"worried", "ALERT", Colors.DANGER, "Hull's in bad shape. One more hit and we're scrap."]
	if weight >= ship.max_cargo_weight:
		return [&"happy", "HOLD FULL", Colors.SUCCESS, "Hold's packed! Dock and cash in."]
	if fuel_level == LowFuelEffect.Level.LOW:
		return [&"worried", "LOW FUEL", Colors.FUEL_HALF, "Fuel's getting low. Keep a port in range."]
	if weight <= 0.0:
		return [&"neutral", "NOMINAL", Colors.SUCCESS, "Hold's empty. Plenty of scrap out there."]
	return [&"happy", "NOMINAL", Colors.SUCCESS, "Haul's coming along nicely, pilot."]


func _gem_color(tier: GemData.Tier) -> Color:
	match tier:
		GemData.Tier.SHARD: return Colors.GEM_SHARD
		GemData.Tier.CRYSTAL: return Colors.GEM_CRYSTAL
		GemData.Tier.ARTIFACT: return Colors.GEM_ARTIFACT
	return Colors.GEM_GEM


func _hull_color(ratio: float) -> Color:
	if ratio < 0.1:
		return Colors.FUEL_EMPTY
	if ratio < 0.3:
		return Colors.FUEL_QUARTER
	if ratio < 0.6:
		return Colors.FUEL_HALF
	return Colors.PRIMARY


func _fuel_color(ratio: float) -> Color:
	if ratio <= 0.125:
		return Colors.FUEL_EIGHTH
	if ratio <= 0.25:
		return Colors.FUEL_QUARTER
	if ratio <= 0.5:
		return Colors.FUEL_HALF
	if ratio <= 0.75:
		return Colors.FUEL_THREE_QUARTERS
	return Colors.FUEL_FULL


func _hold_color(ratio: float) -> Color:
	if ratio >= 0.9:
		return Colors.CARGO_FULL
	if ratio >= 0.75:
		return Colors.CARGO_THREE_QUARTERS
	if ratio >= 0.5:
		return Colors.CARGO_HALF
	return Colors.CARGO_EMPTY


## Segmented bar. `blink` pulses the filled part (low fuel, full hold).
class Gauge extends Control:
	const HEIGHT := 12.0
	const GAP := 2.0

	var ratio := 0.0
	var color := Colors.PRIMARY
	var segments := 20
	var blink := false

	func _init() -> void:
		custom_minimum_size.y = HEIGHT
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_fill(r: float, c: Color, count: int, pulse: bool = false) -> void:
		ratio = clampf(r, 0.0, 1.0)
		color = c
		segments = maxi(count, 1)
		blink = pulse
		set_process(blink)
		queue_redraw()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := (size.x - GAP * (segments - 1)) / segments
		var filled := ceili(ratio * segments - 0.001)
		var fill := color
		if blink:
			fill.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.5)
		for i in segments:
			var rect := Rect2(floorf(i * (w + GAP)), 0, maxf(floorf(w), 1.0), HEIGHT)
			if i < filled:
				draw_rect(rect, fill)
			else:
				draw_rect(rect, Colors.PRIMARY_DIM, false, 1.0)


## Small diamond marking a gem tier.
class GemIcon extends Control:
	const SIZE := 10.0

	var color := Colors.PRIMARY

	func _init() -> void:
		custom_minimum_size = Vector2(SIZE, SIZE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := SIZE / 2.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(h, 0), Vector2(SIZE, h), Vector2(h, SIZE), Vector2(0, h)]), color)
