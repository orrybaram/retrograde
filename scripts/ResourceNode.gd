extends Area2D
class_name ResourceNode

@export var kind: String = "Basalt"
@export var amount: int = 10
@export var harvest_rate: float = 5.0

var _harvesting: bool = false
var _accum: float = 0.0

func _ready() -> void:
	add_to_group("resource_nodes")

func start_harvest() -> void:
	_harvesting = true

func stop_harvest() -> void:
	_harvesting = false

func _process(dt: float) -> void:
	if not _harvesting or amount <= 0:
		return
	_accum += harvest_rate * dt
	if _accum >= 1.0:
		var chunk = int(_accum)
		_accum -= float(chunk)
		var take = min(chunk, amount)
		amount -= take
		var gs := get_tree().get_first_node_in_group("game_state") as Node
		if gs and "add_cargo" in gs:
			gs.add_cargo(kind, take)
	if amount <= 0:
		queue_free()
