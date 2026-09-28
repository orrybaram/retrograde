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
const MSG_NO_HOLD := preload("res://entities/Robot/radio/messages/first_no_hold.tres")
const MSG_CARGO_BAY_FITTED := preload("res://entities/Robot/radio/messages/cargo_bay_fitted.tres")
const MSG_FIRST_TRANSIT := preload("res://entities/Robot/radio/messages/first_transit.tres")
const MSG_SHIP_DESTROYED := preload("res://entities/Robot/radio/messages/ship_destroyed.tres")
const MSG_VOID_CONSUMED := preload("res://entities/Robot/radio/messages/void_consumed.tres")

var queue := RadioQueue.new()
## Save file the show-once flags are written into. Empty keeps them in memory only, so a
## radio in a test never touches a save file; Main points the game's at the save.
var save_path := ""

## UNIT-7 is off when the game opens (docs/OPENING.md §5): the station is dead and nobody
## is on the comms. Until the core's cold start at the end of Act 1 reboots it, every
## call - tips, alarms, the Void, a lost ship - is dropped (request() refuses them), and
## MSG_WAKE is the first thing it says. The radio is the comms system to reuse.
## The core's cold start sets it (wake_guide); a load sets it from the ledger (CORE_STARTED).
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
	EventBus.scrap_swept.connect(_on_scrap_swept)
	EventBus.component_fitted.connect(check_fitted)
	EventBus.ship_respawned.connect(_bind_ship)
	# Hull comes off the bus, not off _bind_ship: it has to be heard on whichever ship
	# is flying, including one that respawned before the binding caught up.
	EventBus.ship_hull_changed.connect(check_hull)

## Queues a conversation. Show-once conversations already seen are dropped, and so is
## everything while UNIT-7 is still off.
## Tips go on air the moment they're triggered, even mid-flight: RadioPanel keeps a
## held or mashed SPACE from dismissing a line that just appeared.
func request(conv: RadioConversation) -> RadioQueue.Result:
	if conv == null or not guide_awake:
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
## never empty (docs/GLOSSARY.md, docs/adr/0003). Marked in the Progress ledger like a named
## Gate is, which writes it through - the first transmission comes long before any dock.
func _mark_guide_met() -> void:
	if not is_inside_tree():
		return
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.progress.mark(Progress.MET_AUTOMATONS, Automatons.GUIDE.record_key())

## SR-7's core has caught and the power is up (CoreHousing): UNIT-7 comes on the comms
## for the first time, and from here its tips and alarms are live.
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
	_write_seen()

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
	_write_seen()
	silence()
	watch_for_boost()

## Into the save at `save_path`, when there is one to write to.
func _write_seen() -> void:
	if save_path != "":
		Save.save_radio_seen(seen_ids(), save_path)

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
	ship.drive.changed.connect(func() -> void: check_fuel(ship.drive.fuel, ship.drive.max_fuel))
	ship.cargo_changed.connect(check_cargo)

## Starts the boost clock for a session. Nothing happens if the hint is already spent.
func watch_for_boost() -> void:
	_played = 0.0
	_watching_boost = not has_seen(MSG_BOOST_HINT.id)

## Pausable, so time spent reading a transmission or sitting in a menu doesn't count.
func _process(delta: float) -> void:
	if not _watching_boost or _ship == null:
		return
	# Lit, not just held: a boost tried on a dry tank or cut by a cough hasn't shown the
	# player what the Burn does, so the hint still has something to teach
	tick_boost_watch(delta, _ship.drive.is_lit(),
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
	# A docked ship is filling up, not running dry: a relaunched clone comes up on a low
	# tank at the dock, and that is no moment for the low-fuel briefing.
	if is_instance_valid(_ship) and _ship.state_machine and _ship.state_machine.current_state is LandedState:
		return
	if guide_awake and max_fuel > 0.0 and Drive.level_for(fuel, max_fuel) != Drive.Level.OK:
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
	check_scrap(can_harvest, cargo_bay_fitted())

## The cutting tutorial waits for the first scrap the ship can actually cut, which is only
## ever after the Cargo Bay is fitted (docs/OPENING.md §9).
func check_scrap(can_harvest: bool, fitted: bool) -> void:
	if guide_awake and can_harvest and fitted:
		request(MSG_SCRAP)

func _on_scrap_swept() -> void:
	check_swept_scrap(cargo_bay_fitted())

## A Sweep found scrap and the ship has nowhere to put it: UNIT-7 names the need, never
## the place (docs/OPENING.md §9). It sincerely does not know where a hold is (ADR 0008).
func check_swept_scrap(fitted: bool) -> void:
	if guide_awake and not fitted:
		request(MSG_NO_HOLD)

## UNIT-7 fits what the player brought home to SR-7's Cradle, and says so.
func check_fitted(id: String) -> void:
	if guide_awake and id == Components.CARGO_BAY:
		request(MSG_CARGO_BAY_FITTED)

## The Cargo Bay is the ship's: there is a hold, and scrap can be cut.
func cargo_bay_fitted() -> bool:
	if not is_inside_tree():
		return false
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	return gs != null and gs.progress.holds(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)
