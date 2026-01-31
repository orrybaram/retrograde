extends Control
class_name PauseMenu

## Pause menu with terminal-style interface and arrow key navigation.

signal resumed
signal quit_to_menu

@onready var resume_button: RichTextLabel = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ResumeRow/ResumeButton
@onready var quit_button: RichTextLabel = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/QuitRow/QuitButton

var _selected_index: int = 0
var _menu_items: Array[Dictionary] = []
var _pause_start_time: float = 0.0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")

	if resume_button:
		resume_button.gui_input.connect(_on_item_gui_input.bind(0))
	if quit_button:
		quit_button.gui_input.connect(_on_item_gui_input.bind(1))

	_build_menu_items()

func _input(event: InputEvent) -> void:
	# Handle escape to toggle pause
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_resume_pressed()
		else:
			_show_pause_menu()
		get_viewport().set_input_as_handled()
		return

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

func _show_pause_menu() -> void:
	# Don't pause if we're on the start menu
	var start_menu = get_tree().get_first_node_in_group("start_menu") as StartMenu
	if start_menu and start_menu.visible:
		return

	# Don't pause if game over menu is showing
	var game_over = get_tree().get_first_node_in_group("game_over_menu") as GameOverMenu
	if game_over and game_over.visible:
		return

	# Don't pause if another dialogue is open
	var spaceport = get_tree().get_first_node_in_group("spaceport_dialogue") as SpacePortDialogue
	if spaceport and spaceport.visible:
		return
	var store = get_tree().get_first_node_in_group("store_ui") as StoreUI
	if store and store.visible:
		return
	var system_map = get_tree().get_first_node_in_group("system_map") as SystemMap
	if system_map and system_map.visible:
		return
	var inventory = get_tree().get_first_node_in_group("inventory_ui") as InventoryUI
	if inventory and inventory.visible:
		return

	visible = true
	get_tree().paused = true
	_pause_start_time = Time.get_ticks_msec() / 1000.0
	_selected_index = 0
	_update_menu_display()

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

func _on_item_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index >= 0 and index < _menu_items.size() and _menu_items[index]["enabled"]:
			_selected_index = index
			_activate_selection()

func _build_menu_items() -> void:
	_menu_items.clear()
	_menu_items.append({"button": resume_button, "action": _on_resume_pressed, "enabled": true, "label": "RESUME"})
	_menu_items.append({"button": quit_button, "action": _on_quit_pressed, "enabled": true, "label": "QUIT TO MENU"})

func _update_menu_display() -> void:
	for i in range(_menu_items.size()):
		var item = _menu_items[i]
		var button = item["button"] as RichTextLabel
		if not button:
			continue

		var is_selected = (i == _selected_index)
		var is_enabled = item["enabled"]
		var label = item["label"]

		if is_selected and is_enabled:
			button.text = "[color=#ffbf00]>[/color] %s" % label
		elif is_enabled:
			button.text = "  %s" % label
		else:
			button.text = "  [color=#5f4700]%s[/color]" % label

func _on_resume_pressed() -> void:
	var pause_duration = Time.get_ticks_msec() / 1000.0 - _pause_start_time
	visible = false
	get_tree().paused = false
	EventBus.game_unpaused.emit(pause_duration)
	resumed.emit()

func _on_quit_pressed() -> void:
	var pause_duration = Time.get_ticks_msec() / 1000.0 - _pause_start_time
	visible = false
	get_tree().paused = false
	EventBus.game_unpaused.emit(pause_duration)
	quit_to_menu.emit()
