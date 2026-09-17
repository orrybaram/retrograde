extends Node

## The guide robot's radio. Owns the transmission queue and show-once flags,
## and turns game events into help messages. RadioPanel (HUD) displays the
## current line and calls advance() when it is dismissed.
##
## Anything can radio the player with
##   EventBus.radio_message_requested.emit(conversation)

signal line_started(line: RadioLine, conversation: RadioConversation)
## The radio went quiet (last line dismissed, or reset).
signal transmission_ended

## Placeholder until the guide gets a name (docs/DESIGN.md 5.3).
const SPEAKER_NAME := "UNIT-7"

const MSG_DEPARTURE := preload("res://entities/Robot/radio/messages/first_departure.tres")
const MSG_LOW_FUEL := preload("res://entities/Robot/radio/messages/first_low_fuel.tres")
const MSG_CARGO_FULL := preload("res://entities/Robot/radio/messages/first_cargo_full.tres")
const MSG_SCRAP := preload("res://entities/Robot/radio/messages/first_scrap.tres")

var queue := RadioQueue.new()
## Save file for show-once flags; empty uses the game save (Playtest.save_path()).
var save_path := ""
## Off in tests so flags never touch a save file.
var persist := true

var _seen: Dictionary = {}  # StringName -> true
var _ship: Ship = null

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
		line_started.emit(queue.current_line(), queue.current)
	return result

## Dismisses the current line and plays the next one, if any.
func advance() -> void:
	if not queue.is_active():
		return
	var line := queue.advance()
	if line:
		line_started.emit(line, queue.current)
	else:
		transmission_ended.emit()

func current_line() -> RadioLine:
	return queue.current_line()

func is_active() -> bool:
	return queue.is_active()

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
