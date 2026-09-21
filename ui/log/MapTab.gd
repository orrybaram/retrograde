class_name MapTab
extends LogTab

## The Log's star chart: the SystemMap filling the tab body, frame and all. "M" opens
## the Log straight onto it (see Main). The chart keeps its own keys; the Log only
## carries them in its bottom border.

const SYSTEM_MAP_SCENE := preload("res://ui/system_map/SystemMap.tscn")

var map: SystemMap


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map = SYSTEM_MAP_SCENE.instantiate() as SystemMap
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(map)


func tab_title() -> String:
	return "MAP"


func hint() -> String:
	return map.hint_text() + "   " + SHELL_KEYS


## Every chart key goes to the chart, the arrows included: they drive the mark.
func handle_key(keycode: int) -> bool:
	return map.handle_key(keycode)


func on_shown() -> void:
	map.open_map()


func on_hidden() -> void:
	map.close_map()
