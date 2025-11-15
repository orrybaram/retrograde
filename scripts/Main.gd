extends Node2D

@onready var ship := $Ship
@onready var tick := $TickTimer

func _ready() -> void:
	tick.timeout.connect(_on_tick)

func _on_tick() -> void:
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if ship.global_position.distance_to(node.global_position) < 32 and ship.grounded:
			node.start_harvest()
		else:
			node.stop_harvest()
