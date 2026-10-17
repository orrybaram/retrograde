extends Control

## In-game HUD: boost gauge (around the minimap), hull segment bar, cargo weight, Stores, velocity readout,
## and the robot's radio panel. Subscribes to ship signals. (Action prompts live in IndicatorManager.)
## The ship's manual diagnostic (BootLog) takes the dashboard's corner while a new game owes
## it; the dashboard is dark until then, and glitches back on a piece at a time once the
## pilot has the controls.

## The dashboard's pieces powering up after the diagnostic: how long each stutters before
## it holds, the beat before the next starts, how often the stutter changes, how far a
## cold piece tears sideways (px), and the flare as it catches.
const POWER_TIME := 0.5
const POWER_STAGGER := 0.28
const POWER_ROLL := 0.04
const POWER_TEAR := 6.0
const POWER_FLARE := 0.08
const POWER_FLARE_GAIN := 1.6

@onready var dashboard: MarginContainer = $"DashboardAnchor"
@onready var boost_gauge: BoostGauge = $"DashboardAnchor/HBox/LeftColumn/MinimapDial/BoostGauge"
@onready var hull_segment_bar: HullSegmentBar = $"DashboardAnchor/HBox/RightColumn/HullRow/HullSegmentBar"
@onready var hull_label: Label = $"DashboardAnchor/HBox/RightColumn/HullRow/HullLabel"
@onready var current_cargo_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/CurrentCargoLabel"
@onready var max_cargo_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/MaxCargoLabel"
@onready var cargo_icon: TextureRect = $"DashboardAnchor/HBox/RightColumn/CargoRow/TrolleyIcon"
@onready var stores_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/StoresLabel"
@onready var velocity_label: Label = $"DashboardAnchor/HBox/LeftColumn/VelocityLabel"
@onready var save_indicator_label: Label = $"SaveIndicatorLabel"
## Powered up in this order: the minimap's dial, then the readouts top to bottom.
@onready var dashboard_pieces: Array[Control] = [
	$"DashboardAnchor/HBox/LeftColumn/MinimapDial",
	$"DashboardAnchor/HBox/LeftColumn/VelocityLabel",
	$"DashboardAnchor/HBox/RightColumn/HullRow",
	$"DashboardAnchor/HBox/RightColumn/CargoRow",
]
var boot_log: BootLog = null
## Seconds into the power-up, or below 0 when none is running; each piece's laid-out
## position while it tears; and its own RNG, so the stutter never shifts gameplay rolls.
var _power_t := -1.0
var _power_roll := 0.0
var _power_home := {}
var _power_rng := RandomNumberGenerator.new()

var gs: Node = null
var ship: Ship = null
var _last_cargo_weight: float = 0.0
var _cargo_punch_tween: Tween = null
var _shown_stores := 0.0  # rolls toward gs.stores so the Deposit counts up
var _stores_punch_tween: Tween = null

func _ready() -> void:
	add_to_group("hud")
	gs = get_tree().get_first_node_in_group("game_state")
	ship = get_tree().get_first_node_in_group("ship") as Ship

	if boost_gauge:
		boost_gauge.ship = ship
	add_child(HarvestMeter.new())
	add_child(ResonanceMeter.new())
	add_child(PlacardPanel.new())
	var radio := RadioPanel.new()
	var tracking := TrackingIndicator.new()
	boot_log = BootLog.new()
	boot_log.dashboard = dashboard
	tracking.blockers = [dashboard, radio, boot_log]
	add_child(tracking)
	add_child(radio)
	add_child(HullWarning.new())
	add_child(boot_log)
	# Added last so it processes after _update_labels and rots the finished readouts
	var glitch := HudGlitch.new()
	glitch.name = "HudGlitch"
	add_child(glitch)
	# Auto-fit dashboard to its content
	_fit_dashboard.call_deferred()
	if gs:
		_shown_stores = gs.stores
	_update_labels()
	_last_cargo_weight = InventoryManager.get_total_weight()
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if ship:
		ship.drive.changed.connect(_update_labels)
	if ship and ship.has_signal("cargo_changed"):
		ship.cargo_changed.connect(_on_cargo_changed)

func _on_inventory_changed(item_id: String = "", new_quantity: int = 0) -> void:
	_update_labels(item_id, new_quantity)
	var new_weight = InventoryManager.get_total_weight()
	if new_weight > _last_cargo_weight:
		_punch_cargo_label()
	_last_cargo_weight = new_weight

func _on_cargo_changed(_current_weight: float, _max_weight: float) -> void:
	_update_labels()

func show_saving_indicator() -> void:
	if save_indicator_label:
		save_indicator_label.visible = true

func hide_saving_indicator() -> void:
	if save_indicator_label:
		save_indicator_label.visible = false

func _punch_cargo_label() -> void:
	if not current_cargo_label:
		return

	if _cargo_punch_tween and _cargo_punch_tween.is_valid():
		_cargo_punch_tween.kill()

	current_cargo_label.pivot_offset = current_cargo_label.size / 2.0
	_cargo_punch_tween = create_tween()
	# Scale punch
	_cargo_punch_tween.tween_property(current_cargo_label, "scale", Vector2(1.3, 1.3), 0.1).set_ease(Tween.EASE_OUT)
	_cargo_punch_tween.tween_property(current_cargo_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	# Flash bright amber
	current_cargo_label.modulate = Colors.PRIMARY * 1.5
	current_cargo_label.modulate.a = 1.0
	_cargo_punch_tween.parallel().tween_property(current_cargo_label, "modulate", Color.WHITE, 0.3)

func _fit_dashboard() -> void:
	# The panel breathes with the cargo and Stores digit counts, so the meters are
	# fixed-width (no expand flag in HUD.tscn) — a Deposit must not stretch the hull bar.
	if not dashboard:
		return
	var min_size = dashboard.get_combined_minimum_size()
	dashboard.offset_top = -min_size.y
	dashboard.offset_right = dashboard.offset_left + min_size.x

func _process(dt: float) -> void:
	_cede_corner()
	_power_up_step(dt)
	_roll_stores(dt)
	_update_labels()

## Dark while the diagnostic has the corner. Back when it lets go: powered up a piece at a
## time if it handed the pilot the controls, at once if anything else ended it (a load, a
## skipped opening).
func _cede_corner() -> void:
	var held := boot_log != null and boot_log.holds_corner()
	if held:
		if _power_t >= 0.0:
			_settle_pieces()
		dashboard.visible = false
	elif not dashboard.visible:
		dashboard.visible = true
		if boot_log.handed_over:
			boot_log.handed_over = false
			_power_up()
		else:
			_settle_pieces()

## Each piece in turn stutters on: it cuts in and out and tears sideways, catching more
## often as it warms, then flares as it holds.
func _power_up() -> void:
	_settle_pieces()
	for piece in dashboard_pieces:
		piece.modulate.a = 0.0
	_power_t = 0.0
	_power_roll = 0.0

func _power_up_step(dt: float) -> void:
	if _power_t < 0.0:
		return
	_power_t += dt
	_power_roll -= dt
	var reroll := _power_roll <= 0.0
	if reroll:
		_power_roll = POWER_ROLL
	var done := true
	for i in dashboard_pieces.size():
		var piece := dashboard_pieces[i]
		var local := _power_t - i * POWER_STAGGER
		if local < 0.0:
			done = false
			piece.modulate.a = 0.0
			continue
		if not _power_home.has(piece):
			_power_home[piece] = piece.position  # laid out by now: where it tears back to
		var home: Vector2 = _power_home[piece]
		if local < POWER_TIME:
			done = false
			if reroll:
				var warm := local / POWER_TIME
				var lit := _power_rng.randf() < 0.25 + 0.65 * warm
				piece.modulate = Color(Color.WHITE, _power_rng.randf_range(0.55, 1.0) if lit else _power_rng.randf_range(0.0, 0.12))
				var tear := _power_rng.randf_range(-1.0, 1.0) * POWER_TEAR * (1.0 - warm) if _power_rng.randf() < 0.4 else 0.0
				piece.position = home + Vector2(tear, 0.0)
		elif local < POWER_TIME + POWER_FLARE:
			done = false
			piece.position = home
			piece.modulate = Color.WHITE * POWER_FLARE_GAIN
		else:
			piece.position = home
			piece.modulate = Color.WHITE
	if done:
		_settle_pieces()

## Every piece where it belongs and lit, the power-up over.
func _settle_pieces() -> void:
	for piece in dashboard_pieces:
		piece.modulate = Color.WHITE
		if _power_home.has(piece):
			piece.position = _power_home[piece]
	_power_home.clear()
	_power_t = -1.0

## Whether the dashboard is up, done powering up and every piece lit, for scenarios.
func dashboard_settled() -> bool:
	if not dashboard.visible or _power_t >= 0.0:
		return false
	for piece in dashboard_pieces:
		if piece.modulate != Color.WHITE:
			return false
	return true

## During a Deposit, tick the shown Stores count up toward `gs.stores`; otherwise
## (loads, a Gate powering up) snap to it.
func _roll_stores(dt: float) -> void:
	if gs == null:
		return
	var target := float(gs.stores)
	if HoldDeposit.running == 0 or target < _shown_stores:
		_shown_stores = target
		return
	var step := maxf(absf(target - _shown_stores) * 10.0, 40.0) * dt
	var before := int(_shown_stores)
	_shown_stores = move_toward(_shown_stores, target, step)
	if int(_shown_stores) > before:
		_punch_stores_label()

func _punch_stores_label() -> void:
	if not stores_label or (_stores_punch_tween and _stores_punch_tween.is_running()):
		return
	stores_label.pivot_offset = stores_label.size / 2.0
	_stores_punch_tween = create_tween()
	_stores_punch_tween.tween_property(stores_label, "scale", Vector2(1.15, 1.15), 0.05)
	_stores_punch_tween.tween_property(stores_label, "scale", Vector2.ONE, 0.1)

func _update_labels(_item_id: String = "", _new_quantity: int = 0) -> void:
	if gs == null: return
	var cargo_weight = InventoryManager.get_total_weight()
	var max_cargo = int(ship.max_cargo_weight) if ship and is_instance_valid(ship) and "max_cargo_weight" in ship else 50
	# No hold, no readout: the ship has nothing to fill, not an empty hold
	var has_hold: bool = max_cargo > 0
	for node: CanvasItem in [cargo_icon, current_cargo_label, max_cargo_label]:
		node.visible = has_hold
	current_cargo_label.text = "%d" % int(cargo_weight)
	var cargo_full: bool = cargo_weight >= max_cargo
	max_cargo_label.text = "/%d FULL" % max_cargo if cargo_full else "/%d" % max_cargo
	stores_label.text = "  %d ST" % int(_shown_stores)
	var cargo_color := Colors.DANGER if cargo_full else Colors.PRIMARY
	current_cargo_label.add_theme_color_override("font_color", cargo_color)
	max_cargo_label.add_theme_color_override("font_color", Colors.DANGER if cargo_full else Colors.PRIMARY_DIM)

	if ship and is_instance_valid(ship):
		if ship.is_locked_to_planet() or ship.is_landed_on_planet():
			velocity_label.text = "0.0 m/s"
		else:
			var speed = ship.linear_velocity.length()
			velocity_label.text = "%.1f m/s" % [speed]

		if boost_gauge:
			boost_gauge.set_fuel(ship.drive.fuel, ship.drive.max_fuel)

		# Update hull segment bar
		var hull = ship.hull_strength if "hull_strength" in ship else 0.0
		var max_hull = ship.max_hull if "max_hull" in ship else 100.0
		if hull_segment_bar:
			hull_segment_bar.set_value(hull, max_hull)
		# The row's own label goes red with it, so the warning starts at the readout.
		if hull_label:
			var hull_level := LowHullEffect.level_for(hull, max_hull)
			hull_label.add_theme_color_override("font_color",
					Colors.PRIMARY if hull_level == LowHullEffect.Level.OK else Colors.DANGER)
	else:
		velocity_label.text = "0.0 m/s"
		if boost_gauge:
			boost_gauge.set_fuel(0.0, 100.0)
		if hull_segment_bar:
			hull_segment_bar.set_value(0.0, 100.0)
