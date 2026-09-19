class_name ShipTab
extends LogTab

## The Log's opening tab: what the ship is carrying and what shape it is in.
## Ship gauges, the hold manifest and the upgrade tiers, across the full body width.

const TEXT_SIZE := TerminalWindow.TEXT_SIZE
const SMALL_SIZE := TerminalWindow.SMALL_SIZE
const STAT_LABEL_WIDTH := 64.0
const STAT_VALUE_WIDTH := 96.0
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

var _hull_gauge: SegmentGauge
var _hull_value: Label
var _fuel_gauge: SegmentGauge
var _fuel_value: Label
var _hold_gauge: SegmentGauge
var _hold_value: Label
var _flight_stats: Label
var _cargo_rows: VBoxContainer
var _hold_total: Label
var _upgrade_rows: VBoxContainer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_build()


func tab_title() -> String:
	return "SHIP"


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	add_child(TerminalWindow.header("S Y S T E M S"))
	var hull := _gauge_row("HULL")
	_hull_gauge = hull[0]
	_hull_value = hull[1]
	add_child(hull[2])
	var fuel := _gauge_row("FUEL")
	_fuel_gauge = fuel[0]
	_fuel_value = fuel[1]
	add_child(fuel[2])
	var hold := _gauge_row("HOLD")
	_hold_gauge = hold[0]
	_hold_value = hold[1]
	add_child(hold[2])
	_flight_stats = TerminalWindow.label("", SMALL_SIZE, Colors.PRIMARY_DIM)
	add_child(_flight_stats)

	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	add_child(gap)
	add_child(TerminalWindow.header("C A R G O"))
	_cargo_rows = VBoxContainer.new()
	_cargo_rows.add_theme_constant_override("separation", 6)
	add_child(_cargo_rows)
	add_child(TerminalWindow.rule())
	var total := HBoxContainer.new()
	total.add_child(TerminalWindow.label("HOLD VALUE", TEXT_SIZE, Colors.PRIMARY_DIM))
	total.add_child(TerminalWindow.spacer())
	_hold_total = TerminalWindow.label("", TEXT_SIZE, Colors.PRIMARY)
	total.add_child(_hold_total)
	add_child(total)

	add_child(TerminalWindow.filler())
	add_child(TerminalWindow.header("U P G R A D E S"))
	_upgrade_rows = VBoxContainer.new()
	_upgrade_rows.add_theme_constant_override("separation", 6)
	add_child(_upgrade_rows)


## [gauge, value label, row]
func _gauge_row(title: String) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := TerminalWindow.label(title, TEXT_SIZE, Colors.PRIMARY)
	name_label.custom_minimum_size.x = STAT_LABEL_WIDTH
	row.add_child(name_label)
	var gauge := SegmentGauge.new()
	gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gauge)
	var value := TerminalWindow.label("", TEXT_SIZE, Colors.TEXT)
	value.custom_minimum_size.x = STAT_VALUE_WIDTH
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return [gauge, value, row]


# --- Content -----------------------------------------------------------------

func refresh() -> void:
	# The ship respawns on death, so re-resolve it every time.
	ship = get_tree().get_first_node_in_group("ship") as Ship
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	inventory_manager = get_node_or_null("/root/InventoryManager") as InventoryManager
	if not is_instance_valid(ship) or not gs:
		return
	_update_systems()
	_update_cargo()
	_update_upgrades()


func _update_systems() -> void:
	var hull_ratio := ship.hull_strength / ship.max_hull if ship.max_hull > 0 else 0.0
	var hull_level := LowHullEffect.level_for(ship.hull_strength, ship.max_hull)
	_hull_gauge.set_fill(hull_ratio, _hull_color(hull_ratio), int(ceil(ship.max_hull / 10.0)),
			hull_level != LowHullEffect.Level.OK)
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
		var name_label := TerminalWindow.label(GemData.display_name(item_id).to_upper(), TEXT_SIZE, color)
		name_label.custom_minimum_size.x = STAT_LABEL_WIDTH + 24
		row.add_child(name_label)
		row.add_child(TerminalWindow.label("x%d" % qty, TEXT_SIZE, Colors.TEXT if qty > 0 else Colors.PRIMARY_DIM))
		row.add_child(TerminalWindow.spacer())
		row.add_child(TerminalWindow.label("%d CR ea" % GemData.value_of(item_id), SMALL_SIZE, Colors.PRIMARY_DIM))
		var worth := TerminalWindow.label("%d CR" % (qty * GemData.value_of(item_id)), TEXT_SIZE, Colors.PRIMARY if qty > 0 else Colors.PRIMARY_DIM)
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
		var lit := Colors.PRIMARY if level > 0 else Colors.PRIMARY_DIM
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := TerminalWindow.label(track[1], TEXT_SIZE, lit)
		name_label.custom_minimum_size.x = STAT_LABEL_WIDTH + 60
		row.add_child(name_label)
		var pips := SegmentGauge.new()
		pips.custom_minimum_size.x = 60
		pips.set_fill(float(level) / MAX_TIER, Colors.PRIMARY, MAX_TIER)
		row.add_child(pips)
		row.add_child(TerminalWindow.spacer())
		var tier_label := TerminalWindow.label(tier_name(level, MAX_TIER), SMALL_SIZE, lit)
		tier_label.custom_minimum_size.x = STAT_VALUE_WIDTH
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(tier_label)
		_upgrade_rows.add_child(row)


static func tier_name(level: int, max_tier: int) -> String:
	if level <= 0:
		return "STOCK"
	if level >= max_tier:
		return "MAX"
	return "TIER %s" % "I".repeat(level)


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


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
