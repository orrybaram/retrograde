extends Node
class_name InputUtils

## Utility functions for input handling.

static func get_action_key_name(action: String) -> String:
	# Get the readable name for an input action's first key binding.
	# Returns the key name (e.g., "Space", "Enter") or fallback text.
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		var event = events[0]
		if event is InputEventKey:
			var key_event = event as InputEventKey
			# Try keycode first, fall back to physical_keycode if keycode is 0
			var keycode = key_event.keycode
			if keycode == 0:
				keycode = key_event.physical_keycode
			
			# Convert keycode to readable name
			var key_name = OS.get_keycode_string(keycode)
			return key_name
		elif event is InputEventMouseButton:
			return "Mouse Button"
	return action  # Fallback to action name
