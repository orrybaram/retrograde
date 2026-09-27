extends Control

## In-game HUD: fuel bar, hull segment bar, cargo weight, Stores, velocity readout,
## and the robot's radio panel. Subscribes to ship signals. (Action prompts live in IndicatorManager.)

@onready var dashboard: MarginContainer = $"DashboardAnchor"
@onready var fuel_progress_bar: ProgressBarWidget = $"DashboardAnchor/HBox/RightColumn/FuelRow/FuelProgressBar"
@onready var hull_segment_bar: HullSegmentBar = $"DashboardAnchor/HBox/RightColumn/HullRow/HullSegmentBar"
@onready var hull_label: Label = $"DashboardAnchor/HBox/RightColumn/HullRow/HullLabel"
@onready var current_cargo_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/CurrentCargoLabel"
@onready var max_cargo_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/MaxCargoLabel"
@onready var cargo_icon: TextureRect = $"DashboardAnchor/HBox/RightColumn/CargoRow/TrolleyIcon"
@onready var stores_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/StoresLabel"
@onready var velocity_label: Label = $"DashboardAnchor/HBox/LeftColumn/VelocityLabel"
@onready var save_indicator_label: Label = $"SaveIndicatorLabel"

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

	if fuel_progress_bar:
		fuel_progress_bar.bar_color = Colors.FUEL_FULL
		fuel_progress_bar.background_color = Colors.PRIMARY_DIM
	add_child(HarvestMeter.new())
	add_child(ResonanceMeter.new())
	add_child(PlacardPanel.new())
	var radio := RadioPanel.new()
	var tracking := TrackingIndicator.new()
	tracking.blockers = [dashboard, radio]
	add_child(tracking)
	add_child(radio)
	add_child(HullWarning.new())
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
	if ship and ship.has_signal("fuel_changed"):
		ship.fuel_changed.connect(_update_labels)
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
	# fixed-width (no expand flag in HUD.tscn) — a Deposit must not stretch the fuel bar.
	if not dashboard:
		return
	var min_size = dashboard.get_combined_minimum_size()
	dashboard.offset_top = -min_size.y
	dashboard.offset_right = dashboard.offset_left + min_size.x

func _process(dt: float) -> void:
	_roll_stores(dt)
	_update_labels()

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

		# Update fuel progress bar
		var fuel = ship.fuel if "fuel" in ship else 0.0
		var max_fuel = ship.max_fuel if "max_fuel" in ship else 100.0
		var fuel_percent = (fuel / max_fuel * 100.0) if max_fuel > 0 else 0.0
		if fuel_progress_bar:
			fuel_progress_bar.set_value(fuel, max_fuel)
			if fuel <= 0:
				fuel_progress_bar.bar_color = Colors.FUEL_EMPTY
			elif fuel_percent <= 12.5:
				fuel_progress_bar.bar_color = Colors.FUEL_EIGHTH
			elif fuel_percent <= 25:
				fuel_progress_bar.bar_color = Colors.FUEL_QUARTER
			elif fuel_percent <= 50:
				fuel_progress_bar.bar_color = Colors.FUEL_HALF
			elif fuel_percent <= 75:
				fuel_progress_bar.bar_color = Colors.FUEL_THREE_QUARTERS
			else:
				fuel_progress_bar.bar_color = Colors.FUEL_FULL
			# Blink the gauge once it's low; faster when critical.
			var fuel_level := LowFuelEffect.level_for(fuel, max_fuel)
			var blink_period := 0.5 if fuel_level == LowFuelEffect.Level.CRITICAL else 1.0
			var dim := fuel_level != LowFuelEffect.Level.OK and fmod(Time.get_ticks_msec() / 1000.0, blink_period) > blink_period * 0.6
			fuel_progress_bar.modulate.a = 0.35 if dim else 1.0

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
		if fuel_progress_bar:
			fuel_progress_bar.set_value(0.0, 100.0)
			fuel_progress_bar.bar_color = Colors.FUEL_EMPTY
		if hull_segment_bar:
			hull_segment_bar.set_value(0.0, 100.0)
