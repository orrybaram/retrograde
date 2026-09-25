extends MinimapTarget
class_name SectionMinimapTarget

## MinimapTarget for a piece of SR-7 not yet back in its Mount (docs/OPENING.md §4): a faint
## ring breathing out on the minimap, roughly where the piece is. Only roughly - the pulse
## sits a fixed distance off the piece, in a direction set by its id, so it says *over
## here somewhere* and the Sweep still does the finding. Held on the rim when the piece is
## out of range, so it also gives the bearing. Gone once the piece is seated, and while
## the ship has it clamped (it is right there on the nose).

## How far off the piece the pulse sits, world px: about one Sweep's reach.
const FUZZ := 520.0
## One breath out, s, and how far the ring grows, minimap px.
const PERIOD := 2.6
const RING_MIN := 2.0
const RING_MAX := 11.0
const ALPHA := 0.35

var mount: Mount
var _section: Freight = null
var _offset := Vector2.ZERO
var _phase := 0.0

func _init(m: Mount) -> void:
	mount = m
	var h := hash(m.section)
	_offset = Vector2.from_angle(float(h % 3600) / 3600.0 * TAU) * FUZZ
	_phase = float((h / 3600) % 100) / 100.0 * PERIOD

func _piece() -> Freight:
	if _section == null or not is_instance_valid(_section) or _section.is_queued_for_deletion():
		_section = mount._find_section() if mount and is_instance_valid(mount) else null
	return _section

func get_minimap_position() -> Vector2:
	var f := _piece()
	return f.global_position + _offset if f else Vector2.ZERO

func get_minimap_color() -> Color:
	return Colors.PRIMARY

func get_minimap_size() -> float:
	return RING_MAX

func get_minimap_priority() -> int:
	return 5  # under everything solid

func is_minimap_visible() -> bool:
	if mount == null or not is_instance_valid(mount) or mount.seated:
		return false
	var f := _piece()
	return f != null and not f.is_clamped()

func get_minimap_node() -> Node2D:
	return _piece()

func pins_to_edge() -> bool:
	return true

func draw_marker(map: Minimap, pos: Vector2, _size: float, _view_rotation: float) -> void:
	var t := fmod(Minimap.now() + _phase, PERIOD) / PERIOD
	var r := lerpf(RING_MIN, RING_MAX, t)
	var a := ALPHA * (1.0 - t)
	map.draw_arc(pos, r, 0.0, TAU, 24, Color(Colors.PRIMARY, a), 1.0, true)
	map.draw_circle(pos, 1.0, Color(Colors.PRIMARY, ALPHA * 0.5))
