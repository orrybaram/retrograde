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

## Placeholder until the guide gets a name (docs/DESIGN.md 5.3).
const SPEAKER_NAME := "UNIT-7"

const MSG_DEPARTURE := preload("res://entities/Robot/radio/messages/first_departure.tres")
const MSG_LOW_FUEL := preload("res://entities/Robot/radio/messages/first_low_fuel.tres")
const MSG_CARGO_FULL := preload("res://entities/Robot/radio/messages/first_cargo_full.tres")
const MSG_SCRAP := preload("res://entities/Robot/radio/messages/first_scrap.tres")
const MSG_OUT_OF_FUEL := preload("res://entities/Robot/radio/messages/out_of_fuel.tres")
const MSG_OUT_OF_FUEL_BEAM := preload("res://entities/Robot/radio/messages/out_of_fuel_beam.tres")
const MSG_SHIP_DESTROYED := preload("res://entities/Robot/radio/messages/ship_destroyed.tres")
const MSG_SHIP_ABANDONED := preload("res://entities/Robot/radio/messages/ship_abandoned.tres")
const MSG_TRACTOR_RESCUE := preload("res://entities/Robot/radio/messages/tractor_rescue.tres")

var queue := RadioQueue.new()
## Save file for show-once flags; empty uses the game save (Playtest.save_path()).
var save_path := ""
## Off in tests so flags never touch a save file.
var persist := true

var _seen: Dictionary = {}  # StringName -> true
var _ship: Ship = null
var _pausing := false  # this radio paused the tree
var _pause_started := 0.0

func _ready() -> void:
	EventBus.radio_message_requested.connect(request)
	EventBus.harvest_available_changed.connect(_on_harvest_available_changed)
	EventBus.ship_respawned.connect(_bind_ship)

## Queues a conversation. Show-once conversations already seen are dropped.
func request(conv: RadioConversation) -> RadioQueue.Result:
	if conv == null:
		return RadioQueue.Result.REJECTED
	if conv.once and has_seen(conv.id):
		return RadioQueue.Result.REJECTED
	var result := queue.push(conv)
	if conv.once and result in [RadioQueue.Result.STARTED, RadioQueue.Result.INTERRUPTED, RadioQueue.Result.QUEUED]:
		mark_seen(conv.id)
	if result == RadioQueue.Result.STARTED or result == RadioQueue.Result.INTERRUPTED:
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

# --- Triggers ------------------------------------------------------------------

func _bind_ship() -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == _ship or ship == null:
		return
	_ship = ship
	ship.fuel_changed.connect(func() -> void: check_fuel(ship.fuel, ship.max_fuel))
	ship.cargo_changed.connect(check_cargo)
	ship.state_machine.state_changed.connect(on_ship_state_changed)

func on_ship_state_changed(from: State, to: State) -> void:
	if from is LandedState and to is FlyingState:
		request(MSG_DEPARTURE)

func check_fuel(fuel: float, max_fuel: float) -> void:
	if max_fuel > 0.0 and LowFuelEffect.level_for(fuel, max_fuel) != LowFuelEffect.Level.OK:
		request(MSG_LOW_FUEL)

func check_cargo(weight: float, max_weight: float) -> void:
	if max_weight > 0.0 and weight >= max_weight:
		request(MSG_CARGO_FULL)

func _on_harvest_available_changed(can_harvest: bool) -> void:
	if can_harvest:
		request(MSG_SCRAP)
