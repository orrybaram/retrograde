extends CanvasLayer
class_name VoidShroud

## Full-screen overlay for the Void: the dark closing in, the static, the tears.
## Sits above the HUD, so as the shroud takes hold the instruments go under it
## too — except while a full-screen instrument is open, where it pulls back to
## UI_RELIEF so the player keeps one panel they can still read their way out by.
##
## Driven entirely by VoidZone. Runs while paused so opening a menu in the dark
## eases the overlay back instead of freezing it mid-collapse.

## Above the HUD's CanvasLayer (0), below nothing.
const LAYER := 40
## How much of the shroud survives over something the player has to read.
const UI_RELIEF := 0.35
## Seconds-ish to follow VoidZone in and out. Going dark is slower than coming back.
const DARKEN_SPEED := 0.5
const LIGHTEN_SPEED := 1.4

var _rect: ColorRect
var _material: ShaderMaterial
var _shroud: float = 0.0
var _dread: float = 0.0

func _ready() -> void:
	add_to_group("void_shroud")
	layer = LAYER
	# Menus pause the tree; the overlay still has to ease itself out of the way.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_material = ShaderMaterial.new()
	_material.shader = load("res://scenes/VoidShroud.gdshader")
	_material.set_shader_parameter("void_color", Color(0.0, 0.0, 0.0, 1.0))

	_rect = ColorRect.new()
	_rect.color = Color(1, 1, 1, 1)  # the shader supplies the color; this is just the canvas
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.y <= 0.0:
		return
	_material.set_shader_parameter("half_extent", Vector2(0.5 * size.x / size.y, 0.5))

func _process(delta: float) -> void:
	var relief := UI_RELIEF if _something_to_read() else 1.0
	_shroud = _ease(_shroud, VoidZone.shroud * relief, delta)
	_dread = _ease(_dread, VoidZone.shroud * relief, delta)

	visible = _shroud > 0.002
	if not visible:
		return
	_material.set_shader_parameter("shroud", _shroud)
	_material.set_shader_parameter("dread", _dread)

func _ease(current: float, target: float, delta: float) -> float:
	var speed := DARKEN_SPEED if target > current else LIGHTEN_SPEED
	return move_toward(current, target, speed * delta)

## Something the player has to be able to read: the chart, the pause menu, or a
## transmission holding the game. An ordinary in-flight tip doesn't count — the
## robot's warning is meant to arrive half-swallowed.
func _something_to_read() -> bool:
	if RobotRadio.is_pausing():
		return true
	for group in ["system_map", "pause_menu"]:
		var panel := get_tree().get_first_node_in_group(group) as CanvasItem
		if panel and panel.visible:
			return true
	return false
