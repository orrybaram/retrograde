extends Control

## In-game HUD: fuel bar, hull segment bar, cargo weight, velocity readout,
## and transient action messages. Subscribes to ship signals and EventBus.action_message_changed.

@onready var dashboard: MarginContainer = $"DashboardAnchor"
@onready var fuel_progress_bar: ProgressBarWidget = $"DashboardAnchor/HBox/RightColumn/FuelRow/FuelProgressBar"
@onready var hull_segment_bar: HullSegmentBar = $"DashboardAnchor/HBox/RightColumn/HullRow/HullSegmentBar"
@onready var current_cargo_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/CurrentCargoLabel"
@onready var max_cargo_label: Label = $"DashboardAnchor/HBox/RightColumn/CargoRow/MaxCargoLabel"
@onready var velocity_label: Label = $"DashboardAnchor/HBox/LeftColumn/VelocityLabel"
@onready var action_message_label: Label = $"ActionMessageLabel"
@onready var save_indicator_label: Label = $"SaveIndicatorLabel"

var gs: Node = null
var ship: Ship = null
var _last_cargo_weight: float = 0.0
var _cargo_punch_tween: Tween = null
var _pending_cargo_flights := 0  # loot chips still flying; cargo punch waits for them

func _ready() -> void:
	add_to_group("hud")
	gs = get_tree().get_first_node_in_group("game_state")
	ship = get_tree().get_first_node_in_group("ship") as Ship

	if fuel_progress_bar:
		fuel_progress_bar.bar_color = Colors.FUEL_FULL
		fuel_progress_bar.background_color = Colors.PRIMARY_DIM
	add_child(HarvestMeter.new())
	# Auto-fit dashboard to its content
	_fit_dashboard.call_deferred()
	_update_labels()
	_last_cargo_weight = InventoryManager.get_total_weight()
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if ship and ship.has_signal("fuel_changed"):
		ship.fuel_changed.connect(_update_labels)
	if ship and ship.has_signal("cargo_changed"):
		ship.cargo_changed.connect(_on_cargo_changed)

	EventBus.action_message_changed.connect(_on_action_message_changed)
	if EventBus.is_harvest_available():
		var action_key = InputUtils.get_action_key_name("action")
		_on_action_message_changed('Press "%s" to harvest' % [action_key])
	else:
		_on_action_message_changed("")

func _on_action_message_changed(message: String) -> void:
	_update_action_message(message)

func _on_inventory_changed(item_id: String = "", new_quantity: int = 0) -> void:
	_update_labels(item_id, new_quantity)
	var new_weight = InventoryManager.get_total_weight()
	if new_weight > _last_cargo_weight and _pending_cargo_flights == 0:
		_punch_cargo_label()
	_last_cargo_weight = new_weight

func _on_cargo_changed(_current_weight: float, _max_weight: float) -> void:
	_update_labels()

func _update_action_message(message: String) -> void:
	if action_message_label:
		action_message_label.visible = message != ""
		action_message_label.text = message

func show_saving_indicator() -> void:
	if save_indicator_label:
		save_indicator_label.visible = true

func hide_saving_indicator() -> void:
	if save_indicator_label:
		save_indicator_label.visible = false

## Fly a loot chip from a world position into the cargo readout, then punch it.
func fly_item_to_cargo(world_pos: Vector2, color: Color, big: bool) -> void:
	if not current_cargo_label:
		return
	var canvas_to_local := get_global_transform_with_canvas().affine_inverse()
	var from := canvas_to_local * (get_viewport().get_canvas_transform() * world_pos)
	var to := canvas_to_local * (current_cargo_label.get_global_transform_with_canvas() * (current_cargo_label.size / 2.0))
	var chip := ColorRect.new()
	var side := 9.0 if big else 6.0
	chip.size = Vector2(side, side)
	chip.pivot_offset = chip.size / 2.0
	chip.color = color
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.position = from - chip.pivot_offset
	add_child(chip)
	_pending_cargo_flights += 1

	# Arc out sideways first, then dive into the readout.
	var control := from.lerp(to, 0.3) + (from - to).orthogonal().normalized() * 60.0
	var tween := create_tween()
	tween.tween_interval(0.08)
	tween.tween_method(func(t: float):
		var p := from.lerp(control, t).lerp(control.lerp(to, t), t)
		chip.position = p - chip.pivot_offset
		chip.rotation = t * TAU
		chip.scale = Vector2.ONE * lerpf(1.4, 0.6, t)
	, 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func():
		chip.queue_free()
		_pending_cargo_flights -= 1
		_punch_cargo_label())

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
	if not dashboard:
		return
	var min_size = dashboard.get_combined_minimum_size()
	dashboard.offset_top = -min_size.y
	dashboard.offset_right = dashboard.offset_left + min_size.x

func _process(_dt: float) -> void:
	_update_labels()

func _update_labels(_item_id: String = "", _new_quantity: int = 0) -> void:
	if gs == null: return
	var cargo_weight = InventoryManager.get_total_weight()
	var max_cargo = int(ship.max_cargo_weight) if ship and is_instance_valid(ship) and "max_cargo_weight" in ship else 5
	current_cargo_label.text = "%d" % int(cargo_weight)
	max_cargo_label.text = "/%d" % max_cargo

	if ship and is_instance_valid(ship):
		if ship.is_locked_to_planet():
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

		# Update hull segment bar
		var hull = ship.hull_strength if "hull_strength" in ship else 0.0
		var max_hull = ship.max_hull if "max_hull" in ship else 100.0
		if hull_segment_bar:
			hull_segment_bar.set_value(hull, max_hull)
	else:
		velocity_label.text = "0.0 m/s"
		if fuel_progress_bar:
			fuel_progress_bar.set_value(0.0, 100.0)
			fuel_progress_bar.bar_color = Colors.FUEL_EMPTY
		if hull_segment_bar:
			hull_segment_bar.set_value(0.0, 100.0)
