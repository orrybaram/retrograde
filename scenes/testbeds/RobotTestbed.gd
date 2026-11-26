extends Control

## Test bed for the guide robot. Run with:
##   godot --path . res://scenes/testbeds/RobotTestbed.tscn [-- --talk --preset=N]
## Arrows pick a face, V cycles the model, ENTER toggles talking, G glitches, B blinks.

const COLUMNS := 4
const GRID_FONT := 16
const HERO_FONT := 24
const PRESET_FONT := 8

const PRESETS := [
	{"name": "BRICK", "antenna": RobotView.Antenna.NONE, "faceplate": RobotView.Faceplate.SPEAKER},
	{"name": "SCOUT", "antenna": RobotView.Antenna.TWIN, "faceplate": RobotView.Faceplate.BOLTS},
	{"name": "BEACON", "antenna": RobotView.Antenna.SINGLE, "faceplate": RobotView.Faceplate.LIGHTS},
	{"name": "RELAY", "antenna": RobotView.Antenna.DISH, "faceplate": RobotView.Faceplate.BUTTONS},
	{"name": "WHIP", "antenna": RobotView.Antenna.OFFSET, "faceplate": RobotView.Faceplate.SPEAKER},
	{"name": "ARRAY", "antenna": RobotView.Antenna.TRIPLE, "faceplate": RobotView.Faceplate.KEYPAD},
]

var _selected := 0
var _preset := 0
var _talking := false
var _hero: RobotView
var _cells: Array[PanelContainer] = []
var _grid_views: Array[RobotView] = []
var _preset_cells: Array[PanelContainer] = []
var _preset_views: Array[RobotView] = []
var _title: Label

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Colors.SPACE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 20
	root.offset_right = -24
	root.offset_bottom = -20
	root.add_theme_constant_override("separation", 28)
	add_child(root)

	root.add_child(_build_hero_column())
	var grid_holder := CenterContainer.new()
	grid_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_holder.add_child(_build_grid())
	root.add_child(grid_holder)
	_talking = "--talk" in OS.get_cmdline_user_args()
	_apply_talking()
	_select(0)
	var start_preset := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			start_preset = int(arg.get_slice("=", 1))
	_select_preset(start_preset)

func _build_hero_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 300
	col.add_theme_constant_override("separation", 12)
	col.add_child(_label("/ R O B O T   T E S T   B E D /", Colors.PRIMARY, 8))

	_hero = RobotView.new()
	_hero.font_size = HERO_FONT
	_hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_hero)

	_title = _label("", Colors.PRIMARY, 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	var presets := GridContainer.new()
	presets.columns = 3
	presets.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	presets.add_theme_constant_override("h_separation", 8)
	presets.add_theme_constant_override("v_separation", 8)
	for p in PRESETS:
		var v := RobotView.new()
		v.font_size = PRESET_FONT
		v.antenna = p.antenna
		v.faceplate = p.faceplate
		var cell := _cell(v, p.name)
		presets.add_child(cell)
		_preset_cells.append(cell)
		_preset_views.append(v)
	col.add_child(presets)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	col.add_child(_label("ARROWS FACE   V MODEL   ENTER TALK\nG GLITCH      B BLINK", Colors.PRIMARY_DIM, 8))
	return col

func _build_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for face in RobotFaces.names():
		var v := RobotView.new()
		v.font_size = GRID_FONT
		v.expression = face
		var cell := _cell(v, String(face).to_upper())
		grid.add_child(cell)
		_cells.append(cell)
		_grid_views.append(v)
	return grid

func _cell(view: RobotView, caption: String) -> PanelContainer:
	var cell := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view)
	var name_label := _label(caption, Colors.PRIMARY, 8)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	cell.add_child(box)
	cell.add_theme_stylebox_override("panel", _cell_style(false))
	return cell

func _label(text: String, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	return l

func _cell_style(selected: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(2)
	s.border_color = Colors.UI_BORDER if selected else Colors.PRIMARY_GHOST
	s.set_content_margin_all(8)
	return s

func _select(index: int) -> void:
	_selected = posmod(index, _cells.size())
	for i in _cells.size():
		_cells[i].add_theme_stylebox_override("panel", _cell_style(i == _selected))
	var face: StringName = RobotFaces.names()[_selected]
	_hero.expression = face
	for v in _preset_views:
		v.expression = face
	_refresh_title()

func _select_preset(index: int) -> void:
	_preset = posmod(index, PRESETS.size())
	var p: Dictionary = PRESETS[_preset]
	for i in _preset_cells.size():
		_preset_cells[i].add_theme_stylebox_override("panel", _cell_style(i == _preset))
	for v in [_hero] + _grid_views:
		v.antenna = p.antenna
		v.faceplate = p.faceplate
	_refresh_title()

func _refresh_title() -> void:
	if _hero == null:
		return
	_title.text = "> %s / %s%s" % [PRESETS[_preset].name, String(_hero.expression).to_upper(), "  [TALKING]" if _talking else ""]

func _all_views() -> Array[RobotView]:
	var out: Array[RobotView] = [_hero]
	out.append_array(_preset_views)
	out.append_array(_grid_views)
	return out

func _apply_talking() -> void:
	for v in _all_views():
		v.talking = _talking

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_LEFT:
			_select(_selected - 1)
		KEY_RIGHT:
			_select(_selected + 1)
		KEY_UP:
			_select(_selected - COLUMNS)
		KEY_DOWN:
			_select(_selected + COLUMNS)
		KEY_V:
			_select_preset(_preset + 1)
		KEY_ENTER, KEY_KP_ENTER:
			_talking = not _talking
			_apply_talking()
			_refresh_title()
		KEY_G:
			for v in _all_views():
				v.glitch_burst(0.4)
		KEY_B:
			for v in _all_views():
				v.blink()
		_:
			return
	get_viewport().set_input_as_handled()
