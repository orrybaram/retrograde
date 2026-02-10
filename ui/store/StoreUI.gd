extends Control
class_name StoreUI

## Store UI for purchasing upgrades and selling resources.
## Terminal-style interface with arrow key navigation.

signal dialogue_closed

@onready var title_label: Label = $CenterContainer/StoreWindow/BorderPanel/TitleLabel
@onready var credits_label: Label = $CenterContainer/StoreWindow/BorderPanel/CreditsDecoration
@onready var upgrades_container: VBoxContainer = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/ScrollContainer/UpgradesContainer
@onready var sell_button: RichTextLabel = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/SellRow/SellButton
@onready var sell_value_label: RichTextLabel = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/SellRow/SellValue
@onready var sell_row: HBoxContainer = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/SellRow
@onready var close_button: RichTextLabel = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/CloseRow/CloseButton

var store: Store = null
var gs: GameState = null

var _menu_items: Array[Dictionary] = []  # [{button: RichTextLabel, cost_label: RichTextLabel, action: Callable, enabled: bool, label: String, cost_text: String, type: String}]
var _selected_index: int = 0

func _ready() -> void:
	visible = false
	add_to_group("store_ui")
	gs = get_tree().get_first_node_in_group("game_state") as GameState

	# Connect click handlers for static elements
	if sell_button:
		sell_button.gui_input.connect(_on_sell_gui_input)
	if close_button:
		close_button.gui_input.connect(_on_close_gui_input)

	# Connect to credits changed signal for live updates
	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_update_display)
	if gs and gs.has_signal("upgrade_level_changed"):
		gs.upgrade_level_changed.connect(_on_upgrade_level_changed)

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

func _on_sell_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Find sell item index and activate
		for i in range(_menu_items.size()):
			if _menu_items[i].get("type") == "sell" and _menu_items[i]["enabled"]:
				_selected_index = i
				_activate_selection()
				break

func _on_close_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()

func open_dialogue(target_store: Store) -> void:
	store = target_store
	visible = true
	_selected_index = 0
	_build_menu_items()
	_update_display()


func close_dialogue() -> void:
	visible = false
	store = null
	_clear_upgrade_rows()

	dialogue_closed.emit()


func _build_menu_items() -> void:
	_clear_upgrade_rows()
	_menu_items.clear()

	if not store:
		return

	# Add upgrade items
	var upgrades = store.get_all_upgrades()
	for i in range(upgrades.size()):
		var upgrade = upgrades[i]
		_create_upgrade_row(upgrade, i)

	# Add sell item (if store supports selling)
	if store.can_sell_resources():
		_menu_items.append({
			"button": sell_button,
			"cost_label": sell_value_label,
			"action": _on_sell_pressed,
			"enabled": true,
			"label": "SELL ALL RESOURCES",
			"cost_text": "+0 CR",
			"type": "sell"
		})

	# Add close item
	_menu_items.append({
		"button": close_button,
		"cost_label": null,
		"action": _on_close_pressed,
		"enabled": true,
		"label": "CLOSE",
		"cost_text": "",
		"type": "close"
	})

	# Ensure selected index is valid
	if _selected_index >= _menu_items.size():
		_selected_index = 0


func _create_upgrade_row(upgrade: UpgradeItem, index: int) -> void:
	# Create HBoxContainer for the row
	var row = HBoxContainer.new()
	row.name = "Upgrade_" + upgrade.upgrade_id

	# Create left side (button)
	var button = RichTextLabel.new()
	button.bbcode_enabled = true
	button.fit_content = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("default_color", Color(1, 0.75, 0, 1))

	# Add left margin style
	var style = StyleBoxEmpty.new()
	style.content_margin_left = 20.0
	button.add_theme_stylebox_override("normal", style)

	# Connect click handler
	var item_index = _menu_items.size()  # Index will be assigned when added
	button.gui_input.connect(_on_upgrade_row_gui_input.bind(item_index))

	# Create right side (cost)
	var cost_label = RichTextLabel.new()
	cost_label.bbcode_enabled = true
	cost_label.fit_content = true
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.add_theme_color_override("default_color", Color(0.75, 0.56, 0, 1))

	row.add_child(button)
	row.add_child(cost_label)
	upgrades_container.add_child(row)

	# Add to menu items
	_menu_items.append({
		"button": button,
		"cost_label": cost_label,
		"action": _on_upgrade_pressed.bind(upgrade),
		"enabled": true,
		"label": upgrade.display_name,
		"cost_text": "%d CR" % upgrade.cost,
		"type": "upgrade",
		"upgrade": upgrade,
		"container": row
	})

func _on_upgrade_row_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index >= 0 and index < _menu_items.size() and _menu_items[index]["enabled"]:
			_selected_index = index
			_activate_selection()

func _clear_upgrade_rows() -> void:
	for item in _menu_items:
		if item.get("type") == "upgrade":
			var container = item.get("container")
			if container and is_instance_valid(container):
				container.queue_free()

func _update_display() -> void:
	if not store or not gs:
		return

	# Update credits decoration
	if credits_label:
		credits_label.text = "[ CR: %d ]" % gs.credits

	# Update upgrade items enabled state
	for item in _menu_items:
		if item.get("type") == "upgrade":
			var upgrade = item.get("upgrade") as UpgradeItem
			if upgrade:
				var can_buy = store.can_purchase(upgrade)
				var current_tier = gs.get_upgrade_level(upgrade.upgrade_path)
				var already_owned = current_tier >= upgrade.tier

				if already_owned:
					item["enabled"] = false
					item["cost_text"] = "OWNED"
				elif can_buy:
					item["enabled"] = true
					item["cost_text"] = "%d CR" % upgrade.cost
				else:
					item["enabled"] = false
					item["cost_text"] = "%d CR" % upgrade.cost

	# Update sell item
	for item in _menu_items:
		if item.get("type") == "sell":
			var sell_value = store.get_sell_value()
			if sell_value > 0:
				item["enabled"] = true
				item["cost_text"] = "+%d CR" % sell_value
			else:
				item["enabled"] = false
				item["cost_text"] = "+0 CR"

	# Ensure selected index is on an enabled item
	if _selected_index < _menu_items.size() and not _menu_items[_selected_index]["enabled"]:
		# Find first enabled item
		for i in range(_menu_items.size()):
			if _menu_items[i]["enabled"]:
				_selected_index = i
				break

	# Update sell row visibility
	if sell_row:
		sell_row.visible = store.can_sell_resources()

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
		var cost_text = item.get("cost_text", "")

		# Update button text
		if is_selected and is_enabled:
			button.text = "[color=#ffbf00]>[/color] %s" % label
		elif is_enabled:
			button.text = "  %s" % label
		else:
			button.text = "  [color=#5f4700]%s[/color]" % label

		# Update cost label
		if cost_label:
			if is_enabled:
				cost_label.text = "[right]%s" % cost_text
			else:
				cost_label.text = "[right][color=#5f4700]%s[/color]" % cost_text

func _on_upgrade_pressed(upgrade: UpgradeItem) -> void:
	if store:
		var success = await store.purchase_upgrade(upgrade)
		if success:
			_update_display()

func _on_sell_pressed() -> void:
	if store and store.can_sell_resources():
		var sell_value = store.get_sell_value()
		if sell_value > 0:
			store.sell_all_resources()
			_update_display()

func _on_close_pressed() -> void:
	close_dialogue()

func _on_upgrade_level_changed(_path: String, _level: int) -> void:
	_update_display()
