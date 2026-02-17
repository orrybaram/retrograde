extends Control
class_name SpacePortDialogue

## Space Port hub menu - small left-side panel for NPC selection.
## Selecting an NPC opens the combined NPC+Store UI (StoreUI).

var ship: Ship = null
var spaceport: SpacePort = null
var gs: GameState = null

var _selected_index: int = 0
var _menu_items: Array[Dictionary] = []
var _stores: Array[Store] = []
var _store_ui: StoreUI = null

signal dialogue_closed

# Node references (built in _ready)
var _hub_items_container: VBoxContainer = null
var _border_panel: Panel = null
var _title_label: Label = null
var _bg_rect: ColorRect = null

func _ready() -> void:
	visible = false
	add_to_group("spaceport_dialogue")
	ship = get_tree().get_first_node_in_group("ship") as Ship
	gs = get_tree().get_first_node_in_group("game_state") as GameState

	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	# Background
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0, 0, 0, 0.95)
	add_child(_bg_rect)

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
	add_child(_border_panel)

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
	_title_label.text = "/ S P A C E  P O R T /"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_border_panel.add_child(_title_label)

	# Main margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)

	var hub_vbox = VBoxContainer.new()
	hub_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(hub_vbox)

	var hub_header = _make_header("D O C K E D")
	hub_vbox.add_child(hub_header)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	hub_vbox.add_child(spacer)

	_hub_items_container = VBoxContainer.new()
	_hub_items_container.add_theme_constant_override("separation", 4)
	hub_vbox.add_child(_hub_items_container)

func _make_header(text: String) -> Label:
	var label = Label.new()
	label.add_theme_color_override("font_color", Colors.AMBER)
	var indent = StyleBoxEmpty.new()
	indent.content_margin_left = 20.0
	label.add_theme_stylebox_override("normal", indent)
	label.text = text
	return label

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Don't process input while StoreUI is open
	if _store_ui and is_instance_valid(_store_ui) and _store_ui.visible:
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
				close_dialogue()
				get_viewport().set_input_as_handled()

func _move_selection(direction: int) -> void:
	if _menu_items.is_empty():
		return

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

func open_dialogue(target_spaceport: SpacePort) -> void:
	spaceport = target_spaceport
	_gather_stores()
	_selected_index = 0
	_update_hub_display()
	visible = true

func close_dialogue() -> void:
	if _store_ui and is_instance_valid(_store_ui) and _store_ui.visible:
		_store_ui.close_dialogue()
	visible = false
	spaceport = null
	dialogue_closed.emit()

func _gather_stores() -> void:
	_stores.clear()
	if not spaceport:
		return
	for child in spaceport.get_children():
		if child is Store:
			_stores.append(child as Store)

func _clear_container(container: VBoxContainer) -> void:
	while container.get_child_count() > 0:
		var child = container.get_child(0)
		container.remove_child(child)
		child.free()

func _update_hub_display() -> void:
	_menu_items.clear()
	_clear_container(_hub_items_container)

	for i in range(_stores.size()):
		var store = _stores[i]
		_menu_items.append({
			"enabled": true,
			"action": _select_store.bind(store),
			"label": _get_store_label(store),
		})

	_menu_items.append({
		"enabled": true,
		"action": close_dialogue,
		"label": "DEPART",
		"separator_before": true,
	})

	if _selected_index >= _menu_items.size():
		_selected_index = 0

	for i in range(_menu_items.size()):
		if _menu_items[i].get("separator_before", false):
			_hub_items_container.add_child(_make_separator())
		_hub_items_container.add_child(_make_menu_label())

	_update_menu_display()

func _update_menu_display() -> void:
	var labels: Array[RichTextLabel] = []
	for child in _hub_items_container.get_children():
		if child is RichTextLabel:
			labels.append(child as RichTextLabel)
	for i in range(_menu_items.size()):
		if i >= labels.size():
			break
		var rtl = labels[i]

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

func _make_separator() -> Control:
	var sep = Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	return sep

func _get_store_label(store: Store) -> String:
	return store.get_store_name().to_upper()

func _select_store(store: Store) -> void:
	if not _store_ui or not is_instance_valid(_store_ui):
		_store_ui = get_tree().get_first_node_in_group("store_ui") as StoreUI

	if _store_ui:
		if not _store_ui.dialogue_closed.is_connected(_on_store_closed):
			_store_ui.dialogue_closed.connect(_on_store_closed)
		visible = false
		_store_ui.open_dialogue(store)

func _on_store_closed() -> void:
	# Re-show hub menu after store closes
	visible = true
	_selected_index = 0
	_update_hub_display()
