extends MinimapTarget
class_name GateMinimapTarget

## MinimapTarget for a Gate: a ring the shape of the thing itself. Dormant it is dark
## hull with the blinker still going round; powered it carries the Titan's purple.
## Deliberately does NOT pin to the rim: the minimap shows what is in scanner range and
## no more, so a Gate has to be flown to rather than pointed at (docs/adr/0002).

const SIZE := 6.0

var gate: Gate

func _init(g: Gate) -> void:
	gate = g

func get_minimap_position() -> Vector2:
	if gate and is_instance_valid(gate):
		return gate.global_position
	return Vector2.ZERO

func get_minimap_color() -> Color:
	return Colors.TITAN if _powered() else Colors.HULL_LIGHT

func get_minimap_size() -> float:
	return SIZE

func get_minimap_priority() -> int:
	return 55

func is_minimap_visible() -> bool:
	return gate != null and is_instance_valid(gate)

func get_minimap_node() -> Node2D:
	return gate

func draw_marker(map: Minimap, pos: Vector2, size: float, _view_rotation: float) -> void:
	var color := get_minimap_color()
	map.draw_arc(pos, size, 0.0, TAU, 20, color, 1.6)
	if _powered():
		map.draw_arc(pos, size + 2.0, 0.0, TAU, 20, Color(Colors.TITAN, 0.35), 1.0)
		return
	# The blinker still turning over out there
	var lit := fmod(Minimap.now(), Gate.BLINK_PERIOD) < Gate.BLINK_PERIOD * Gate.BLINK_DUTY
	map.draw_circle(pos, 1.8, Colors.PRIMARY if lit else Color(Colors.PRIMARY, 0.25))

func _powered() -> bool:
	return gate != null and is_instance_valid(gate) and gate.is_powered()
