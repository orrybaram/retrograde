class_name RadioConversation
extends Resource

## A radio transmission: lines played in order. A higher-priority conversation
## interrupts a lower one; the interrupted one replays afterwards.

enum Priority { CHATTER, HINT, WARNING, URGENT }

## Stable key for show-once tracking and de-duplication.
@export var id: StringName
@export var priority: Priority = Priority.HINT
## Only ever plays once per save.
@export var once: bool = false
@export var lines: Array[RadioLine] = []

static func make(conv_id: StringName, conv_lines: Array[RadioLine], conv_priority: Priority = Priority.HINT, show_once: bool = false) -> RadioConversation:
	var conv := RadioConversation.new()
	conv.id = conv_id
	conv.lines = conv_lines
	conv.priority = conv_priority
	conv.once = show_once
	return conv
