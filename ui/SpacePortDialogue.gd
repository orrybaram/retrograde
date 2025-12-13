extends Control
class_name SpacePortDialogue

## Space Port dialogue UI for repairing and refueling the ship.

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var hull_label: Label = $MarginContainer/VBoxContainer/HullLabel
@onready var fuel_label: Label = $MarginContainer/VBoxContainer/FuelLabel
@onready var credits_label: Label = $MarginContainer/VBoxContainer/CreditsLabel
@onready var repair_button: Button = $MarginContainer/VBoxContainer/RepairButton
@onready var refuel_button: Button = $MarginContainer/VBoxContainer/RefuelButton
@onready var store_button: Button = $MarginContainer/VBoxContainer/StoreButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var ship: Ship = null
var spaceport: SpacePort = null
var gs: GameState = null
var economy: Economy = null
var zoom_tween: Tween = null
var _store_ui: StoreUI = null

signal dialogue_closed

func _ready() -> void:
	visible = false
	ship = get_tree().get_first_node_in_group("ship") as Ship
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	economy = get_tree().get_first_node_in_group("economy") as Economy
	
	if repair_button:
		repair_button.pressed.connect(_on_repair_pressed)
	if refuel_button:
		refuel_button.pressed.connect(_on_refuel_pressed)
	if store_button:
		store_button.pressed.connect(_on_store_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connect to signals for updates
	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_update_display)
	if ship and ship.has_signal("fuel_changed"):
		ship.fuel_changed.connect(_update_display)

func open_dialogue(target_spaceport: SpacePort) -> void:
	spaceport = target_spaceport
	
	visible = true
	_update_display()
	ship.camera.zoom_camera_in(Vector2(2.5,2.5))

func close_dialogue() -> void:
	visible = false
	spaceport = null
	ship.camera.zoom_camera_out()
	dialogue_closed.emit()

func _update_display() -> void:
	if not ship or not gs or not economy:
		return
	
	if title_label:
		title_label.text = "SPACE PORT"
	
	# Update hull display
	var hull = ship.hull_strength
	var max_hull = ship.max_hull
	var hull_percent = (hull / max_hull * 100.0) if max_hull > 0 else 0.0
	if hull_label:
		hull_label.text = "Hull: %.0f/%.0f (%.0f%%)" % [hull, max_hull, hull_percent]
	
	# Update fuel display
	var fuel = ship.fuel
	var max_fuel = ship.max_fuel
	var fuel_percent = (fuel / max_fuel * 100.0) if max_fuel > 0 else 0.0
	if fuel_label:
		fuel_label.text = "Fuel: %.0f/%.0f (%.0f%%)" % [fuel, max_fuel, fuel_percent]
	
	# Update credits display
	if credits_label:
		credits_label.text = "Credits: %d" % [gs.credits]
	
	# Calculate repair cost
	var repair_cost = int((max_hull - hull) * Economy.REPAIR_COST_PER_POINT)
	if repair_button:
		if repair_cost > 0 and gs.credits >= repair_cost:
			repair_button.text = "Repair (%d credits)" % [repair_cost]
			repair_button.disabled = false
		elif repair_cost > 0:
			repair_button.text = "Repair (%d credits) [Insufficient]" % [repair_cost]
			repair_button.disabled = true
		else:
			repair_button.text = "Repair (Full)"
			repair_button.disabled = true
	
	# Calculate refuel cost
	var refuel_cost = int((max_fuel - fuel) * Economy.REFUEL_COST_PER_POINT)
	if refuel_button:
		if refuel_cost > 0 and gs.credits >= refuel_cost:
			refuel_button.text = "Refuel (%d credits)" % [refuel_cost]
			refuel_button.disabled = false
		elif refuel_cost > 0:
			refuel_button.text = "Refuel (%d credits) [Insufficient]" % [refuel_cost]
			refuel_button.disabled = true
		else:
			refuel_button.text = "Refuel (Full)"
			refuel_button.disabled = true

func _on_repair_pressed() -> void:
	if not ship or not gs or not economy:
		return
	
	var max_hull = ship.max_hull
	var hull = ship.hull_strength
	var repair_cost = int((max_hull - hull) * Economy.REPAIR_COST_PER_POINT)
	
	if repair_cost > 0 and gs.credits >= repair_cost:
		gs.credits -= repair_cost
		ship.hull_strength = max_hull
		_update_display()

func _on_refuel_pressed() -> void:
	if not ship or not gs or not economy:
		return
	
	var max_fuel = ship.max_fuel
	var fuel = ship.fuel
	var refuel_cost = int((max_fuel - fuel) * Economy.REFUEL_COST_PER_POINT)
	
	if refuel_cost > 0 and gs.credits >= refuel_cost:
		gs.credits -= refuel_cost
		ship.fuel = max_fuel
		ship.fuel_changed.emit()
		_update_display()

func _on_store_pressed() -> void:
	if not spaceport:
		return
	
	# Find the Store component on the spaceport
	var store = spaceport.get_node_or_null("Store") as Store
	if not store:
		push_warning("SpacePort has no Store component")
		return
	
	# Find StoreUI in the scene
	if not _store_ui or not is_instance_valid(_store_ui):
		var current_scene = get_tree().current_scene
		if current_scene:
			var canvas_layer = current_scene.get_node_or_null("CanvasLayer")
			if canvas_layer:
				_store_ui = canvas_layer.get_node_or_null("StoreUI") as StoreUI
	
	if _store_ui:
		# Hide this dialogue and open the store
		visible = false
		_store_ui.open_dialogue(store)
		# Connect to store close to reopen this dialogue
		if not _store_ui.dialogue_closed.is_connected(_on_store_closed):
			_store_ui.dialogue_closed.connect(_on_store_closed)

func _on_store_closed() -> void:
	# Reopen this dialogue when store closes
	visible = true
	_update_display()

func _on_close_pressed() -> void:
	close_dialogue()
