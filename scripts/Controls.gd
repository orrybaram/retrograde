extends Node

## Every input the game reads lives here: flight, the shortcuts, the chart and the fixed
## menu keys, each with its keyboard and gamepad defaults. They are registered into the
## InputMap at boot (project.godot carries none), rebound through `rebind()` from the
## CONTROLS screen (`ui/ControlsUI.gd`) and saved to `save_path`.
##
## Game code keeps asking the InputMap (`Input.is_action_pressed("thrust")`); menus ask
## `menu_action(event)` rather than matching keycodes, so arrows / ENTER / ESC and the
## D-pad / A / B drive every terminal alike. Prompts ask `label(action)`, which follows
## whichever device was touched last: a pad player reads [A] where a keyboard reads [SPACE].
##
## The left stick is turned into menu presses here, with key-repeat, and a held D-pad
## repeats too, so a pad scrolls a list the way a held arrow key does.

signal bindings_changed
signal device_changed(pad: bool)

enum Kind { KEY, PAD }

## Where an action is live. Two actions may share an input only when they never are
## live together: flight's LB strafes, a menu's LB changes tab.
const CTX_FLIGHT := 1
const CTX_MENU := 2

## Bindings per device per action: a main one and an alternate.
const SLOTS := 2
const DEADZONE := 0.5
## A stick past this, or a trigger pulled this far, counts when capturing a rebind.
const CAPTURE_AXIS := 0.6
const REPEAT_DELAY := 0.4
const REPEAT_RATE := 0.08
## Stick menu nav presses past PRESS and lets go under RELEASE, so it doesn't chatter.
const STICK_PRESS := 0.6
const STICK_RELEASE := 0.35

const DEFAULT_SAVE_PATH := "user://controls.cfg"

## Every action in display order, grouped for the CONTROLS screen. A `fixed` one is
## shown but can't be rebound: the keys that get you out of a menu can never be lost.
const ACTIONS := [
	{"id": &"thrust", "label": "THRUST", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"reverse_thrust", "label": "REVERSE", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"turn_left", "label": "TURN LEFT", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"turn_right", "label": "TURN RIGHT", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"strafe_left", "label": "STRAFE LEFT", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"strafe_right", "label": "STRAFE RIGHT", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"boost", "label": "BOOST", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"action", "label": "ACTION / SONAR", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"radio_next", "label": "RADIO NEXT", "group": "FLIGHT", "ctx": CTX_FLIGHT},
	{"id": &"open_log", "label": "LOG", "group": "SHORTCUTS", "ctx": CTX_FLIGHT | CTX_MENU},
	{"id": &"open_map", "label": "CHART", "group": "SHORTCUTS", "ctx": CTX_FLIGHT | CTX_MENU},
	{"id": &"pause", "label": "PAUSE", "group": "SHORTCUTS", "ctx": CTX_FLIGHT | CTX_MENU, "fixed": true},
	{"id": &"chart_zoom_in", "label": "ZOOM IN", "group": "CHART", "ctx": CTX_MENU},
	{"id": &"chart_zoom_out", "label": "ZOOM OUT", "group": "CHART", "ctx": CTX_MENU},
	{"id": &"chart_pan_up", "label": "PAN UP", "group": "CHART", "ctx": CTX_MENU},
	{"id": &"chart_pan_down", "label": "PAN DOWN", "group": "CHART", "ctx": CTX_MENU},
	{"id": &"chart_pan_left", "label": "PAN LEFT", "group": "CHART", "ctx": CTX_MENU},
	{"id": &"chart_pan_right", "label": "PAN RIGHT", "group": "CHART", "ctx": CTX_MENU},
	{"id": &"chart_center", "label": "CENTER", "group": "CHART", "ctx": CTX_MENU},
	{"id": &"menu_up", "label": "UP", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	{"id": &"menu_down", "label": "DOWN", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	{"id": &"menu_left", "label": "LEFT", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	{"id": &"menu_right", "label": "RIGHT", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	{"id": &"menu_accept", "label": "CONFIRM", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	{"id": &"menu_back", "label": "BACK", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	# Before NEXT TAB: an action's modifiers only have to be a subset of the event's, so
	# plain TAB would also claim SHIFT+TAB.
	{"id": &"menu_tab_prev", "label": "PREV TAB", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	{"id": &"menu_tab_next", "label": "NEXT TAB", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
	{"id": &"menu_clear", "label": "CLEAR", "group": "MENUS", "ctx": CTX_MENU, "fixed": true},
]

const GROUPS := ["FLIGHT", "SHORTCUTS", "CHART", "MENUS"]

const _KEY_NAMES := {
	"Escape": "ESC", "Delete": "DEL", "Backspace": "BKSP", "Equal": "=", "Minus": "-",
	"Kp Add": "KP +", "Kp Subtract": "KP -", "Kp Enter": "KP ENTER", "Quoteleft": "`",
	"Bracketleft": "[", "Bracketright": "]", "Semicolon": ";", "Apostrophe": "'",
	"Comma": ",", "Period": ".", "Slash": "/", "Backslash": "\\",
}
const _BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_GUIDE: "GUIDE", JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
}
const _DPAD_DIRS := {
	JOY_BUTTON_DPAD_UP: &"menu_up", JOY_BUTTON_DPAD_DOWN: &"menu_down",
	JOY_BUTTON_DPAD_LEFT: &"menu_left", JOY_BUTTON_DPAD_RIGHT: &"menu_right",
}

var save_path := DEFAULT_SAVE_PATH
## True once a pad was the last thing touched; labels then name pad inputs.
var using_pad := false

## id -> {Kind.KEY: [event|null, ...], Kind.PAD: [...]}, SLOTS long each.
var _bindings: Dictionary = {}
var _by_id: Dictionary = {}
## Actions live in menus, the fixed MENUS keys first: ESC is BACK to a menu before it is PAUSE.
var _menu_order: Array[StringName] = []
var _held_dir: StringName = &""
var _held_from_stick := false
var _repeat_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		_by_id[a["id"]] = a
		if a["group"] == "MENUS":
			_menu_order.append(a["id"])
	for a in ACTIONS:
		if a["ctx"] & CTX_MENU and a["group"] != "MENUS":
			_menu_order.append(a["id"])
	_bindings = defaults()
	load_bindings()
	_register_all()


# --- Queries -----------------------------------------------------------------

func info(id: StringName) -> Dictionary:
	return _by_id.get(id, {})


func is_fixed(id: StringName) -> bool:
	return info(id).get("fixed", false)


func event_at(id: StringName, kind: int, slot: int) -> InputEvent:
	return _bindings[id][kind][slot]


## The menu action an event means, if any: the fixed menu keys first, then the rest live
## in menus (the shortcuts and the chart's). Empty when it means nothing to a menu.
func menu_action(event: InputEvent, allow_echo := true) -> StringName:
	if not event.is_pressed() or (event.is_echo() and not allow_echo):
		return &""
	for id in _menu_order:
		if event.is_action_pressed(id, true):
			return id
	return &""


## The fixed menu directions held right now, keys, D-pad and left stick together, for
## anything that glides while a direction is held (the chart's mark).
func nav_vector() -> Vector2:
	var v := Vector2.ZERO
	for code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		if Input.is_key_pressed(code):
			v += _dir_vector(_menu_dir_for_key(code))
	for pad in Input.get_connected_joypads():
		for button in _DPAD_DIRS:
			if Input.is_joy_button_pressed(pad, button):
				v += _dir_vector(_DPAD_DIRS[button])
		var stick := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if stick.length() > DEADZONE:
			v += stick
	return v.limit_length(1.0)


## What to print for an action in a prompt, "SPACE" or "A": its main binding on the
## device in use, else on the other one, else "--".
func label(id: StringName) -> String:
	if not _bindings.has(id):
		return String(id).to_upper()
	var kinds := [Kind.PAD, Kind.KEY] if using_pad else [Kind.KEY, Kind.PAD]
	for kind in kinds:
		for ev in _bindings[id][kind]:
			if ev != null:
				return event_label(ev)
	return "--"


## "UP/DN" on a keyboard, "D-PAD" on a pad: the fixed pair that moves a menu cursor.
func nav_label() -> String:
	return "D-PAD" if using_pad else "UP/DN"


## A terminal's footer: "UP/DN SELECT   ENTER BUY   ESC BACK", in the device's names.
func menu_hint(accept_verb: String, back_verb: String) -> String:
	return "%s SELECT   %s %s   %s %s" % [nav_label(), label(&"menu_accept"), accept_verb,
			label(&"menu_back"), back_verb]


static func event_label(ev: InputEvent) -> String:
	if ev == null:
		return "--"
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.keycode
		# A physical binding reads as whatever that key prints on this layout.
		if code == KEY_NONE and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)
		if code == KEY_NONE:
			code = k.physical_keycode
		var text := OS.get_keycode_string(code)
		text = _KEY_NAMES.get(text, text)
		if k.shift_pressed:
			text = "SHIFT+" + text
		return text.to_upper()
	if ev is InputEventJoypadButton:
		var b := (ev as InputEventJoypadButton).button_index
		return _BUTTON_NAMES.get(b, "BTN %d" % b)
	if ev is InputEventJoypadMotion:
		var m := ev as InputEventJoypadMotion
		var neg := m.axis_value < 0.0
		match m.axis:
			JOY_AXIS_LEFT_X: return "LS LEFT" if neg else "LS RIGHT"
			JOY_AXIS_LEFT_Y: return "LS UP" if neg else "LS DOWN"
			JOY_AXIS_RIGHT_X: return "RS LEFT" if neg else "RS RIGHT"
			JOY_AXIS_RIGHT_Y: return "RS UP" if neg else "RS DOWN"
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
		return "AXIS %d%s" % [m.axis, "-" if neg else "+"]
	return "?"


# --- Rebinding ---------------------------------------------------------------

## Turn a raw event the player just pressed into a binding for `kind`, or null when it
## can't be one (wrong device, a release, a stick barely moved, a reserved input).
## ESC and START are reserved: they cancel a capture, and they are PAUSE.
static func capture(event: InputEvent, kind: int) -> InputEvent:
	if kind == Kind.KEY and event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo or k.keycode == KEY_ESCAPE:
			return null
		return key(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if kind == Kind.PAD and event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		if not b.pressed or b.button_index == JOY_BUTTON_START:
			return null
		return button(b.button_index)
	if kind == Kind.PAD and event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) < CAPTURE_AXIS:
			return null
		return axis(m.axis, signf(m.axis_value))
	return null


## Whether `event` cancels a capture in progress.
static func cancels_capture(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_START
	return false


## Bind `event` to `id`'s `slot` for `kind`. Another rebindable action live at the same
## time that already uses it swaps: it takes this slot's old input. A fixed one blocks it.
## Returns {"ok": bool, "swapped": id or &"", "blocked": id or &""}.
func rebind(id: StringName, kind: int, slot: int, event: InputEvent) -> Dictionary:
	var result := {"ok": false, "swapped": &"", "blocked": &""}
	if is_fixed(id) or event == null:
		return result
	var old: InputEvent = _bindings[id][kind][slot]
	var clashes: Array = []  # [other id, slot]
	for a in ACTIONS:
		if not (a["ctx"] & info(id)["ctx"]):
			continue
		for s in SLOTS:
			if (a["id"] == id and s == slot) or not same_input(_bindings[a["id"]][kind][s], event):
				continue
			if a.get("fixed", false):
				result["blocked"] = a["id"]
				return result
			clashes.append([a["id"], s])
	for clash in clashes:
		# The other one takes this slot's old input; its own alternate just trades places.
		_bindings[clash[0]][kind][clash[1]] = old
		if clash[0] != id:
			result["swapped"] = clash[0]
			_register(clash[0])
	_bindings[id][kind][slot] = event
	_register(id)
	save_bindings()
	bindings_changed.emit()
	result["ok"] = true
	return result


func clear_binding(id: StringName, kind: int, slot: int) -> void:
	if is_fixed(id):
		return
	_bindings[id][kind][slot] = null
	_register(id)
	save_bindings()
	bindings_changed.emit()


func reset_to_defaults() -> void:
	_bindings = defaults()
	_register_all()
	save_bindings()
	bindings_changed.emit()


static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		return _key_code(a) == _key_code(b) and a.shift_pressed == b.shift_pressed
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


static func _key_code(k: InputEventKey) -> int:
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode


# --- Defaults ----------------------------------------------------------------

## Physical, so WASD stays where it is on any layout.
static func key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	return ev


## By keycode: menus' named keys (ENTER, ESC, the arrows) read the same on any layout.
static func named_key(code: Key, shift := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.shift_pressed = shift
	return ev


static func button(index: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = index
	return ev


static func axis(which: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = which
	ev.axis_value = signf(direction)
	return ev


static func defaults() -> Dictionary:
	var d := {
		&"thrust": [[key(KEY_UP), key(KEY_W)], [axis(JOY_AXIS_TRIGGER_RIGHT, 1), axis(JOY_AXIS_LEFT_Y, -1)]],
		&"reverse_thrust": [[key(KEY_DOWN), key(KEY_S)], [axis(JOY_AXIS_TRIGGER_LEFT, 1), axis(JOY_AXIS_LEFT_Y, 1)]],
		&"turn_left": [[key(KEY_LEFT), key(KEY_A)], [axis(JOY_AXIS_LEFT_X, -1), button(JOY_BUTTON_DPAD_LEFT)]],
		&"turn_right": [[key(KEY_RIGHT), key(KEY_D)], [axis(JOY_AXIS_LEFT_X, 1), button(JOY_BUTTON_DPAD_RIGHT)]],
		&"strafe_left": [[key(KEY_Q)], [button(JOY_BUTTON_LEFT_SHOULDER)]],
		&"strafe_right": [[key(KEY_E)], [button(JOY_BUTTON_RIGHT_SHOULDER)]],
		&"boost": [[key(KEY_SHIFT)], [button(JOY_BUTTON_B)]],
		&"action": [[key(KEY_SPACE)], [button(JOY_BUTTON_A)]],
		&"radio_next": [[key(KEY_TAB)], [button(JOY_BUTTON_Y)]],
		&"open_log": [[key(KEY_I)], [button(JOY_BUTTON_BACK)]],
		&"open_map": [[key(KEY_M)], [button(JOY_BUTTON_RIGHT_STICK)]],
		&"pause": [[named_key(KEY_ESCAPE)], [button(JOY_BUTTON_START)]],
		&"chart_zoom_in": [[key(KEY_EQUAL), key(KEY_KP_ADD)], [axis(JOY_AXIS_TRIGGER_RIGHT, 1)]],
		&"chart_zoom_out": [[key(KEY_MINUS), key(KEY_KP_SUBTRACT)], [axis(JOY_AXIS_TRIGGER_LEFT, 1)]],
		&"chart_pan_up": [[key(KEY_W)], [axis(JOY_AXIS_RIGHT_Y, -1)]],
		&"chart_pan_down": [[key(KEY_S)], [axis(JOY_AXIS_RIGHT_Y, 1)]],
		&"chart_pan_left": [[key(KEY_A)], [axis(JOY_AXIS_RIGHT_X, -1)]],
		&"chart_pan_right": [[key(KEY_D)], [axis(JOY_AXIS_RIGHT_X, 1)]],
		&"chart_center": [[key(KEY_C)], [button(JOY_BUTTON_Y)]],
		&"menu_up": [[named_key(KEY_UP)], [button(JOY_BUTTON_DPAD_UP)]],
		&"menu_down": [[named_key(KEY_DOWN)], [button(JOY_BUTTON_DPAD_DOWN)]],
		&"menu_left": [[named_key(KEY_LEFT)], [button(JOY_BUTTON_DPAD_LEFT)]],
		&"menu_right": [[named_key(KEY_RIGHT)], [button(JOY_BUTTON_DPAD_RIGHT)]],
		&"menu_accept": [[named_key(KEY_ENTER), named_key(KEY_KP_ENTER)], [button(JOY_BUTTON_A)]],
		&"menu_back": [[named_key(KEY_ESCAPE)], [button(JOY_BUTTON_B)]],
		&"menu_tab_prev": [[named_key(KEY_TAB, true)], [button(JOY_BUTTON_LEFT_SHOULDER)]],
		&"menu_tab_next": [[named_key(KEY_TAB)], [button(JOY_BUTTON_RIGHT_SHOULDER)]],
		&"menu_clear": [[named_key(KEY_DELETE), named_key(KEY_BACKSPACE)], [button(JOY_BUTTON_X)]],
	}
	var out := {}
	for id in d:
		out[id] = {Kind.KEY: _slots(d[id][0]), Kind.PAD: _slots(d[id][1])}
	return out


static func _slots(events: Array) -> Array:
	var s: Array = events.duplicate()
	s.resize(SLOTS)
	return s


func _register_all() -> void:
	for a in ACTIONS:
		_register(a["id"])


func _register(id: StringName) -> void:
	if InputMap.has_action(id):
		InputMap.erase_action(id)
	InputMap.add_action(id, DEADZONE)
	for kind in [Kind.KEY, Kind.PAD]:
		for ev in _bindings[id][kind]:
			if ev != null:
				InputMap.action_add_event(id, ev)


# --- Saving ------------------------------------------------------------------

## Only rebindable actions are written; a missing or unreadable entry keeps its default.
func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for a in ACTIONS:
		if a.get("fixed", false):
			continue
		var id: StringName = a["id"]
		cfg.set_value("keys", id, _bindings[id][Kind.KEY].map(_encode))
		cfg.set_value("pad", id, _bindings[id][Kind.PAD].map(_encode))
	cfg.save(save_path)


func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	for a in ACTIONS:
		if a.get("fixed", false):
			continue
		var id: StringName = a["id"]
		for pair in [["keys", Kind.KEY], ["pad", Kind.PAD]]:
			var saved = cfg.get_value(pair[0], id, null)
			if not (saved is Array) or saved.size() != SLOTS:
				continue
			_bindings[id][pair[1]] = saved.map(_decode)


static func _encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "k:%d" % _key_code(ev)
	if ev is InputEventJoypadButton:
		return "b:%d" % ev.button_index
	if ev is InputEventJoypadMotion:
		return "a:%d:%d" % [ev.axis, int(signf(ev.axis_value))]
	return ""


static func _decode(s: Variant) -> InputEvent:
	var parts := str(s).split(":")
	match parts[0]:
		"k":
			return key(int(parts[1]) as Key) if parts.size() == 2 else null
		"b":
			return button(int(parts[1]) as JoyButton) if parts.size() == 2 else null
		"a":
			return axis(int(parts[1]) as JoyAxis, float(parts[2])) if parts.size() == 3 else null
	return null


## Test hook: rebuild from defaults and point saving somewhere else.
func use_save_path(path: String) -> void:
	save_path = path
	_bindings = defaults()
	load_bindings()
	_register_all()


# --- Device + pad menu nav ---------------------------------------------------

func _process(delta: float) -> void:
	_track_device()
	_drive_pad_nav(delta)


## Polled rather than read from `_input`: menus swallow their events before an autoload
## would see them.
func _track_device() -> void:
	var pad := false
	for d in Input.get_connected_joypads():
		for b in JOY_BUTTON_SDL_MAX:
			if Input.is_joy_button_pressed(d, b as JoyButton):
				pad = true
		for ax in JOY_AXIS_SDL_MAX:
			if absf(Input.get_joy_axis(d, ax as JoyAxis)) > STICK_PRESS:
				pad = true
	if pad:
		_set_pad(true)
	elif Input.is_anything_pressed():
		_set_pad(false)


func _set_pad(pad: bool) -> void:
	if pad == using_pad:
		return
	using_pad = pad
	device_changed.emit(pad)


## A pushed stick presses a menu direction, a held stick or D-pad repeats it. The first
## D-pad press is the button's own event; only its repeats come from here.
func _drive_pad_nav(delta: float) -> void:
	var dir := &""
	var from_stick := false
	for d in Input.get_connected_joypads():
		for b in _DPAD_DIRS:
			if Input.is_joy_button_pressed(d, b):
				dir = _DPAD_DIRS[b]
		if dir != &"":
			break
		var stick := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		var threshold := STICK_RELEASE if _held_from_stick and _held_dir != &"" else STICK_PRESS
		if stick.length() > threshold:
			from_stick = true
			if absf(stick.x) > absf(stick.y):
				dir = &"menu_right" if stick.x > 0 else &"menu_left"
			else:
				dir = &"menu_down" if stick.y > 0 else &"menu_up"
			break
	if dir != _held_dir:
		_held_dir = dir
		_held_from_stick = from_stick
		_repeat_left = REPEAT_DELAY
		if dir != &"" and from_stick:
			_press(dir)
		return
	if dir == &"":
		return
	_repeat_left -= delta
	if _repeat_left <= 0.0:
		_repeat_left = REPEAT_RATE
		_press(dir)


func _press(id: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = id
		ev.pressed = pressed
		Input.parse_input_event(ev)


static func _menu_dir_for_key(code: Key) -> StringName:
	match code:
		KEY_LEFT: return &"menu_left"
		KEY_RIGHT: return &"menu_right"
		KEY_UP: return &"menu_up"
	return &"menu_down"


static func _dir_vector(dir: StringName) -> Vector2:
	match dir:
		&"menu_left": return Vector2.LEFT
		&"menu_right": return Vector2.RIGHT
		&"menu_up": return Vector2.UP
	return Vector2.DOWN
