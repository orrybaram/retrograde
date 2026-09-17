class_name RadioQueue
extends RefCounted

## Which transmission is on air and what's waiting. Pending conversations are
## ordered by priority, first-come first-served within a priority.

enum Result { STARTED, INTERRUPTED, QUEUED, DUPLICATE, REJECTED }

const MAX_PENDING := 8

var current: RadioConversation = null
var line_index := 0
var _pending: Array[RadioConversation] = []

func push(conv: RadioConversation) -> Result:
	if conv == null or conv.lines.is_empty():
		return Result.REJECTED
	if has(conv):
		return Result.DUPLICATE
	if current == null:
		_start(conv)
		return Result.STARTED
	if conv.priority > current.priority:
		# The interrupted one goes back to the front of its priority and replays from the top.
		_insert(current, true)
		_start(conv)
		return Result.INTERRUPTED
	if _pending.size() >= MAX_PENDING:
		return Result.REJECTED
	_insert(conv, false)
	return Result.QUEUED

## Moves to the next line, or the next conversation once this one is done.
## Returns the new current line, or null when the radio goes quiet.
func advance() -> RadioLine:
	if current == null:
		return null
	line_index += 1
	if line_index >= current.lines.size():
		current = null
		line_index = 0
		if not _pending.is_empty():
			_start(_pending.pop_front())
	return current_line()

func current_line() -> RadioLine:
	if current == null:
		return null
	return current.lines[line_index]

func is_active() -> bool:
	return current != null

func pending_count() -> int:
	return _pending.size()

func has(conv: RadioConversation) -> bool:
	if _same(current, conv):
		return true
	return _pending.any(func(c: RadioConversation) -> bool: return _same(c, conv))

func clear() -> void:
	current = null
	line_index = 0
	_pending.clear()

func _start(conv: RadioConversation) -> void:
	current = conv
	line_index = 0

func _insert(conv: RadioConversation, ahead_of_equals: bool) -> void:
	var i := 0
	while i < _pending.size():
		var p := _pending[i].priority
		if p < conv.priority or (ahead_of_equals and p == conv.priority):
			break
		i += 1
	_pending.insert(i, conv)

static func _same(a: RadioConversation, b: RadioConversation) -> bool:
	if a == null or b == null:
		return false
	if a == b:
		return true
	return a.id != &"" and a.id == b.id
