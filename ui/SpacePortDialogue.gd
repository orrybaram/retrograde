extends Control
class_name SpacePortDialogue

## Space Port dialogue UI for repairing the ship.
## Terminal-style interface with arrow key navigation.

@onready var title_label: Label = $BorderPanel/TitleLabel
@onready var hull_progress: ProgressBar = $MarginContainer/VBoxContainer/HullProgressBar
@onready var hull_label: Label = $MarginContainer/VBoxContainer/HullProgressBar/HullLabel
@onready var credits_label: RichTextLabel = $MarginContainer/VBoxContainer/CreditsRow/CreditsLabel
@onready var repair_button: RichTextLabel = $MarginContainer/VBoxContainer/RepairRow/RepairButton
@onready var repair_cost_label: RichTextLabel = $MarginContainer/VBoxContainer/RepairRow/RepairCost
@onready var sell_button: RichTextLabel = $MarginContainer/VBoxContainer/SellRow/SellButton
@onready var sell_value_label: RichTextLabel = $MarginContainer/VBoxContainer/SellRow/SellValue
@onready var sell_row: HBoxContainer = $MarginContainer/VBoxContainer/SellRow
@onready var store_button: RichTextLabel = $MarginContainer/VBoxContainer/StoreRow/StoreButton
@onready var close_button: RichTextLabel = $MarginContainer/VBoxContainer/CloseRow/CloseButton

var ship: Ship = null
var spaceport: SpacePort = null
var gs: GameState = null
var economy: Economy = null
var zoom_tween: Tween = null
var _store_ui: StoreUI = null

var _selected_index: int = 0
var _menu_items: Array[Dictionary] = []  # [{button: RichTextLabel, cost_label: RichTextLabel, action: Callable, enabled: bool, label: String, cost_text: String}]

signal dialogue_closed

func _ready() -> void:
	visible = false
	add_to_group("spaceport_dialogue")
	ship = get_tree().get_first_node_in_group("ship") as Ship
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	economy = get_tree().get_first_node_in_group("economy") as Economy

	# Connect click handlers
	if repair_button:
		repair_button.gui_input.connect(_on_item_gui_input.bind(0))
	if sell_button:
		sell_button.gui_input.connect(_on_item_gui_input.bind(1))
	if store_button:
		store_button.gui_input.connect(_on_item_gui_input.bind(2))
	if close_button:
		close_button.gui_input.connect(_on_item_gui_input.bind(3))

	# Connect to signals for updates
	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_update_display)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_move_selection(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_move_selection(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate_selection()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_on_close_pressed()
				get_viewport().set_input_as_handled()

func _move_selection(direction: int) -> void:
	if _menu_items.is_empty():
		return

	var new_index = _selected_index
	var attempts = 0

	# Find next enabled item in direction
	while attempts < _menu_items.size():
		new_index = (new_index + direction + _menu_items.size()) % _menu_items.size()
		if _menu_items[new_index]["enabled"]:
			break
		attempts += 1

	if _menu_items[new_index]["enabled"]:
		_selected_index = new_index
		_update_menu_display()

func _activate_selection() -> void:
	if _selected_index >= 0 and _selected_index < _menu_items.size():
		var item = _menu_items[_selected_index]
		if item["enabled"] and item["action"]:
			item["action"].call()

func _on_item_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index >= 0 and index < _menu_items.size() and _menu_items[index]["enabled"]:
			_selected_index = index
			_activate_selection()

func open_dialogue(target_spaceport: SpacePort) -> void:
	spaceport = target_spaceport
	_selected_index = 0

	visible = true
	_update_display()

func close_dialogue() -> void:
	visible = false
	spaceport = null
	dialogue_closed.emit()

func _update_display() -> void:
	if not ship or not gs or not economy:
		return

	# Update hull display
	var hull = ship.hull_strength
	var max_hull = ship.max_hull
	if hull_progress:
		hull_progress.max_value = max_hull
		hull_progress.value = hull
	if hull_label:
		hull_label.text = "HULL %.0f/%.0f" % [hull, max_hull]

	# Update credits display
	if credits_label:
		credits_label.text = "[color=#ffbf00]CREDITS[/color] %d" % [gs.credits]

	# Calculate costs and build menu items
	var repair_cost = int((max_hull - hull) * Economy.REPAIR_COST_PER_POINT)
	var repair_needed = repair_cost > 0
	var repair_affordable = gs.credits >= repair_cost

	# Build menu items
	_menu_items.clear()
	_menu_items.append({
		"button": repair_button,
		"cost_label": repair_cost_label,
		"action": _on_repair_pressed,
		"enabled": repair_needed and repair_affordable,
		"label": "REPAIR HULL",
		"cost_text": "%d CR" % repair_cost if repair_needed else "FULL",
		"needed": repair_needed,
		"affordable": repair_affordable
	})
	# Sell resources item
	var store = spaceport.get_node_or_null("Store") as Store if spaceport else null
	var sell_value = store.get_sell_value() if store and store.can_sell_resources() else 0
	var can_sell = sell_value > 0
	_menu_items.append({
		"button": sell_button,
		"cost_label": sell_value_label,
		"action": _on_sell_pressed,
		"enabled": can_sell,
		"label": "SELL ALL RESOURCES",
		"cost_text": "+%d CR" % sell_value if can_sell else "+0 CR",
		"needed": can_sell,
		"affordable": true
	})

	# Show/hide sell row based on store support
	if sell_row:
		sell_row.visible = store != null and store.can_sell_resources()

	_menu_items.append({
		"button": store_button,
		"cost_label": null,
		"action": _on_store_pressed,
		"enabled": true,
		"label": "UPGRADES",
		"cost_text": "",
		"needed": true,
		"affordable": true
	})
	_menu_items.append({
		"button": close_button,
		"cost_label": null,
		"action": _on_close_pressed,
		"enabled": true,
		"label": "CLOSE",
		"cost_text": "",
		"needed": true,
		"affordable": true
	})

	# Ensure selected index is on an enabled item
	if _selected_index < _menu_items.size() and not _menu_items[_selected_index]["enabled"]:
		# Find first enabled item
		for i in range(_menu_items.size()):
			if _menu_items[i]["enabled"]:
				_selected_index = i
				break

	_update_menu_display()

func _update_menu_display() -> void:
	for i in range(_menu_items.size()):
		var item = _menu_items[i]
		var button = item["button"] as RichTextLabel
		var cost_label = item["cost_label"] as RichTextLabel
		if not button:
			continue

		var is_selected = (i == _selected_index)
		var is_enabled = item["enabled"]
		var label = item["label"]
		var cost_text = item["cost_text"]
		var needed = item.get("needed", true)
		var affordable = item.get("affordable", true)

		# Update button text
		if is_selected and is_enabled:
			button.text = "[color=#ffbf00]>[/color] %s" % label
		elif is_enabled:
			button.text = "  %s" % label
		elif not needed:
			button.text = "  [color=#5f4700]%s[/color]" % label
		else:
			button.text = "  [color=#5f4700]%s[/color]" % label

		# Update cost label
		if cost_label:
			if not needed:
				cost_label.text = "[right][color=#5f4700]%s[/color]" % cost_text
			elif not affordable:
				cost_label.text = "[right][color=#5f4700]%s[/color]" % cost_text
			else:
				cost_label.text = "[right]%s" % cost_text

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

func _on_sell_pressed() -> void:
	if not spaceport:
		return
	var store = spaceport.get_node_or_null("Store") as Store
	if store and store.can_sell_resources():
		var sell_value = store.get_sell_value()
		if sell_value > 0:
			store.sell_all_resources()
			_update_display()

func _on_store_pressed() -> void:
	if not spaceport:
		return

	# Find the Store component on the spaceport
	var store = spaceport.get_node_or_null("Store")
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
	_selected_index = 0
	_update_display()

func _on_close_pressed() -> void:
	close_dialogue()
