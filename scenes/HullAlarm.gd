extends CanvasLayer
class_name HullAlarm

## Full-screen overlay for a failing hull: the rust vignette that breathes at the rim
## while the hull is low, and the tear across the picture when something hits it.
##
## Sits above the HUD so the warning is never hidden behind a readout, but below the
## Void's shroud (40) — out at the edge of the system the dark is the bigger problem,
## and two full-screen alarms stacked on each other read as neither. It pulls out of
## the way entirely while a full-screen panel is open, so the chart and the store stay
## readable, and it goes quiet the moment the ship is gone.
##
## Driven off the bus (EventBus.ship_hull_changed / ship_damaged) rather than by
## holding a ship, so it survives a respawn swapping the ship out from under it.

## Above the HUD's CanvasLayer (0), below VoidShroud (40).
const LAYER := 35
## Seconds-ish to follow the hull in and out. Coming on is slower than going off:
## a repair should feel like relief, not like the alarm was never serious.
const RISE_SPEED := 0.9
const FALL_SPEED := 2.0
## How hard a hit floods the screen, and how fast it bleeds off.
const HIT_DECAY := 2.6
## Alarm strength at each level.
const STRENGTH := {LowHullEffect.Level.LOW: 0.45, LowHullEffect.Level.CRITICAL: 1.0}
## Matches HullSegmentBar so the rim and the bar breathe together.
const PULSE_HZ := {LowHullEffect.Level.LOW: 1.2, LowHullEffect.Level.CRITICAL: 2.6}
## How much of the alarm survives over something the player has to read.
const UI_RELIEF := 0.0

var _rect: ColorRect
var _material: ShaderMaterial
var _level := LowHullEffect.Level.OK
var _alarm: float = 0.0
var _hit: float = 0.0

func _ready() -> void:
	add_to_group("hull_alarm")
	add_to_group("screen_effects")
	layer = LAYER
	# Menus pause the tree; the overlay still has to ease itself out of the way.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_material = ShaderMaterial.new()
	_material.shader = load("res://scenes/HullAlarm.gdshader")
	_material.set_shader_parameter("alarm_color", Colors.DANGER)
	_material.set_shader_parameter("hit_color", Colors.CREAM)

	_rect = ColorRect.new()
	_rect.color = Color(1, 1, 1, 1)  # the shader supplies the color; this is just the canvas
	_rect.material = _material
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

	EventBus.ship_hull_changed.connect(_on_hull_changed)
	EventBus.ship_damaged.connect(_on_ship_damaged)
	EventBus.ship_respawned.connect(_on_respawned)

	get_viewport().size_changed.connect(_fit)
	_fit()

func _fit() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.y <= 0.0:
		return
	_material.set_shader_parameter("half_extent", Vector2(0.5 * size.x / size.y, 0.5))

func _on_hull_changed(current: float, max_hull: float) -> void:
	_level = LowHullEffect.level_for(current, max_hull)

func _on_ship_damaged(amount: float, hull_ratio: float) -> void:
	# The same weighting the dashboard glitch uses, so one hit reads as one event.
	var weight := clampf(amount / Ship.DAMAGE_REFERENCE, 0.3, 1.0)
	var desperation := 1.0 + (1.0 - clampf(hull_ratio, 0.0, 1.0)) * 0.5
	_hit = maxf(_hit, clampf(weight * desperation, 0.0, 1.0))

func _on_respawned() -> void:
	_level = LowHullEffect.Level.OK
	_alarm = 0.0
	_hit = 0.0

func _process(delta: float) -> void:
	var relief := UI_RELIEF if _something_to_read() else 1.0
	var target: float = STRENGTH.get(_level, 0.0) * relief
	_alarm = _ease(_alarm, target, delta)
	_hit = maxf(_hit - HIT_DECAY * delta, 0.0) * relief

	visible = _alarm > 0.002 or _hit > 0.002
	if not visible:
		return
	_material.set_shader_parameter("alarm", _alarm)
	_material.set_shader_parameter("hit", _hit)
	_material.set_shader_parameter("pulse", _pulse())

## Gone at once, not eased out: a relaunch or a load boots onto a clean screen.
func clear_now() -> void:
	_level = LowHullEffect.Level.OK
	_alarm = 0.0
	_hit = 0.0
	visible = false

func _ease(current: float, target: float, delta: float) -> float:
	var speed := RISE_SPEED if target > current else FALL_SPEED
	return move_toward(current, target, speed * delta)

## 0..1 on the wall clock, in step with HullSegmentBar._pulse().
func _pulse() -> float:
	if _level == LowHullEffect.Level.OK:
		return 1.0
	var hz: float = PULSE_HZ[_level]
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * hz)

## Something the player has to be able to read: the chart, a menu, the store, or a
## transmission holding the game. The hull isn't getting any worse while they read it.
func _something_to_read() -> bool:
	if RobotRadio.is_pausing():
		return true
	for group in ["system_map", "pause_menu", "log_ui", "store_ui"]:
		var panel := get_tree().get_first_node_in_group(group) as CanvasItem
		if panel and panel.visible:
			return true
	return false
