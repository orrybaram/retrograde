extends MinimapTarget
class_name HaulerWreckMinimapTarget

## MinimapTarget for the hauler down on Veld (HaulerWreck): nothing on the scope until SR-7's
## dish comes back on the air and its great ping reaches the wreck, then a ping held on the
## rim so it gives the bearing - something out there answered. Gone once the ship has flown
## close enough to name it: it has been investigated.

var wreck: HaulerWreck

func _init(w: HaulerWreck) -> void:
	wreck = w

func get_minimap_position() -> Vector2:
	return wreck.global_position if _alive() else Vector2.ZERO

func is_ping() -> bool:
	return true

func is_minimap_visible() -> bool:
	return _alive() and wreck.heard and not wreck.is_identified()

func get_minimap_node() -> Node2D:
	return wreck if _alive() else null

func pins_to_edge() -> bool:
	return true

func _alive() -> bool:
	return wreck != null and is_instance_valid(wreck)
