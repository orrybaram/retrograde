extends Control
class_name SpacePortDialogue

## Space Port dialogue UI for repairing and refueling the ship.

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var hull_label: Label = $MarginContainer/VBoxContainer/HullLabel
@onready var fuel_label: Label = $MarginContainer/VBoxContainer/FuelLabel
@onready var credits_label: Label = $MarginContainer/VBoxContainer/CreditsLabel
@onready var repair_button: Button = $MarginContainer/VBoxContainer/RepairButton
@onready var refuel_button: Button = $MarginContainer/VBoxContainer/RefuelButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

var ship: Ship = null
var spaceport: SpacePort = null
var gs: GameState = null
var economy: Economy = null
var camera: Camera2D = null
var original_zoom: Vector2 = Vector2.ONE
var zoom_tween: Tween = null

signal dialogue_closed

func _ready() -> void:
	visible = false
	ship = get_tree().get_first_node_in_group("ship") as Ship
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	economy = get_tree().get_first_node_in_group("economy") as Economy
	
	if ship:
		camera = ship.get_node_or_null("Camera2D") as Camera2D
		if camera:
			original_zoom = camera.zoom
	
	if repair_button:
		repair_button.pressed.connect(_on_repair_pressed)
	if refuel_button:
		refuel_button.pressed.connect(_on_refuel_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Connect to signals for updates
	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_update_display)
	if ship and ship.has_signal("fuel_changed"):
		ship.fuel_changed.connect(_update_display)

func open_dialogue(target_spaceport: SpacePort) -> void:
	spaceport = target_spaceport
	
	# Ensure we have references
	if not ship:
		ship = get_tree().get_first_node_in_group("ship") as Ship
	if not camera and ship:
		camera = ship.get_node_or_null("Camera2D") as Camera2D
		if camera:
			original_zoom = camera.zoom
	
	visible = true
	_update_display()
	_zoom_camera_in()

func close_dialogue() -> void:
	visible = false
	spaceport = null
	_zoom_camera_out()
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

func _on_close_pressed() -> void:
	close_dialogue()

func _zoom_camera_in() -> void:
	if not camera:
		return
	
	# Kill any existing zoom tween
	if zoom_tween:
		zoom_tween.kill()
	
	# Store original zoom if not already stored
	if original_zoom == Vector2.ONE:
		original_zoom = camera.zoom
	
	# Create tween for zoom
	zoom_tween = create_tween()
	
	# Zoom in (e.g., to 2.5x)
	var target_zoom = Vector2(2.5, 2.5)
	zoom_tween.tween_property(camera, "zoom", target_zoom, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _zoom_camera_out() -> void:
	if not camera:
		return
	
	# Kill any existing zoom tween
	if zoom_tween:
		zoom_tween.kill()
	
	# Create tween to zoom back out
	zoom_tween = create_tween()
	
	# Zoom back to original
	zoom_tween.tween_property(camera, "zoom", original_zoom, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

