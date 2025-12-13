extends Control
class_name InventoryUI

## Inventory UI showing ship systems, upgrades, and cargo.
## Opens/closes with "i" key.

signal dialogue_closed

@onready var title_label: Label = $CenterContainer/InventoryWindow/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var systems_label: Label = $CenterContainer/InventoryWindow/MarginContainer/VBoxContainer/ContentContainer/SystemsSection/SystemsContent
@onready var upgrades_label: Label = $CenterContainer/InventoryWindow/MarginContainer/VBoxContainer/ContentContainer/UpgradesSection/UpgradesContent
@onready var cargo_label: Label = $CenterContainer/InventoryWindow/MarginContainer/VBoxContainer/ContentContainer/CargoSection/CargoContent
@onready var close_button: Button = $CenterContainer/InventoryWindow/MarginContainer/VBoxContainer/ActionsContainer/CloseButton

var ship: Ship = null
var gs: GameState = null
var inventory_manager: InventoryManager = null


func _ready() -> void:
	visible = false
	ship = get_tree().get_first_node_in_group("ship") as Ship
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	inventory_manager = get_node_or_null("/root/InventoryManager") as InventoryManager
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connect to signals for live updates
	if gs:
		if gs.has_signal("credits_changed"):
			gs.credits_changed.connect(_update_display)
		if gs.has_signal("upgrade_level_changed"):
			gs.upgrade_level_changed.connect(_update_display)
	if ship and ship.has_signal("fuel_changed"):
		ship.fuel_changed.connect(_update_display)
	if inventory_manager and inventory_manager.has_signal("inventory_changed"):
		inventory_manager.inventory_changed.connect(_update_display)


func open_inventory() -> void:
	visible = true
	_update_display()
	
	if ship and ship.camera:
		ship.camera.zoom_camera_in(Vector2(2.5, 2.5))


func close_inventory() -> void:
	visible = false
	
	if ship and ship.camera:
		ship.camera.zoom_camera_out()
	
	dialogue_closed.emit()


func _update_display() -> void:
	if not ship or not gs:
		return
	
	_update_systems()
	_update_upgrades()
	_update_cargo()


func _update_systems() -> void:
	if not systems_label or not ship:
		return
	
	var hull_percent = (ship.hull_strength / ship.max_hull * 100.0) if ship.max_hull > 0 else 0.0
	var fuel_percent = (ship.fuel / ship.max_fuel * 100.0) if ship.max_fuel > 0 else 0.0
	
	var systems_text = ""
	systems_text += "Hull: %.0f/%.0f (%.0f%%)\n" % [ship.hull_strength, ship.max_hull, hull_percent]
	systems_text += "Fuel: %.0f/%.0f (%.0f%%)\n" % [ship.fuel, ship.max_fuel, fuel_percent]
	systems_text += "Thrust Power: %.0f\n" % ship.thrust_power
	systems_text += "Turn Speed: %.1f\n" % ship.turn_speed
	systems_text += "Fuel Consumption: %.1f/s\n" % ship.fuel_consumption_rate
	systems_text += "Boost Multiplier: %.1fx\n" % ship.boost_power_multiplier
	
	if gs:
		systems_text += "Credits: %d\n" % gs.credits
		systems_text += "Drone Bay: %s\n" % ("Enabled" if gs.has_drone_bay else "Disabled")
	
	systems_label.text = systems_text


func _update_upgrades() -> void:
	if not upgrades_label or not gs:
		return
	
	var upgrades_text = ""
	
	if gs.upgrade_levels.is_empty():
		upgrades_text = "No upgrades purchased"
	else:
		for path in gs.upgrade_levels.keys():
			var tier = gs.upgrade_levels[path]
			var path_display = path.capitalize()
			upgrades_text += "%s: Tier %d\n" % [path_display, tier]
	
	upgrades_label.text = upgrades_text


func _update_cargo() -> void:
	if not cargo_label or not inventory_manager:
		return
	
	var cargo_text = ""
	var all_items = inventory_manager.get_all_items()
	
	if all_items.is_empty():
		cargo_text = "No cargo"
	else:
		for item_id in all_items.keys():
			var quantity = all_items[item_id] as int
			var item_display = item_id.capitalize()
			cargo_text += "%s: %d\n" % [item_display, quantity]
	
	cargo_label.text = cargo_text


func _on_close_pressed() -> void:
	close_inventory()

