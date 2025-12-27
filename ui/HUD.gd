extends Control

@onready var fuel_progress_bar: ProgressBarWidget = $"MarginContainer/VBoxContainer/FuelProgressBar"
@onready var hull_progress_bar: ProgressBarWidget = $"MarginContainer/VBoxContainer/HullProgressBar"
@onready var cargo_label: Label = $"MarginContainer/VBoxContainer/CargoLabel"
@onready var position_label: Label = $"MarginContainer/VBoxContainer/PositionLabel"
@onready var velocity_label: Label = $"MarginContainer/VBoxContainer/VelocityLabel"
@onready var action_message_label: Label = $"ActionMessageLabel"

var gs: Node = null
var ship: Ship = null

func _ready() -> void:
	gs = get_tree().get_first_node_in_group("game_state")
	ship = get_tree().get_first_node_in_group("ship") as Ship
	
	# Configure progress bar colors (terminal amber)
	if fuel_progress_bar:
		fuel_progress_bar.bar_color = Colors.FUEL_FULL  # Amber for fuel
	if hull_progress_bar:
		hull_progress_bar.bar_color = Color(1.0, 0.75, 0.0)  # Amber for hull (will be updated dynamically)
	
	_update_labels()
	# Connect to InventoryManager for inventory changes
	InventoryManager.inventory_changed.connect(_update_labels)
	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_update_labels)
	if ship and ship.has_signal("fuel_changed"):
		ship.fuel_changed.connect(_update_labels)
	
	
	# Connect to EventBus for action messages
	EventBus.action_message_changed.connect(_on_action_message_changed)
	# Check initial state (harvest message if available)
	if EventBus.is_harvest_available():
		var action_key = InputUtils.get_action_key_name("action")
		_on_action_message_changed('Press "%s" to harvest' % [action_key])
	else:	
		_on_action_message_changed("")

func _on_action_message_changed(message: String) -> void:
	_update_action_message(message)

func _update_action_message(message: String) -> void:
	if action_message_label:
		action_message_label.visible = message != ""
		action_message_label.text = message

func _process(_dt: float) -> void:
	_update_labels()

func _update_labels(_item_id: String = "", _new_quantity: int = 0) -> void:
	# Parameters are provided by inventory_changed signal but not used
	# since we query InventoryManager directly
	if gs == null: return
	var cargo_scrap = InventoryManager.get_quantity("scrap")
	var credits = gs.credits if "credits" in gs else 0
	
	cargo_label.text = "Cargo: Scrap %d | Credits %d" % [cargo_scrap, credits]
	
	# Update position, velocity, fuel, and hull from ship
	if ship and is_instance_valid(ship):
		var pos = ship.global_position
		position_label.text = "Position: (%.1f, %.1f)" % [pos.x, pos.y]
		
		# Show 0 velocity if ship is landed
		if ship.is_locked_to_planet():
			velocity_label.text = "Velocity: 0.0 m/s"
		else:
			var velocity = ship.linear_velocity
			var speed = velocity.length()
			velocity_label.text = "Velocity: %.1f m/s" % [speed]
		
		# Update fuel progress bar
		var fuel = ship.fuel if "fuel" in ship else 0.0
		var max_fuel = ship.max_fuel if "max_fuel" in ship else 100.0
		var fuel_percent = (fuel / max_fuel * 100.0) if max_fuel > 0 else 0.0
		if fuel_progress_bar:
			fuel_progress_bar.set_value(fuel, max_fuel)
			
			# Change color based on fuel level (terminal-appropriate colors)
			if fuel <= 0:
				fuel_progress_bar.bar_color = Colors.FUEL_EMPTY
			elif fuel_percent <= 12.5:
				fuel_progress_bar.bar_color = Colors.FUEL_EIGHTH  # Red (1/8)
			elif fuel_percent <= 25:
				fuel_progress_bar.bar_color = Colors.FUEL_QUARTER
			elif fuel_percent <= 50:
				fuel_progress_bar.bar_color = Colors.FUEL_HALF
			elif fuel_percent <= 75:
				fuel_progress_bar.bar_color = Colors.FUEL_THREE_QUARTERS
			else:
				fuel_progress_bar.bar_color = Colors.FUEL_FULL
		
		# Update hull progress bar
		var hull = ship.hull_strength if "hull_strength" in ship else 0.0
		var max_hull = ship.max_hull if "max_hull" in ship else 100.0
		var hull_percent = (hull / max_hull * 100.0) if max_hull > 0 else 0.0
		if hull_progress_bar:
			hull_progress_bar.set_value(hull, max_hull)
			
			# Change color based on hull status (terminal-appropriate colors)
			if hull <= 0:
				hull_progress_bar.bar_color = Color(1.0, 0.3, 0.0)  # Red-orange
			elif hull_percent < 10:
				hull_progress_bar.bar_color = Color(1.0, 0.3, 0.0)  # Red-orange
			elif hull_percent < 30:
				hull_progress_bar.bar_color = Color(1.0, 0.5, 0.0)  # Orange
			elif hull_percent < 60:
				hull_progress_bar.bar_color = Color(1.0, 0.65, 0.0)  # Amber-orange
			else:
				hull_progress_bar.bar_color = Color(1.0, 0.75, 0.0)  # Amber
	else:
		position_label.text = "Position: (0, 0)"
		velocity_label.text = "Velocity: 0.0 m/s"
		if fuel_progress_bar:
			fuel_progress_bar.set_value(0.0, 100.0)
			fuel_progress_bar.bar_color = Colors.FUEL_EMPTY
		if hull_progress_bar:
			hull_progress_bar.set_value(0.0, 100.0)
			hull_progress_bar.bar_color = Color(1.0, 0.3, 0.0)  # Red-orange
