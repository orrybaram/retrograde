extends Control
class_name StartMenu

## Start menu with terminal-style interface and arrow key navigation.

signal start_game
signal load_game

@onready var start_button: RichTextLabel = $CenterContainer/VBoxContainer/MenuPanel/MarginContainer/VBoxContainer/StartRow/StartButton
@onready var load_button: RichTextLabel = $CenterContainer/VBoxContainer/MenuPanel/MarginContainer/VBoxContainer/LoadRow/LoadButton
@onready var load_row: HBoxContainer = $CenterContainer/VBoxContainer/MenuPanel/MarginContainer/VBoxContainer/LoadRow
@onready var quit_button: RichTextLabel = $CenterContainer/VBoxContainer/MenuPanel/MarginContainer/VBoxContainer/QuitRow/QuitButton

var _save_exists: bool = false
var _selected_index: int = 0
var _menu_items: Array[Dictionary] = []  # [{button: RichTextLabel, action: Callable, enabled: bool, label: String}]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Always process so button works when paused
	add_to_group("start_menu")

	# Connect click handlers
	if load_button:
		load_button.gui_input.connect(_on_item_gui_input.bind(0))
	if start_button:
		start_button.gui_input.connect(_on_item_gui_input.bind(1))
	if quit_button:
		quit_button.gui_input.connect(_on_item_gui_input.bind(2))

	_update_display()

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
				_on_quit_pressed()
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
		_update_display()

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

func _update_display() -> void:
	_save_exists = Save.save_exists()

	# Build menu items list
	_menu_items.clear()
	_menu_items.append({"button": load_button, "action": _on_load_pressed, "enabled": _save_exists, "label": "CONTINUE"})
	_menu_items.append({"button": start_button, "action": _on_start_pressed, "enabled": true, "label": "NEW GAME"})
	_menu_items.append({"button": quit_button, "action": _on_quit_pressed, "enabled": true, "label": "QUIT"})

	# Ensure selected index is on an enabled item
	if not _menu_items[_selected_index]["enabled"]:
		_move_selection(1)

	# Update all items
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

func _on_start_pressed() -> void:
	start_game.emit()
	visible = false

func _on_load_pressed() -> void:
	if _save_exists:
		load_game.emit()
		visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func show_menu() -> void:
	visible = true
	_selected_index = 0
	_update_display()
