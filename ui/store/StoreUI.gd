extends Control
class_name StoreUI

## Combined NPC character interaction + store UI.
## Modes: Character (greeting + BUY/TALK/EXIT), Talk (topics), Buy (store items).
## Always shows NPC ASCII art at top.

enum Mode { CHARACTER, TALK, BUY, SELL }

signal dialogue_closed

var store: Store = null
var gs: GameState = null
var _ship: Ship = null

var _mode: Mode = Mode.CHARACTER
var _menu_items: Array[Dictionary] = []
var _selected_index: int = 0

# Scene node
@onready var _store_window: Control = $StoreWindow

# Built nodes
var _bg_rect: ColorRect = null
var _border_panel: Panel = null
var _title_label: Label = null
var _credits_label: Label = null
var _ascii_label: RichTextLabel = null
var _dialogue_label: RichTextLabel = null
var _store_items_container: VBoxContainer = null
var _menu_container: VBoxContainer = null
var _buy_info_label: RichTextLabel = null
var _typewriter: Typewriter = null
var _flavor_typewriter: Typewriter = null

func _ready() -> void:
	visible = false
	add_to_group("store_ui")
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	_ship = get_tree().get_first_node_in_group("ship") as Ship

	_build_ui()

	_typewriter = Typewriter.new()
	_typewriter.setup(_dialogue_label)
	add_child(_typewriter)

	_flavor_typewriter = Typewriter.new()
	_flavor_typewriter.setup(_buy_info_label)
	add_child(_flavor_typewriter)

	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_on_credits_changed)
	if gs and gs.has_signal("upgrade_level_changed"):
		gs.upgrade_level_changed.connect(_on_upgrade_level_changed)

func _build_ui() -> void:
	# Background
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0, 0, 0, 0.98)
	_store_window.add_child(_bg_rect)

	# Border panel
	_border_panel = Panel.new()
	_border_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var border_style = StyleBoxFlat.new()
	border_style.draw_center = false
	border_style.border_width_left = 2
	border_style.border_width_top = 2
	border_style.border_width_right = 2
	border_style.border_width_bottom = 2
	border_style.border_color = Colors.AMBER
	_border_panel.add_theme_stylebox_override("panel", border_style)
	_store_window.add_child(_border_panel)

	# Title label (top-right corner)
	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_title_label.offset_left = -180.0
	_title_label.offset_top = -10.0
	_title_label.offset_right = -15.0
	_title_label.offset_bottom = 13.0
	_title_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_title_label.add_theme_color_override("font_color", Colors.AMBER)
	var title_bg = StyleBoxFlat.new()
	title_bg.bg_color = Color(0, 0, 0, 1)
	_title_label.add_theme_stylebox_override("normal", title_bg)
	_title_label.text = "/ S T O R E /"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_border_panel.add_child(_title_label)

	# Credits label (top-left corner)
	_credits_label = Label.new()
	_credits_label.offset_left = 15.0
	_credits_label.offset_top = -10.0
	_credits_label.offset_right = 100.0
	_credits_label.offset_bottom = 13.0
	_credits_label.add_theme_color_override("font_color", Colors.AMBER)
	var credits_bg = StyleBoxFlat.new()
	credits_bg.bg_color = Color(0, 0, 0, 1)
	_credits_label.add_theme_stylebox_override("normal", credits_bg)
	_credits_label.text = "[ CR: 0 ]"
	_border_panel.add_child(_credits_label)

	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	_store_window.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(main_vbox)

	# ASCII art area (top portion)
	_ascii_label = RichTextLabel.new()
	_ascii_label.bbcode_enabled = true
	_ascii_label.fit_content = false
	_ascii_label.scroll_active = false
	_ascii_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ascii_label.size_flags_stretch_ratio = 0.4
	_ascii_label.add_theme_color_override("default_color", Colors.AMBER)
	main_vbox.add_child(_ascii_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Colors.AMBER)
	sep.add_theme_constant_override("separation", 4)
	main_vbox.add_child(sep)

	# Bottom half: left panel + right panel
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_hbox.size_flags_stretch_ratio = 0.6
	bottom_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(bottom_hbox)

	# Left panel: dialogue text OR store items
	var left_panel = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.6
	var left_style = StyleBoxFlat.new()
	left_style.draw_center = false
	left_style.border_width_left = 1
	left_style.border_width_top = 1
	left_style.border_width_right = 1
	left_style.border_width_bottom = 1
	left_style.border_color = Colors.AMBER
	left_style.content_margin_left = 8
	left_style.content_margin_top = 8
	left_style.content_margin_right = 8
	left_style.content_margin_bottom = 8
	left_panel.add_theme_stylebox_override("panel", left_style)
	bottom_hbox.add_child(left_panel)

	_dialogue_label = RichTextLabel.new()
	_dialogue_label.bbcode_enabled = true
	_dialogue_label.fit_content = false
	_dialogue_label.scroll_active = false
	_dialogue_label.add_theme_color_override("default_color", Colors.AMBER)
	left_panel.add_child(_dialogue_label)

	_store_items_container = VBoxContainer.new()
	_store_items_container.add_theme_constant_override("separation", 2)
	_store_items_container.visible = false
	left_panel.add_child(_store_items_container)

	# Right panel: menu OR buy info
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.4
	var right_style = StyleBoxFlat.new()
	right_style.draw_center = false
	right_style.border_width_left = 1
	right_style.border_width_top = 1
	right_style.border_width_right = 1
	right_style.border_width_bottom = 1
	right_style.border_color = Colors.AMBER
	right_style.content_margin_left = 8
	right_style.content_margin_top = 8
	right_style.content_margin_right = 8
	right_style.content_margin_bottom = 8
	right_panel.add_theme_stylebox_override("panel", right_style)
	bottom_hbox.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 4)
	right_panel.add_child(right_vbox)

	_menu_container = VBoxContainer.new()
	_menu_container.add_theme_constant_override("separation", 2)
	_menu_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(_menu_container)

	_buy_info_label = RichTextLabel.new()
	_buy_info_label.bbcode_enabled = true
	_buy_info_label.fit_content = false
	_buy_info_label.scroll_active = false
	_buy_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buy_info_label.add_theme_color_override("default_color", Colors.AMBER)
	_buy_info_label.visible = false
	right_vbox.add_child(_buy_info_label)

func _format_spaced_title(text: String) -> String:
	var spaced = " ".join(text.to_upper().split(""))
	return "/ %s /" % spaced

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
				_on_escape()
				get_viewport().set_input_as_handled()

func _move_selection(direction: int) -> void:
	if _menu_items.is_empty():
		return

	if _mode == Mode.BUY or _mode == Mode.SELL:
		# Allow selecting disabled items to view descriptions
		_selected_index = (_selected_index + direction + _menu_items.size()) % _menu_items.size()
	else:
		var new_index = _selected_index
		var attempts = 0
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

func _on_escape() -> void:
	match _mode:
		Mode.CHARACTER:
			close_dialogue()
		Mode.TALK:
			_switch_to_character()
		Mode.BUY:
			_switch_to_character()
		Mode.SELL:
			_switch_to_character()

func open_dialogue(target_store: Store) -> void:
	store = target_store
	_ship = get_tree().get_first_node_in_group("ship") as Ship
	_selected_index = 0
	visible = true

	# Set title from store name
	if _title_label and store and store.store_data:
		_title_label.text = _format_spaced_title(store.store_data.store_name)

	# Show NPC ASCII art
	_update_ascii_art()

	_switch_to_character()

func close_dialogue() -> void:
	visible = false
	store = null
	dialogue_closed.emit()

func _get_npc() -> NPCData:
	if store and store.store_data and store.store_data.npc_data:
		return store.store_data.npc_data
	return null

func _update_ascii_art() -> void:
	var npc = _get_npc()
	if _ascii_label and npc:
		_ascii_label.text = "[color=#ffbf00]%s[/color]" % npc.ascii_art
	elif _ascii_label:
		_ascii_label.text = ""

func _update_credits() -> void:
	if _credits_label and gs:
		_credits_label.text = "[ CR: %d ]" % gs.credits

func _switch_to_character() -> void:
	_mode = Mode.CHARACTER
	_selected_index = 0
	_dialogue_label.visible = true
	_store_items_container.visible = false
	_menu_container.visible = true
	_buy_info_label.visible = false
	_update_character_display()

func _switch_to_talk() -> void:
	_mode = Mode.TALK
	_selected_index = 0
	_dialogue_label.visible = true
	_store_items_container.visible = false
	_menu_container.visible = true
	_buy_info_label.visible = false
	_update_talk_display()

func _switch_to_buy() -> void:
	_mode = Mode.BUY
	_selected_index = 0
	_dialogue_label.visible = false
	_store_items_container.visible = true
	_menu_container.visible = false
	_buy_info_label.visible = true
	_update_buy_display()

func _clear_container(container) -> void:
	while container.get_child_count() > 0:
		var child = container.get_child(0)
		container.remove_child(child)
		child.free()

func _update_character_display() -> void:
	_menu_items.clear()
	_update_credits()

	var npc = _get_npc()

	if _dialogue_label and npc:
		_typewriter.type_text("[color=#ffbf00]%s[/color]" % npc.greeting)
	elif _dialogue_label:
		_typewriter.show_immediate("")

	_menu_items.append({
		"enabled": true,
		"action": _switch_to_buy,
		"label": "BUY",
	})

	if store and store.can_sell_resources():
		var inventory_manager = get_node_or_null("/root/InventoryManager") as InventoryManager
		var has_items = inventory_manager and not inventory_manager.get_all_items().is_empty()
		_menu_items.append({
			"enabled": has_items,
			"action": _switch_to_sell,
			"label": "SELL",
		})

	_menu_items.append({
		"enabled": npc != null and npc.talk_topics.size() > 0,
		"action": _switch_to_talk,
		"label": "TALK",
	})

	_menu_items.append({
		"enabled": true,
		"action": close_dialogue,
		"label": "EXIT",
	})

	_clear_container(_menu_container)
	for i in range(_menu_items.size()):
		_menu_container.add_child(_make_menu_label())

	_update_menu_display()

func _update_talk_display() -> void:
	_menu_items.clear()
	_update_credits()

	var npc = _get_npc()
	if not npc:
		_switch_to_character()
		return

	for topic in npc.talk_topics:
		_menu_items.append({
			"enabled": true,
			"action": _on_topic_selected.bind(topic),
			"label": topic,
		})

	_menu_items.append({
		"enabled": true,
		"action": _switch_to_character,
		"label": "BACK",
	})

	_clear_container(_menu_container)
	for i in range(_menu_items.size()):
		_menu_container.add_child(_make_menu_label())

	_update_menu_display()

func _update_buy_display() -> void:
	if not store:
		return

	_menu_items.clear()
	_clear_container(_store_items_container)
	_update_credits()

	# Add repair row if supported
	if store.store_data and store.store_data.can_repair:
		_add_buy_repair_item()

	# Add upgrade rows (next tier per path)
	var next_upgrades = _get_next_upgrades()
	for entry in next_upgrades:
		_add_buy_upgrade_item(entry["upgrade"], entry["maxed"])

	# Add BACK
	_menu_items.append({
		"enabled": true,
		"action": _switch_to_character,
		"label": "BACK",
		"cost_text": "",
		"description": "",
	})
	_store_items_container.add_child(_make_buy_row())

	if _selected_index >= _menu_items.size():
		_selected_index = 0

	_update_menu_display()

func _get_next_upgrades() -> Array[Dictionary]:
	var paths_seen: Dictionary = {}
	var result: Array[Dictionary] = []
	var upgrades = store.get_all_upgrades()

	for upgrade in upgrades:
		var path = upgrade.upgrade_path
		if path in paths_seen:
			continue

		var current_tier = gs.get_upgrade_level(path) if gs else 0
		var next_upgrade: UpgradeItem = null
		var max_tier: int = 0

		for u in upgrades:
			if u.upgrade_path == path:
				max_tier = max(max_tier, u.tier)
				if u.tier == current_tier + 1:
					next_upgrade = u

		var maxed = current_tier >= max_tier
		if maxed:
			for u in upgrades:
				if u.upgrade_path == path and u.tier == max_tier:
					next_upgrade = u
					break

		if next_upgrade:
			result.append({"upgrade": next_upgrade, "maxed": maxed})
			paths_seen[path] = true

	return result

func _add_buy_repair_item() -> void:
	var repair_cost = 0
	var repair_needed = false
	var repair_affordable = false

	if _ship and is_instance_valid(_ship) and gs:
		var hull = _ship.hull_strength
		var max_hull = _ship.max_hull
		repair_cost = int((max_hull - hull) * Economy.REPAIR_COST_PER_POINT)
		repair_needed = repair_cost > 0
		repair_affordable = gs.credits >= repair_cost

	var cost_text: String
	var enabled: bool
	if not repair_needed:
		cost_text = "FULL"
		enabled = false
	elif repair_affordable:
		cost_text = "%d CR" % repair_cost
		enabled = true
	else:
		cost_text = "%d CR" % repair_cost
		enabled = false

	_menu_items.append({
		"enabled": enabled,
		"action": _on_repair_pressed,
		"label": "REPAIR HULL",
		"cost_text": cost_text,
		"description": "Patch the holes, seal the cracks. Good as new... mostly.",
	})
	_store_items_container.add_child(_make_buy_row())

func _add_buy_upgrade_item(upgrade: UpgradeItem, maxed: bool) -> void:
	var cost_text: String
	var enabled: bool

	if maxed:
		cost_text = "MAX"
		enabled = false
	elif store.can_purchase(upgrade):
		cost_text = "%d CR" % upgrade.cost
		enabled = true
	else:
		cost_text = "%d CR" % upgrade.cost
		enabled = false

	_menu_items.append({
		"enabled": enabled,
		"action": _on_upgrade_pressed.bind(upgrade),
		"label": upgrade.display_name.to_upper(),
		"cost_text": cost_text,
		"description": upgrade.description,
	})
	_store_items_container.add_child(_make_buy_row())

func _make_buy_row() -> HBoxContainer:
	var row = HBoxContainer.new()

	var name_label = RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.scroll_active = false
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("default_color", Colors.AMBER)
	var indent = StyleBoxEmpty.new()
	indent.content_margin_left = 8.0
	name_label.add_theme_stylebox_override("normal", indent)
	row.add_child(name_label)

	var cost_label = RichTextLabel.new()
	cost_label.bbcode_enabled = true
	cost_label.fit_content = true
	cost_label.scroll_active = false
	cost_label.custom_minimum_size = Vector2(80, 0)
	cost_label.add_theme_color_override("default_color", Colors.AMBER)
	row.add_child(cost_label)

	return row

func _update_menu_display() -> void:
	if _mode == Mode.BUY or _mode == Mode.SELL:
		_update_buy_menu_display()
		return

	var labels = _menu_container.get_children()
	for i in range(_menu_items.size()):
		if i >= labels.size():
			break
		var rtl = labels[i] as RichTextLabel
		if not rtl:
			continue

		var item = _menu_items[i]
		var is_selected = (i == _selected_index)
		var is_enabled = item["enabled"]
		var label_text = item["label"]

		if is_selected and is_enabled:
			rtl.text = "[color=#ffbf00]>[/color] %s" % label_text
		elif is_enabled:
			rtl.text = "  %s" % label_text
		else:
			rtl.text = "  [color=#5f4700]%s[/color]" % label_text

func _update_buy_menu_display() -> void:
	var children = _store_items_container.get_children()
	for i in range(_menu_items.size()):
		if i >= children.size():
			break

		var item = _menu_items[i]
		var is_selected = (i == _selected_index)
		var is_enabled = item["enabled"]
		var label_text = item["label"]
		var cost_text = item.get("cost_text", "")

		var row = children[i]
		if row.get_child_count() < 1:
			continue

		var name_label = row.get_child(0) as RichTextLabel
		var cost_label = row.get_child(1) as RichTextLabel if row.get_child_count() > 1 else null

		if name_label:
			if is_selected and is_enabled:
				name_label.text = "[color=#ffbf00]>[/color] %s" % label_text
			elif is_selected:
				name_label.text = "[color=#ffbf00]>[/color] [color=#5f4700]%s[/color]" % label_text
			elif is_enabled:
				name_label.text = "  %s" % label_text
			else:
				name_label.text = "  [color=#5f4700]%s[/color]" % label_text

		if cost_label:
			if cost_text == "":
				cost_label.text = ""
			elif is_enabled:
				cost_label.text = "[right]%s" % cost_text
			elif cost_text == "MAX" or cost_text == "FULL":
				cost_label.text = "[right][color=#5f4700]%s[/color]" % cost_text
			else:
				cost_label.text = "[right][color=#aa0000]%s[/color]" % cost_text

	# Update info panel with selected item description
	if _buy_info_label:
		if _selected_index >= 0 and _selected_index < _menu_items.size():
			var desc = _menu_items[_selected_index].get("description", "")
			if desc != "":
				_flavor_typewriter.type_text("[color=#ffbf00]%s[/color]" % desc)
			else:
				_flavor_typewriter.show_immediate("")
		else:
			_flavor_typewriter.show_immediate("")

func _switch_to_sell() -> void:
	_mode = Mode.SELL
	_selected_index = 0
	_dialogue_label.visible = false
	_store_items_container.visible = true
	_menu_container.visible = false
	_buy_info_label.visible = true
	_update_sell_display()

func _update_sell_display() -> void:
	if not store:
		return

	_menu_items.clear()
	_clear_container(_store_items_container)
	_update_credits()

	var inventory_manager = get_node_or_null("/root/InventoryManager") as InventoryManager
	if not inventory_manager:
		_switch_to_character()
		return

	var all_items = inventory_manager.get_all_items()
	if all_items.is_empty():
		_switch_to_character()
		return

	# Add a row for each resource in inventory
	for item_id in all_items.keys():
		var quantity = all_items[item_id] as int
		if quantity <= 0:
			continue
		var unit_price = Economy.get_resource_price(item_id)
		var display_name = TierData.get_display_name_for_item_id(item_id).to_upper()
		var total_value = quantity * unit_price

		_menu_items.append({
			"enabled": true,
			"action": _on_sell_one_pressed.bind(item_id),
			"label": "%s x%d" % [display_name, quantity],
			"cost_text": "%d CR" % unit_price,
			"description": "%d x %d CR = %d CR" % [quantity, unit_price, total_value],
		})
		_store_items_container.add_child(_make_buy_row())

	# SELL ALL row
	var sell_all_value = store.get_sell_value()
	_menu_items.append({
		"enabled": true,
		"action": _on_sell_all_pressed,
		"label": "SELL ALL",
		"cost_text": "%d CR" % sell_all_value,
		"description": "Sell entire cargo for %d CR" % sell_all_value,
	})
	_store_items_container.add_child(_make_buy_row())

	# BACK row
	_menu_items.append({
		"enabled": true,
		"action": _switch_to_character,
		"label": "BACK",
		"cost_text": "",
		"description": "",
	})
	_store_items_container.add_child(_make_buy_row())

	if _selected_index >= _menu_items.size():
		_selected_index = 0

	_update_menu_display()

func _on_sell_one_pressed(item_id: String) -> void:
	if store:
		store.sell_resource(item_id, 1)
		_update_sell_display()

func _on_sell_all_pressed() -> void:
	if store:
		store.sell_all_resources()
		# sell_all clears inventory, so return to character
		_switch_to_character()

func _make_menu_label() -> RichTextLabel:
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_color_override("default_color", Colors.AMBER)
	var indent = StyleBoxEmpty.new()
	indent.content_margin_left = 20.0
	rtl.add_theme_stylebox_override("normal", indent)
	return rtl

func _on_topic_selected(topic: String) -> void:
	if _dialogue_label:
		_typewriter.type_text("[color=#ffbf00]* ...%s, you ask?\n* Hmm, that's a good question.\n* Maybe another time.[/color]" % topic)

func _on_repair_pressed() -> void:
	if not _ship or not is_instance_valid(_ship) or not gs:
		return

	var max_hull = _ship.max_hull
	var hull = _ship.hull_strength
	var repair_cost = int((max_hull - hull) * Economy.REPAIR_COST_PER_POINT)

	if repair_cost > 0 and gs.credits >= repair_cost:
		gs.credits -= repair_cost
		_ship.hull_strength = max_hull
		_update_buy_display()

func _on_upgrade_pressed(upgrade: UpgradeItem) -> void:
	if store:
		var success = await store.purchase_upgrade(upgrade)
		if success:
			_update_buy_display()

func _on_credits_changed() -> void:
	if visible:
		_update_credits()

func _on_upgrade_level_changed(_path: String, _level: int) -> void:
	if visible and _mode == Mode.BUY:
		_update_buy_display()
