extends Control
class_name SpacePortDialogue

## Space Port hub menu - small left-side panel listing what the dock offers.
## There is no store (docs/adr/0007). At SR-7, whose Cradle is where Components wait, the
## hub offers SHIP (with a count of what is waiting, and none when nothing is) above
## DEPART. SHIP widens the panel into ShipPage, where Components are fitted and taken off
## (docs/adr/0014); BACK returns to the hub. Elsewhere the only row is DEPART.

var ship: Ship = null
var spaceport: SpacePort = null
var gs: GameState = null

var _selected_index: int = 0
var _menu_items: Array[Dictionary] = []
## "hub" or "ship": which page is up.
var _page := "hub"

## Rows are padded to this many characters, so a count on the right lines up.
const ROW_WIDTH := 22
## The panel's reach while SHIP is up: taller, and wider but short of the screen's middle,
## where the docked ship is, so the hull changing behind the menu stays in view.
## Left, top, right, bottom.
const SHIP_ANCHORS: Array[float] = [0.03, 0.06, 0.42, 0.94]

signal dialogue_closed

# Node references (built in _ready)
var _hub_items_container: VBoxContainer = null
var _ship_page: ShipPage = null
var _page_header: Label = null
## The panel's anchors and offsets as the scene lays it out (left, top, right, bottom).
var _hub_anchors: Array[float] = []
var _hub_offsets: Array[float] = []
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
	_bg_rect.color = Color(Colors.SPACE_BG, 0.95)
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
	border_style.border_color = Colors.PRIMARY
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
	_title_label.add_theme_color_override("font_color", Colors.PRIMARY)
	var title_bg = StyleBoxFlat.new()
	title_bg.bg_color = Colors.UI_BACKGROUND_SOLID
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

	var page_vbox = VBoxContainer.new()
	page_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(page_vbox)

	_page_header = _make_header("D O C K E D")
	page_vbox.add_child(_page_header)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	page_vbox.add_child(spacer)

	_hub_items_container = VBoxContainer.new()
	_hub_items_container.add_theme_constant_override("separation", 4)
	page_vbox.add_child(_hub_items_container)

	_ship_page = ShipPage.new()
	_ship_page.visible = false
	page_vbox.add_child(_ship_page)

	_hub_anchors = [anchor_left, anchor_top, anchor_right, anchor_bottom]
	_hub_offsets = [offset_left, offset_top, offset_right, offset_bottom]

func _make_header(text: String) -> Label:
	var label = Label.new()
	label.add_theme_color_override("font_color", Colors.PRIMARY)
	var indent = StyleBoxEmpty.new()
	indent.content_margin_left = 20.0
	label.add_theme_stylebox_override("normal", indent)
	label.text = text
	return label

func _input(event: InputEvent) -> void:
	if not visible:
		return

	match Controls.menu_action(event):
		&"menu_up":
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		&"menu_down":
			_move_selection(1)
			get_viewport().set_input_as_handled()
		&"menu_accept":
			_activate_selection()
			get_viewport().set_input_as_handled()
		&"menu_back":
			if _page == "ship":
				_show_page("hub")
			else:
				close_dialogue()
			get_viewport().set_input_as_handled()
		_:
			if event.is_action_pressed(&"action"):
				_activate_selection()
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
	_show_page("hub")
	visible = true
	EventBus.action_message_changed.emit("")

func close_dialogue() -> void:
	if _page != "hub":
		_show_page("hub")
	visible = false
	spaceport = null
	dialogue_closed.emit()

func _clear_container(container: VBoxContainer) -> void:
	while container.get_child_count() > 0:
		var child = container.get_child(0)
		container.remove_child(child)
		child.free()

## Put `page` up ("hub" or "ship"), with the cursor on its first row.
func _show_page(page: String) -> void:
	_page = page
	var ship_up := page == "ship"
	_hub_items_container.visible = not ship_up
	_ship_page.visible = ship_up
	if not ship_up:
		_ship_page.schematic.show_ship(null, PackedStringArray())  # stop the ghost blinking
	_page_header.text = "S H I P" if ship_up else "D O C K E D"
	var a: Array = SHIP_ANCHORS if ship_up else _hub_anchors
	var o: Array = [0.0, 0.0, 0.0, 0.0] if ship_up else _hub_offsets
	anchor_left = a[0]
	anchor_top = a[1]
	anchor_right = a[2]
	anchor_bottom = a[3]
	offset_left = o[0]
	offset_top = o[1]
	offset_right = o[2]
	offset_bottom = o[3]
	_selected_index = 0
	_update_hub_display()

func _update_hub_display() -> void:
	_menu_items.clear()
	var container := _rows()
	_clear_container(container)

	if _page == "ship":
		_ship_rows()
	else:
		_hub_rows()

	if _selected_index >= _menu_items.size():
		_selected_index = 0

	for i in range(_menu_items.size()):
		if _menu_items[i].get("separator_before", false):
			container.add_child(_make_separator())
		container.add_child(_make_menu_label())

	_update_menu_display()

func _rows() -> VBoxContainer:
	return _ship_page.rows if _page == "ship" else _hub_items_container

func _hub_rows() -> void:
	var cradle := _cradle()
	if cradle:
		var waiting := cradle.waiting().size()
		_menu_items.append({
			"enabled": true,
			"action": _show_page.bind("ship"),
			"label": "SHIP",
			"aside": str(waiting) if waiting > 0 else "",
		})
	_menu_items.append({
		"enabled": true,
		"action": close_dialogue,
		"label": "DEPART",
	})

## FIT for each Component waiting, STOW for each one on the hull, BACK.
func _ship_rows() -> void:
	var cradle := _cradle()
	if cradle:
		for id in cradle.waiting():
			_menu_items.append({
				"enabled": true,
				"action": _fit.bind(id),
				"label": "FIT %s" % Components.label(id),
				"fit": id,
			})
		for id in _fitted():
			_menu_items.append({
				"enabled": true,
				"action": _stow.bind(id),
				"label": "STOW %s" % Components.label(id),
				"stow": id,
			})
	_menu_items.append({
		"enabled": true,
		"action": _show_page.bind("hub"),
		"label": "BACK",
		"separator_before": not _menu_items.is_empty(),
	})

func _fitted() -> PackedStringArray:
	return gs.fitted() if gs else PackedStringArray()

## SR-7's Cradle, when the ship is docked at SR-7.
func _cradle() -> Cradle:
	if gs == null or not is_inside_tree():
		return null
	var cradle := Cradle.find(get_tree())
	return cradle if cradle and cradle.serves(spaceport) else null

func _fit(id: String) -> void:
	var cradle := _cradle()
	if cradle:
		cradle.fit(id)
	_update_hub_display()

func _stow(id: String) -> void:
	var cradle := _cradle()
	if cradle:
		cradle.stow(id)
	_update_hub_display()

## SHIP's drawing and STATUS for the row under the cursor: what the hull wears now, and
## what it would wear if the row were taken.
func _preview_selection() -> void:
	if _page != "ship":
		return
	var now := _fitted()
	var then := now.duplicate()
	var ghost := ""
	var leaving := ""
	var item: Dictionary = _menu_items[_selected_index] if _selected_index < _menu_items.size() else {}
	var cradle := _cradle()
	if item.has("fit") and cradle:
		ghost = item["fit"]
		leaving = cradle.displaces(ghost)
		if leaving != "":
			then.remove_at(then.find(leaving))
		then.append(ghost)
	elif item.has("stow"):
		leaving = item["stow"]
		then.remove_at(then.find(leaving))
	var on := ship if is_instance_valid(ship) else get_tree().get_first_node_in_group("ship") as Ship
	_ship_page.show_ship(on, now, then, ghost, leaving)

func _update_menu_display() -> void:
	var labels: Array[RichTextLabel] = []
	for child in _rows().get_children():
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
		var aside: String = item.get("aside", "")
		if aside != "":
			label_text = "%s[color=#%s]%s[/color]" % [
				label_text.rpad(ROW_WIDTH - aside.length()), Colors.hex(Colors.PRIMARY_DIM), aside]

		if is_selected and is_enabled:
			rtl.text = ("[color=#" + Colors.hex(Colors.PRIMARY) + "]>[/color] %s") % label_text
		elif is_enabled:
			rtl.text = "  %s" % label_text
		else:
			rtl.text = ("  [color=#" + Colors.hex(Colors.PRIMARY_DIM) + "]%s[/color]") % label_text
	_preview_selection()

func _make_menu_label() -> RichTextLabel:
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.add_theme_color_override("default_color", Colors.PRIMARY)
	var indent = StyleBoxEmpty.new()
	indent.content_margin_left = 20.0
	rtl.add_theme_stylebox_override("normal", indent)
	return rtl

func _make_separator() -> Control:
	var sep = Control.new()
	sep.custom_minimum_size = Vector2(0, 8)
	return sep
