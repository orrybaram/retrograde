extends Area2D
class_name HarvestCone

## Cone-shaped harvest detection area mounted on the ship.
## Ship faces RIGHT (+X) in local space, so the cone points right.
## Multiple scraps in the cone harvest simultaneously.
## Visual (pulsing amber) is visible only while actively harvesting.

@export var cone_length: float = 200.0
@export var cone_angle_degrees: float = 60.0

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var visual_polygon: Polygon2D = $VisualPolygon

var _scraps_in_cone: Array[ScrapNode] = []
var _pulse_tween: Tween = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	visual_polygon.visible = false


func set_harvesting(active: bool) -> void:
	visual_polygon.visible = active
	if active:
		_start_pulse()
	else:
		_stop_pulse()

func _start_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(visual_polygon, "modulate:a", 0.4, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(visual_polygon, "modulate:a", 0.1, 0.7).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	visual_polygon.modulate.a = 0.15

func has_scrap(scrap: ScrapNode) -> bool:
	return _scraps_in_cone.has(scrap)

func get_scraps_in_cone() -> Array[ScrapNode]:
	return _scraps_in_cone.duplicate()

func _on_area_entered(area: Area2D) -> void:
	if not area is ScrapNode:
		return
	var scrap := area as ScrapNode
	if scrap._is_depleted:
		return
	if not _scraps_in_cone.has(scrap):
		_scraps_in_cone.append(scrap)

	var ship: Ship = get_parent() as Ship
	if not ship:
		return
	scrap._ship_in_range = ship
	if scrap._state_machine and scrap._state_machine.get_current_state_name() == "ScrapIdleState":
		scrap._state_machine.change_state("ScrapInRangeState")

func _on_area_exited(area: Area2D) -> void:
	if not area is ScrapNode:
		return
	var scrap := area as ScrapNode
	_scraps_in_cone.erase(scrap)

	# Lock persists during active harvesting — don't interrupt
	if scrap._state_machine and scrap._state_machine.current_state is ScrapHarvestingState:
		return

	scrap._ship_in_range = null
	if scrap._state_machine:
		var state_name := scrap._state_machine.get_current_state_name()
		if state_name == "ScrapInRangeState":
			scrap._state_machine.change_state("ScrapIdleState")
