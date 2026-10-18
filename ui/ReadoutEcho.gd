extends Control
class_name ReadoutEcho

## The name of what a Sweep just read, blooming over it where the ring touched it (docs/SWEEP.md
## §10): one line pinned to the thing in the world, typed, held and faded, so the eye knows
## which thing answered before it reads the rows in the corner (ContactLog). Something of
## the Titan's blooms as its noise, in its purple. Under a HUD panel (`blockers`) it is not
## drawn: the panel is in front of the thing, and the corner already has the rows.

const TEXT_SIZE := BootLog.TEXT_SIZE
const OUTLINE := BootLog.OUTLINE
## Characters a second, the diagnostic's own rate.
const TYPE_RATE := BootChecklist.TYPE_RATE
## Seconds it stays once typed, and how long it takes to fade.
const HOLD := 2.2
const FADE_TIME := 0.8
## Screen px between the point the ring touched and the bottom of the line, and how far it
## drifts up over RISE_TIME as it blooms.
const LIFT := 22.0
const RISE := 6.0
const RISE_TIME := 0.6

## Panels an echo hides behind while it overlaps one.
var blockers: Array[Control] = []
## Oldest first. Each: {id: the readout's instance id, label: Label, age}.
var _echoes: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("readout_echo")
	# Main.clear_screen_effects: a new game, a load or a quit to the menu clears it
	add_to_group("screen_effects")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.readout_swept.connect(show_read)


## Bloom the name of what `readout` is over it.
func show_read(readout: Node, _tier: int, _rows: Array) -> void:
	var r := readout as SweepReadout
	if r == null:
		return
	var text := r.shown_title() if r.shown_title() != "" else r.shown_heading()
	var id := r.get_instance_id()
	for echo in _echoes:
		if echo.id == id:
			echo.label.text = text
			echo.age = 0.0
			return
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", TEXT_SIZE)
	label.add_theme_color_override("font_color", Colors.TITAN if r.undecipherable else Colors.PRIMARY)
	label.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	label.add_theme_constant_override("outline_size", OUTLINE)
	label.visible_characters = 0
	add_child(label)
	_echoes.append({"id": id, "label": label, "age": 0.0})


## What is blooming right now, oldest first: each line as typed so far.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for echo in _echoes:
		out.append(echo.label.text.left(echo.label.visible_characters) if echo.label.visible_characters >= 0 else echo.label.text)
	return out


func clear_now() -> void:
	while not _echoes.is_empty():
		_drop(0)


func _process(dt: float) -> void:
	if _echoes.is_empty():
		return
	var to_local := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_canvas_transform()
	for i in range(_echoes.size() - 1, -1, -1):
		var echo: Dictionary = _echoes[i]
		var r := instance_from_id(echo.id) as SweepReadout
		echo.age += dt
		var label: Label = echo.label
		var gone_at: float = label.text.length() / TYPE_RATE + HOLD + FADE_TIME
		if r == null or not is_instance_valid(r) or echo.age >= gone_at:
			_drop(i)
			continue
		label.visible_characters = mini(int(echo.age * TYPE_RATE), label.text.length())
		label.modulate.a = clampf((gone_at - echo.age) / FADE_TIME, 0.0, 1.0)
		label.reset_size()
		var rise := RISE * clampf(echo.age / RISE_TIME, 0.0, 1.0)
		var at := to_local * r.global_position
		label.position = at - Vector2(label.size.x * 0.5, LIFT + rise + label.size.y)
		label.visible = not _blocked(label.get_global_rect())


func _blocked(rect: Rect2) -> bool:
	for b in blockers:
		if b and is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().intersects(rect):
			return true
	return false


func _drop(i: int) -> void:
	_echoes[i].label.queue_free()
	_echoes.remove_at(i)
