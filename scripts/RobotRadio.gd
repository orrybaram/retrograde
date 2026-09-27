extends Node

## The guide robot's radio. Owns the transmission queue and show-once flags,
## and turns game events into help messages. RadioPanel (HUD) displays the
## current line and calls advance() when it is dismissed, or confirm() on a
## confirm line. A conversation with `pause_game` pauses the tree while on air.
##
## Anything can radio the player with
##   EventBus.radio_message_requested.emit(conversation)
## and react to a confirm line via `confirmed`.

signal line_started(line: RadioLine, conversation: RadioConversation)
## The radio went quiet (last line dismissed, or reset).
signal transmission_ended
## The player accepted the confirm line of conversation `id`.
signal confirmed(id: StringName)

## The Guide's designation; the same one its Record is filed under in the Log
## (Automatons.GUIDE, docs/DESIGN.md 5.3).
const SPEAKER_NAME := "UNIT-7"

const MSG_WAKE := preload("res://entities/Robot/radio/messages/first_wake.tres")

var queue := RadioQueue.new()
## Save file for show-once flags; empty uses the game save (Playtest.save_path()).
var save_path := ""
## Off in tests so flags never touch a save file.
var persist := true

## UNIT-7 is off when the game opens (docs/OPENING.md §5): the station is dead and nobody
## is on the comms. Its one call is MSG_WAKE, when SR-7's core catches in Act 1; every
## other tip, alarm and game-over call is disconnected. The radio itself is the comms
## system to reuse (EventBus.radio_message_requested).
## The core's cold start sets it (wake_guide); a load sets it from GameState.core_started.
var guide_awake := false

var _seen: Dictionary = {}  # StringName -> true
var _pausing := false  # this radio paused the tree
var _pause_started := 0.0

func _ready() -> void:
	EventBus.radio_message_requested.connect(request)

## Queues a conversation. Show-once conversations already seen are dropped.
## Tips go on air the moment they're triggered, even mid-flight: RadioPanel keeps a
## held or mashed SPACE from dismissing a line that just appeared.
func request(conv: RadioConversation) -> RadioQueue.Result:
	if conv == null:
		return RadioQueue.Result.REJECTED
	if conv.once and has_seen(conv.id):
		return RadioQueue.Result.REJECTED
	return _push(conv)

func _push(conv: RadioConversation) -> RadioQueue.Result:
	var result := queue.push(conv)
	if conv.once and result in [RadioQueue.Result.STARTED, RadioQueue.Result.INTERRUPTED, RadioQueue.Result.QUEUED]:
		mark_seen(conv.id)
	if result == RadioQueue.Result.STARTED or result == RadioQueue.Result.INTERRUPTED:
		_mark_guide_met()
		_sync_pause()
		line_started.emit(queue.current_line(), queue.current)
	return result

## Dismisses the current line and plays the next one, if any.
## Confirm lines only end through confirm().
func advance() -> void:
	if not queue.is_active() or queue.current_line().is_confirm():
		return
	var line := queue.advance()
	_sync_pause()
	if line:
		line_started.emit(line, queue.current)
	else:
		transmission_ended.emit()

## Accepts the current confirm line. A confirm always changes the game state, so
## the radio goes quiet (dropping anything queued) before `confirmed` fires.
func confirm() -> void:
	var line := queue.current_line()
	if line == null or not line.is_confirm():
		return
	var id := queue.current.id
	queue.clear()
	_sync_pause()
	transmission_ended.emit()
	confirmed.emit(id)

func current_line() -> RadioLine:
	return queue.current_line()

func is_active() -> bool:
	return queue.is_active()

## True while an on-air conversation holds the game paused.
func is_pausing() -> bool:
	return _pausing

## `after_key_press` delays the unpause (see _release_pause); code-driven
## changes like silence() unpause right away so a menu can re-pause after.
func _sync_pause(after_key_press: bool = true) -> void:
	var want := queue.is_active() and queue.current.pause_game
	if want == _pausing:
		return
	_pausing = want
	if not is_inside_tree():
		return
	if want:
		_pause_started = Time.get_ticks_msec() / 1000.0
		get_tree().paused = true
	elif after_key_press:
		_release_pause()
	else:
		_unpause()

## Unpauses once the frame of the key press that closed the transmission has passed,
## so gameplay doesn't also read that SPACE as a just-pressed action (dock, harvest).
func _release_pause() -> void:
	for i in 2:
		await get_tree().physics_frame
	if not _pausing:  # unless another pausing transmission started meanwhile
		_unpause()

func _unpause() -> void:
	get_tree().paused = false
	EventBus.game_unpaused.emit(Time.get_ticks_msec() / 1000.0 - _pause_started)

## The radio is a link to UNIT-7 at SR-7, so a transmission going on air is the player
## meeting the Guide: from the first one they hold its Record, and the Records tab is
## never empty (docs/GLOSSARY.md, docs/adr/0003). Written straight into the save like a named
## Gate is — the first transmission happens docked at SR-7, long before the next dock.
func _mark_guide_met() -> void:
	if not is_inside_tree():
		return
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	var designation := Automatons.GUIDE.record_key()
	if gs == null or gs.has_met_automaton(designation):
		return
	gs.mark_automaton_met(designation)
	if persist:
		Save.save_met_automatons(PackedStringArray(gs.met_automatons.keys()), save_path)

## SR-7's core has caught and the power is up (CoreHousing): UNIT-7 comes on the comms
## for the first time. It is the only call UNIT-7 makes.
func wake_guide() -> void:
	guide_awake = true
	request(MSG_WAKE)

# --- Show-once flags -----------------------------------------------------------

func has_seen(id: StringName) -> bool:
	return _seen.has(id)

func mark_seen(id: StringName) -> void:
	if id == &"" or _seen.has(id):
		return
	_seen[id] = true
	if persist:
		Save.save_radio_seen(seen_ids(), save_path)

func seen_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in _seen:
		ids.append(str(id))
	return ids

## Replaces the flags with ones loaded from a save; drops anything on air.
func load_seen(ids: PackedStringArray) -> void:
	_seen.clear()
	for id in ids:
		_seen[StringName(id)] = true
	silence()

## New game: every tip plays again.
func reset() -> void:
	_seen.clear()
	if persist:
		Save.save_radio_seen(seen_ids(), save_path)
	silence()

func silence() -> void:
	var was_active := queue.is_active()
	queue.clear()
	_sync_pause(false)
	if was_active:
		transmission_ended.emit()
