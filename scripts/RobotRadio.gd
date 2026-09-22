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
const MSG_BOOST_HINT := preload("res://entities/Robot/radio/messages/boost_hint.tres")
const MSG_LOW_FUEL := preload("res://entities/Robot/radio/messages/first_low_fuel.tres")
const MSG_LOW_HULL := preload("res://entities/Robot/radio/messages/first_low_hull.tres")
const MSG_HULL_CRITICAL := preload("res://entities/Robot/radio/messages/hull_critical.tres")
const MSG_CARGO_FULL := preload("res://entities/Robot/radio/messages/first_cargo_full.tres")
const MSG_SCRAP := preload("res://entities/Robot/radio/messages/first_scrap.tres")
const MSG_SCANNER := preload("res://entities/Robot/radio/messages/scanner_bought.tres")
const MSG_FIRST_TRANSIT := preload("res://entities/Robot/radio/messages/first_transit.tres")
const MSG_OUT_OF_FUEL := preload("res://entities/Robot/radio/messages/out_of_fuel.tres")
const MSG_OUT_OF_FUEL_BEAM := preload("res://entities/Robot/radio/messages/out_of_fuel_beam.tres")
const MSG_SHIP_DESTROYED := preload("res://entities/Robot/radio/messages/ship_destroyed.tres")
const MSG_SHIP_ABANDONED := preload("res://entities/Robot/radio/messages/ship_abandoned.tres")
const MSG_TRACTOR_RESCUE := preload("res://entities/Robot/radio/messages/tractor_rescue.tres")
const MSG_VOID_CONSUMED := preload("res://entities/Robot/radio/messages/void_consumed.tres")

var queue := RadioQueue.new()
## Save file for show-once flags; empty uses the game save (Playtest.save_path()).
var save_path := ""
## Off in tests so flags never touch a save file.
var persist := true

## UNIT-7 is off when the game opens (docs/OPENING.md §5): the station is dead and nobody
## is on the comms. Until it wakes, its tutorial tips and alarms stay parked - the
## triggers below drop them - and MSG_WAKE is never sent. The radio itself still carries
## the calls the game needs (relaunch, tow, the Void), and is the comms system to reuse.
## Nothing sets this yet: the core's cold start will.
var guide_awake := false

## Nothing teaches boosting any more — the wake-up call is story, not controls. If the
## player hasn't found it after this much play, the guide mentions it.
const BOOST_HINT_AFTER := 300.0

var _seen: Dictionary = {}  # StringName -> true
var _ship: Ship = null
var _pausing := false  # this radio paused the tree
var _pause_started := 0.0
var _played := 0.0  # seconds of unpaused play since the session began
var _watching_boost := false

func _ready() -> void:
	EventBus.radio_message_requested.connect(request)
	EventBus.harvest_available_changed.connect(_on_harvest_available_changed)
	EventBus.ship_respawned.connect(_bind_ship)
	# Hull comes off the bus, not off _bind_ship: it has to be heard on whichever ship
	# is flying, including one that respawned before the binding caught up.
	EventBus.ship_hull_changed.connect(check_hull)

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
## never empty (CONTEXT.md, docs/adr/0003). Written straight into the save like a named
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
	watch_for_boost()

## New game: every tip plays again.
func reset() -> void:
	_seen.clear()
	if persist:
		Save.save_radio_seen(seen_ids(), save_path)
	silence()
	watch_for_boost()

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
	check_undock(from, to, _has_planet_scanner())

## The scanner briefing waits for the undock after the purchase: the store menu is no
## place for it, and a planet is where the thing gets used. Show-once, so it lands on
## the first departure with the array aboard and never again. Taking off from a planet
## isn't an undock (PlanetLandedState), so it can't fire there.
func check_undock(from: State, to: State, has_scanner: bool) -> void:
	if guide_awake and has_scanner and from is LandedState and to is FlyingState:
		request(MSG_SCANNER)

func _has_planet_scanner() -> bool:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	return gs != null and gs.has_planet_scanner

## Starts the boost clock for a session. Nothing happens if the hint is already spent.
func watch_for_boost() -> void:
	_played = 0.0
	_watching_boost = not has_seen(MSG_BOOST_HINT.id)

## Pausable, so time spent reading a transmission or sitting in a menu doesn't count.
func _process(delta: float) -> void:
	if not _watching_boost or _ship == null:
		return
	tick_boost_watch(delta, _ship.want_boost and _ship.want_thrust,
			_ship.state_machine.current_state is FlyingState)

## One step of the boost clock, taken apart from the ship so it can be driven directly.
## The hint is held back until the player is actually flying, so it doesn't cut across
## a dock or a seam.
func tick_boost_watch(delta: float, boosting: bool, flying: bool) -> void:
	if not _watching_boost or not guide_awake:
		return
	if boosting:
		_watching_boost = false  # they worked it out on their own
		return
	_played += delta
	if _played >= BOOST_HINT_AFTER and flying:
		_watching_boost = false
		request(MSG_BOOST_HINT)

func check_fuel(fuel: float, max_fuel: float) -> void:
	if guide_awake and max_fuel > 0.0 and LowFuelEffect.level_for(fuel, max_fuel) != LowFuelEffect.Level.OK:
		request(MSG_LOW_FUEL)

## Two steps, both show-once: the first venting gets the full briefing with the game
## held, and dropping into the red gets a single line that does NOT pause — being
## frozen mid-fight one hit from death would be a worse warning than no warning.
func check_hull(hull: float, max_hull: float) -> void:
	# A hull at zero is a destroyed ship, and MSG_SHIP_DESTROYED has that conversation.
	if not guide_awake or max_hull <= 0.0 or hull <= 0.0:
		return
	match LowHullEffect.level_for(hull, max_hull):
		LowHullEffect.Level.CRITICAL:
			request(MSG_LOW_HULL)
			request(MSG_HULL_CRITICAL)
		LowHullEffect.Level.LOW:
			request(MSG_LOW_HULL)
		_:
			pass

func check_cargo(weight: float, max_weight: float) -> void:
	if guide_awake and max_weight > 0.0 and weight >= max_weight:
		request(MSG_CARGO_FULL)

func _on_harvest_available_changed(can_harvest: bool) -> void:
	if guide_awake and can_harvest:
		request(MSG_SCRAP)
