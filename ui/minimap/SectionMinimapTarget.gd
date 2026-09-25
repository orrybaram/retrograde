extends MinimapTarget
class_name SectionMinimapTarget

## MinimapTarget for a piece of SR-7 not yet back in its Mount (docs/OPENING.md §4): a
## ping, so the beam finding it sends a ring out from it, where solid things only echo. Held
## on the rim when out of range, so it gives the bearing. Gone once the piece is seated, and
## while the ship has it clamped (it is right there on the nose).

var mount: Mount
var _section: Freight = null

func _init(m: Mount) -> void:
	mount = m

func _piece() -> Freight:
	if _section == null or not is_instance_valid(_section) or _section.is_queued_for_deletion():
		_section = mount._find_section() if mount and is_instance_valid(mount) else null
	return _section

func get_minimap_position() -> Vector2:
	var f := _piece()
	return f.global_position if f else Vector2.ZERO

func is_ping() -> bool:
	return true

func is_minimap_visible() -> bool:
	if mount == null or not is_instance_valid(mount) or mount.seated:
		return false
	var f := _piece()
	return f != null and not f.is_clamped()

func get_minimap_node() -> Node2D:
	return _piece()

func pins_to_edge() -> bool:
	return true
