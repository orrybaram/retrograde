extends Node2D
class_name CommDish

## SR-7's comm dish, on its post below the keel. The station never turns, but it goes round
## the Sun, so the dish swings to keep its bowl on the Sun. Its local +x is the way the bowl faces.

func _process(_delta: float) -> void:
	global_rotation = (VoidZone.sun_position() - global_position).angle()
