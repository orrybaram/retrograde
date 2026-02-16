extends Control
class_name StoreUI

## Store UI for purchasing upgrades.
## Terminal-style interface with arrow key navigation.
## Shows only the next available tier per upgrade path.

signal dialogue_closed

@onready var title_label: Label = $CenterContainer/StoreWindow/BorderPanel/TitleLabel
@onready var credits_label: Label = $CenterContainer/StoreWindow/BorderPanel/CreditsDecoration
@onready var upgrades_container: VBoxContainer = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/ScrollContainer/UpgradesContainer
@onready var close_button: RichTextLabel = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/CloseRow/CloseButton
@onready var info_panel: RichTextLabel = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/InfoPanel

var store: Store = null
var gs: GameState = null
var _ship: Ship = null

var _menu_items: Array[Dictionary] = []
var _selected_index: int = 0

func _ready() -> void:
	visible = false
	add_to_group("store_ui")
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	_ship = get_tree().get_first_node_in_group("ship") as Ship

	if close_button:
		close_button.gui_input.connect(_on_close_gui_input)

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

	_selected_index = (_selected_index + direction + _menu_items.size()) % _menu_items.size()
	_update_menu_display()

func _activate_selection() -> void:
	if _selected_index >= 0 and _selected_index < _menu_items.size():
		var item = _menu_items[_selected_index]
		if item["purchasable"] and item["action"]:
			item["action"].call()

func _on_close_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close_pressed()

func _format_spaced_title(store_name: String) -> String:
	var spaced = " ".join(store_name.to_upper().split(""))
	return "/ %s /" % spaced

func open_dialogue(target_store: Store) -> void:
	store = target_store
	_ship = get_tree().get_first_node_in_group("ship") as Ship
	visible = true
	_selected_index = 0

	if title_label and store and store.store_data:
		title_label.text = _format_spaced_title(store.store_data.store_name)

	_build_menu_items()
	_update_display()


func close_dialogue() -> void:
	visible = false
	store = null
	_clear_dynamic_rows()
	dialogue_closed.emit()


## Group upgrades by path and return the next unpurchased upgrade per path.
## If all tiers are owned, returns the last upgrade (to show as maxed).
func _get_next_upgrades() -> Array[Dictionary]:
	var paths_seen: Dictionary = {}  # upgrade_path -> true
	var result: Array[Dictionary] = []

	var upgrades = store.get_all_upgrades()
	for upgrade in upgrades:
		var path = upgrade.upgrade_path
		if path in paths_seen:
			continue

		var current_tier = gs.get_upgrade_level(path) if gs else 0
		# Find the next tier for this path
		var next_upgrade: UpgradeItem = null
		var max_tier: int = 0
		for u in upgrades:
			if u.upgrade_path == path:
				max_tier = max(max_tier, u.tier)
				if u.tier == current_tier + 1:
					next_upgrade = u

		var maxed = current_tier >= max_tier
		if maxed:
			# Use last upgrade just for the path name in display
			for u in upgrades:
				if u.upgrade_path == path and u.tier == max_tier:
					next_upgrade = u
					break

		if next_upgrade:
			result.append({"upgrade": next_upgrade, "maxed": maxed})
			paths_seen[path] = true

	return result


func _build_menu_items() -> void:
	_clear_dynamic_rows()
	_menu_items.clear()

	if not store:
		return

	# Add repair row if this store supports repair
	if store.store_data and store.store_data.can_repair:
		_create_repair_row()

	# Add one row per upgrade path (next available tier only)
	var next_upgrades = _get_next_upgrades()
	for entry in next_upgrades:
		_create_upgrade_row(entry["upgrade"], entry["maxed"])

	# Add close item
	_menu_items.append({
		"button": close_button,
		"cost_label": null,
		"action": _on_close_pressed,
		"purchasable": true,
		"label": "CLOSE",
		"cost_text": "",
		"description": "",
		"type": "close"
	})

	if _selected_index >= _menu_items.size():
		_selected_index = 0


func _create_repair_row() -> void:
	var row = HBoxContainer.new()
	row.name = "RepairRow"

	var button = RichTextLabel.new()
	button.bbcode_enabled = true
	button.fit_content = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("default_color", Color(1, 0.75, 0, 1))

	var style = StyleBoxEmpty.new()
	style.content_margin_left = 20.0
	button.add_theme_stylebox_override("normal", style)

	var item_index = _menu_items.size()
	button.gui_input.connect(_on_row_gui_input.bind(item_index))

	var cost_label = RichTextLabel.new()
	cost_label.bbcode_enabled = true
	cost_label.fit_content = true
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.add_theme_color_override("default_color", Color(0.75, 0.56, 0, 1))

	row.add_child(button)
	row.add_child(cost_label)
	upgrades_container.add_child(row)

	_menu_items.append({
		"button": button,
		"cost_label": cost_label,
		"action": _on_repair_pressed,
		"purchasable": true,
		"label": "REPAIR HULL",
		"cost_text": "0 CR",
		"description": "Patch the holes, seal the cracks. Good as new... mostly.",
		"type": "repair",
		"container": row
	})


func _create_upgrade_row(upgrade: UpgradeItem, maxed: bool) -> void:
	var row = HBoxContainer.new()
	row.name = "Upgrade_" + upgrade.upgrade_id

	var button = RichTextLabel.new()
	button.bbcode_enabled = true
	button.fit_content = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_color_override("default_color", Color(1, 0.75, 0, 1))

	var style = StyleBoxEmpty.new()
	style.content_margin_left = 20.0
	button.add_theme_stylebox_override("normal", style)

	var item_index = _menu_items.size()
	button.gui_input.connect(_on_row_gui_input.bind(item_index))

	var cost_label = RichTextLabel.new()
	cost_label.bbcode_enabled = true
	cost_label.fit_content = true
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.add_theme_color_override("default_color", Color(0.75, 0.56, 0, 1))

	row.add_child(button)
	row.add_child(cost_label)
	upgrades_container.add_child(row)

	_menu_items.append({
		"button": button,
		"cost_label": cost_label,
		"action": _on_upgrade_pressed.bind(upgrade),
		"purchasable": not maxed,
		"label": upgrade.display_name.to_upper(),
		"cost_text": "MAX" if maxed else "%d CR" % upgrade.cost,
		"description": upgrade.description,
		"type": "upgrade",
		"upgrade": upgrade,
		"container": row
	})


func _on_row_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index >= 0 and index < _menu_items.size():
			_selected_index = index
			if _menu_items[index]["purchasable"]:
				_activate_selection()
			else:
				_update_menu_display()

func _clear_dynamic_rows() -> void:
	for item in _menu_items:
		if item.get("type") in ["upgrade", "repair"]:
			var container = item.get("container")
			if container and is_instance_valid(container):
				container.queue_free()

func _update_display() -> void:
	if not store or not gs:
		return

	if credits_label:
		credits_label.text = "[ CR: %d ]" % gs.credits

	# Update repair item state
	for item in _menu_items:
		if item.get("type") == "repair":
			if _ship and is_instance_valid(_ship):
				var hull = _ship.hull_strength
				var max_hull = _ship.max_hull
				var repair_cost = int((max_hull - hull) * Economy.REPAIR_COST_PER_POINT)
				var repair_needed = repair_cost > 0
				var repair_affordable = gs.credits >= repair_cost

				if not repair_needed:
					item["purchasable"] = false
					item["cost_text"] = "FULL"
				elif repair_affordable:
					item["purchasable"] = true
					item["cost_text"] = "%d CR" % repair_cost
				else:
					item["purchasable"] = false
					item["cost_text"] = "%d CR" % repair_cost

	# Update upgrade items
	for item in _menu_items:
		if item.get("type") == "upgrade":
			var upgrade = item.get("upgrade") as UpgradeItem
			if upgrade:
				var current_tier = gs.get_upgrade_level(upgrade.upgrade_path)
				var maxed = current_tier >= upgrade.tier

				if maxed:
					item["purchasable"] = false
					item["cost_text"] = "MAX"
				elif store.can_purchase(upgrade):
					item["purchasable"] = true
					item["cost_text"] = "%d CR" % upgrade.cost
				else:
					item["purchasable"] = false
					item["cost_text"] = "%d CR" % upgrade.cost

	_update_menu_display()

func _update_menu_display() -> void:
	for i in range(_menu_items.size()):
		var item = _menu_items[i]
		var button = item["button"] as RichTextLabel
		var cost_label = item["cost_label"] as RichTextLabel
		if not button:
			continue

		var is_selected = (i == _selected_index)
		var is_purchasable = item["purchasable"]
		var label = item["label"]
		var cost_text = item.get("cost_text", "")

		if is_selected:
			if is_purchasable:
				button.text = "[color=#ffbf00]>[/color] %s" % label
			else:
				button.text = "[color=#ffbf00]>[/color] [color=#5f4700]%s[/color]" % label
		elif is_purchasable:
			button.text = "  %s" % label
		else:
			button.text = "  [color=#5f4700]%s[/color]" % label

		# Update cost label
		if cost_label:
			if is_purchasable:
				cost_label.text = "[right]%s" % cost_text
			elif cost_text == "MAX" or cost_text == "FULL":
				cost_label.text = "[right][color=#5f4700]%s[/color]" % cost_text
			else:
				cost_label.text = "[right][color=#aa0000]%s[/color]" % cost_text

	# Update info panel with selected item description
	_update_info_panel()

func _update_info_panel() -> void:
	if not info_panel:
		return

	if _selected_index >= 0 and _selected_index < _menu_items.size():
		var item = _menu_items[_selected_index]
		var desc = item.get("description", "")
		if desc != "":
			info_panel.text = desc
		else:
			info_panel.text = ""
	else:
		info_panel.text = ""

func _on_repair_pressed() -> void:
	if not _ship or not is_instance_valid(_ship) or not gs:
		return

	var max_hull = _ship.max_hull
	var hull = _ship.hull_strength
	var repair_cost = int((max_hull - hull) * Economy.REPAIR_COST_PER_POINT)

	if repair_cost > 0 and gs.credits >= repair_cost:
		gs.credits -= repair_cost
		_ship.hull_strength = max_hull
		_update_display()

func _on_upgrade_pressed(upgrade: UpgradeItem) -> void:
	if store:
		var success = await store.purchase_upgrade(upgrade)
		if success:
			_build_menu_items()
			_update_display()

func _on_close_pressed() -> void:
	close_dialogue()

func _on_upgrade_level_changed(_path: String, _level: int) -> void:
	_build_menu_items()
	_update_display()
