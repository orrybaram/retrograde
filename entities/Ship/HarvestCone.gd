extends Area2D
class_name HarvestCone

## Harvest detection area mounted on the ship: a circle centred on the hull, so scrap
## is reachable from any heading (the name is historical). Radius lives on the
## CircleShape2D in HarvestCone.tscn. The nearest live scrap in range answers the press.

@export var radius: float = 60.0:
	set(value):
		radius = value
		_apply_radius()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _scraps_in_cone: Array[ScrapNode] = []

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_apply_radius()

func _apply_radius() -> void:
	if collision_shape and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = radius


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
