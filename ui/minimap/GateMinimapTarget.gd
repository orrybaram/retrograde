extends MinimapTarget
class_name GateMinimapTarget

## MinimapTarget for a Gate: the same glyph the system map draws — the Gate seen from
## above, a ring with the cradle's mouth left open in it. Dormant it is dark hull with
## the blinker still going round; powered it carries the Titan's purple.
## Deliberately does NOT pin to the rim: the minimap shows what is in scanner range and
## no more, so a Gate has to be flown to rather than pointed at (docs/adr/0002).
##
## Unlabelled: the glyph is the name. Nothing on the minimap spells out what it is.

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

func draw_marker(map: Minimap, pos: Vector2, size: float, view_rotation: float) -> void:
	var color := get_minimap_color()
	# The mouth faces the way the Gate itself faces, so the glyph reads like the thing
	var start := PI / 2.0 + Gate.MOUTH_ANGLE / 2.0 + gate.global_rotation + view_rotation
	var span := TAU - Gate.MOUTH_ANGLE
	map.draw_arc(pos, size + 2.0, start, start + span, 24, Color(color, 0.18), 3.0, true)
	map.draw_arc(pos, size, start, start + span, 24, Color(color, 0.9), 1.4, true)
	if _powered():
		map.draw_circle(pos, 1.4, color)
		return
	# The blinker still turning over out there
	var lit := fmod(Minimap.now(), Gate.BLINK_PERIOD) < Gate.BLINK_PERIOD * Gate.BLINK_DUTY
	map.draw_circle(pos, 1.4, Colors.PRIMARY if lit else Color(Colors.PRIMARY, 0.25))

func _powered() -> bool:
	return gate != null and is_instance_valid(gate) and gate.is_powered()
