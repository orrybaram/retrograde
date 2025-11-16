extends Control

@onready var fuel_label: Label = $"MarginContainer/VBoxContainer/FuelLabel"
@onready var cargo_label: Label = $"MarginContainer/VBoxContainer/CargoLabel"
@onready var position_label: Label = $"MarginContainer/VBoxContainer/PositionLabel"
@onready var velocity_label: Label = $"MarginContainer/VBoxContainer/VelocityLabel"
@onready var hull_label: Label = $"MarginContainer/VBoxContainer/HullLabel"
@onready var sell_btn: Button = $"MarginContainer/VBoxContainer/HBoxContainer/SellBtn"
@onready var upgrade_btn: Button = $"MarginContainer/VBoxContainer/HBoxContainer/UpgradeBtn"

var gs: Node = null
var ship: Ship = null

func _ready() -> void:
	gs = get_tree().get_first_node_in_group("game_state")
	ship = get_tree().get_first_node_in_group("ship") as Ship
	_update_labels()
	if gs and gs.has_signal("cargo_changed"):
		gs.cargo_changed.connect(_update_labels)
	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_update_labels)
	sell_btn.pressed.connect(_sell)
	upgrade_btn.pressed.connect(_buy_fuel)

func _process(_dt: float) -> void:
	_update_labels()

func _update_labels() -> void:
	if gs == null: return
	var fuel = gs.fuel if "fuel" in gs else 0.0
	var max_fuel = gs.max_fuel if "max_fuel" in gs else 0.0
	var cargo_b = gs.cargo["Basalt"] if "cargo" in gs else 0
	var cargo_h = gs.cargo["He3"] if "cargo" in gs else 0
	var credits = gs.credits if "credits" in gs else 0
	
	fuel_label.text = "Fuel: %.0f / %.0f" % [fuel, max_fuel]
	cargo_label.text = "Cargo: Basalt %d | He-3 %d | Credits %d" % [cargo_b, cargo_h, credits]
	
	# Update position and velocity from ship
	if ship and is_instance_valid(ship):
		var pos = ship.global_position
		position_label.text = "Position: (%.1f, %.1f)" % [pos.x, pos.y]
		
		var velocity = ship.linear_velocity
		var speed = velocity.length()
		velocity_label.text = "Velocity: %.1f m/s" % [speed]
		
		# Update hull strength
		var hull = ship.hull_strength if "hull_strength" in ship else 0.0
		var max_hull = ship.max_hull if "max_hull" in ship else 100.0
		var hull_percent = (hull / max_hull * 100.0) if max_hull > 0 else 0.0
		hull_label.text = "Hull: %.1f / %.1f (%.0f%%)" % [hull, max_hull, hull_percent]
		
		# Change color based on hull status
		if hull <= 0:
			hull_label.modulate = Color.RED
		elif hull_percent < 30:
			hull_label.modulate = Color(1.0, 0.5, 0.0)  # Orange
		elif hull_percent < 60:
			hull_label.modulate = Color.YELLOW
		else:
			hull_label.modulate = Color.WHITE
	else:
		position_label.text = "Position: (0, 0)"
		velocity_label.text = "Velocity: 0.0 m/s"
		hull_label.text = "Hull: 0 / 100 (0%)"
		hull_label.modulate = Color.RED

func _sell() -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	var home := get_tree().get_nodes_in_group("planets")[0] as Node2D
	if ship.global_position.distance_to(home.global_position) > 170.0:
		return
	var economy = get_tree().get_first_node_in_group("economy")
	var total: int = int(gs.cargo["Basalt"]) * economy.PRICES["Basalt"] + int(gs.cargo["He3"]) * economy.PRICES["He3"]
	gs.credits += total
	gs.clear_cargo()

func _buy_fuel() -> void:
	var economy = get_tree().get_first_node_in_group("economy")
	var cost: int = economy.get_cost("FuelTank_I")
	if gs.credits >= cost:
		gs.credits -= cost
		economy.apply_upgrade("FuelTank_I", gs)
