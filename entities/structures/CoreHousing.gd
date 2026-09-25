extends Node2D
class_name CoreHousing

## SR-7's core, in the hull section at the middle of the station (docs/OPENING.md §5): the
## end of Act 1. It is not a component in a housing - it is a recessed bay of window slots
## set in ordinary hull, drawn the way StationLights draws every other window on SR-7.
##
## - Until every piece of SR-7 is home it is dead: no answer to anything.
## - Whole, it comes to standby. The last piece going home brings the bay's **auxiliary
##   lighting** up while the player watches - two strips along the lip of the recess,
##   catching with the same stutter as every other light on SR-7, and the only light on the
##   station until the wake. They are not a marker: a panel on standby has lit its own
##   working area. The same battery runs the dock's arm out (DockArm). A Sweep that reaches
##   the core gets a cold thump back.
## - It is rebooted from the dock's terminal (CoreTerminal), not from out here: `reboot`.
##   The seating clunk lands (SEAT - heard, never seen; the row stays as crooked as whoever
##   left it), it turns over and the slots catch outward (CYCLE), and the power comes up
##   from here (StationPower). Once the dish is on the Sun, UNIT-7 comes on the comms
##   (RobotRadio.wake_guide). The started state is GameState.core_started.

## Cold start pacing, s: the beat before the clunk lands, the beat after it, and the catch.
const SEAT_TIME := 0.5
const CYCLE_DELAY := 0.9
const CATCH_TIME := 1.4

## The bay's auxiliary lighting: two strips along the lip of the recess, running off the
## core's own standby battery. Not a marker and not addressed to the player - a panel that
## has come to standby lighting its own working area. They catch the way every other light
## on SR-7 catches (StationLights.WAKE_FLICKER), and they stay on afterwards, because
## service lighting does not switch off.
const AUX_DELAY := 0.8
const AUX_FLICKER := 0.45
const STRIP_INSET := Vector2(6.0, 3.5)
const STRIP_HEIGHT := 1.6
const STRIP_SPILL := 7.0
## How much light reaches the back of the recess. Deliberately almost nothing: the strips
## are bright, the bay is not, and the slots have to be *barely* visible - five dark
## notches in a box that is only just lifted off the hull, never a readout on a screen.
const BAY_WASH := 0.05
const SPILL_ALPHA := 0.09

## The bay recessed into the hull, and the slots set in it: four, then a fifth, wider and
## set apart.
const BAY := Rect2(-97.0, -20.0, 194.0, 40.0)
const SLOT_SIZE := Vector2(20.0, 12.0)
const WIDE_SIZE := Vector2(30.0, 12.0)
const SLOT_X: Array[float] = [-75.0, -43.0, -11.0, 21.0, 70.0]
## How far each slot sits out of true. Nobody straightens these and the cold start does not
## undo them: the row was refitted in a hurry by whoever took SR-7 apart, and the station
## keeps its scars the way the cracked vat and the tally scratched beside it do
## (docs/OPENING.md §2, "Why it is broken" - clued, never stated).
const SLOT_KINK: Array[Vector2] = [
	Vector2(-3.2, -4.0), Vector2(-1.6, 7.0), Vector2(0.0, -4.0),
	Vector2(1.6, 7.0), Vector2(3.2, -4.0),
]

var started := false
var _starting := false
var _whole := false
var _lit := 0.0
var _clock := 0.0
## Seconds until the bay's aux strips hold; 0 once they are on.
var _aux_time := 0.0

func _ready() -> void:
	z_index = 2  # over the station's Visuals
	add_to_group("core_housing")
	add_to_group("sonar_listeners")
	EventBus.planets_restored.connect(refresh)
	EventBus.section_seated.connect(_on_section_seated)
	refresh.call_deferred()

## The last piece going home is what brings the bay's lights up, so the player watches them
## catch. A load or a new game snaps them instead (refresh).
func _on_section_seated(_id: String) -> void:
	var was_whole := _whole
	refresh()
	if _whole and not was_whole:
		_aux_time = AUX_DELAY

## Whether every piece of SR-7 is home: the three Sections and the nudged wing.
static func is_whole(gs: GameState) -> bool:
	return gs != null and gs.station_whole()

## Match the game's state: a load or a new game snaps it, seated or not.
func refresh() -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	_whole = is_whole(gs)
	if _starting:
		return
	started = gs != null and gs.core_started
	_lit = 1.0 if started else 0.0
	_aux_time = 0.0
	queue_redraw()

## On standby: the station whole, the core still cold. A reboot takes now.
func listens() -> bool:
	return _whole and not started and not _starting

func sonar_point() -> Vector2:
	return global_position

## An ordinary Sweep: a dull ring off the hull if it is on standby, nothing if it is dead
## or running.
func on_sonar_touched(_strength := 1.0) -> void:
	if listens():
		_ring()

func is_starting() -> bool:
	return _starting

## One dull ring off the hull.
func _ring() -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	var station := get_parent() as RigidBody2D
	var velocity := station.linear_velocity if station else Vector2.ZERO
	HarvestJuice.ring(ship.get_parent() if ship else get_parent(), global_position, Color(Colors.PRIMARY_DIM, 0.8), 90.0, velocity)

## The dock's terminal asked for it (CoreTerminal). Nothing happens unless it is on standby.
func reboot() -> bool:
	if not listens():
		return false
	cold_start()
	return true

## SEAT·1, CYCLE·1: the clunk lands, it turns over and catches, and the station comes up.
func cold_start() -> void:
	_starting = true
	# SEAT is heard, not seen: the clunk and the shake, and nothing on the hull moves.
	await get_tree().create_timer(SEAT_TIME, false).timeout
	Mount.clunk(self)
	await get_tree().create_timer(CYCLE_DELAY, false).timeout
	var catch := create_tween()
	catch.tween_property(self, "_lit", 1.0, CATCH_TIME)
	await catch.finished
	started = true
	_starting = false
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.core_started = true
		Save.save_core_started(true)
	EventBus.core_started.emit()
	var power := get_parent().get_node_or_null("StationPower") as StationPower
	if power:
		await power.woken
	RobotRadio.wake_guide()

func _process(delta: float) -> void:
	_clock += delta
	if _aux_time > 0.0:
		_aux_time = maxf(0.0, _aux_time - delta)
	if _whole or _lit > 0.0:
		queue_redraw()

## How brightly the bay's aux strips are burning, 0-1: out until the station is whole, then
## stuttering for a moment before they hold.
func aux_level() -> float:
	if not _whole:
		return 0.0
	if _aux_time <= 0.0:
		return 1.0
	if _aux_time < AUX_FLICKER:
		return 1.0 if fmod(_aux_time, 0.1) < 0.05 else 0.12
	return 0.0

## How brightly each slot is showing, 0-1: dark until the core catches, then turning over
## outward, stuttering before they hold.
func _slot_light() -> Array[float]:
	var out: Array[float] = []
	out.resize(SLOT_X.size())
	out.fill(0.0)
	if _lit <= 0.0:
		return out
	for i in out.size():
		var t := clampf((_lit - i * 0.09) * 2.2, 0.0, 1.0)
		var steady := t >= 1.0 or fmod(_clock * 7.0 + i, 1.0) > 0.45
		out[i] = t * (0.85 + 0.15 * sin(_clock * 1.7)) if steady else t * 0.3
	return out

func _draw() -> void:
	# The bay is hull detail: there from the first second of the game, dark and unremarkable
	draw_rect(BAY, Colors.HULL_DARK)
	draw_rect(BAY.grow(-2.0), Colors.SPACE_BG)
	if _lit > 0.0:
		draw_rect(BAY.grow(8.0), Color(Colors.SUN, 0.05 * _lit))
	_draw_aux(aux_level())
	var light := _slot_light()
	for i in SLOT_X.size():
		var size := WIDE_SIZE if i == SLOT_X.size() - 1 else SLOT_SIZE
		var at := Vector2(SLOT_X[i], 0.0) + SLOT_KINK[i]
		_draw_slot(Rect2(at - size * 0.5, size), light[i])

## The two strips along the lip, and the little light that reaches past them. The strips are
## bright; the recess behind them barely lifts, so the dark slots read as notches and
## nothing more.
func _draw_aux(a: float) -> void:
	if a <= 0.0:
		return
	var inner := BAY.grow(-2.0)
	draw_rect(inner, Color(Colors.SUN, BAY_WASH * a))
	var x := BAY.position.x + STRIP_INSET.x
	var w := BAY.size.x - STRIP_INSET.x * 2.0
	var top := BAY.position.y + STRIP_INSET.y
	var bottom := BAY.end.y - STRIP_INSET.y - STRIP_HEIGHT
	# spill inward off each strip
	draw_rect(Rect2(x, top, w, STRIP_SPILL), Color(Colors.SUN, SPILL_ALPHA * a))
	draw_rect(Rect2(x, bottom + STRIP_HEIGHT - STRIP_SPILL, w, STRIP_SPILL), Color(Colors.SUN, SPILL_ALPHA * a))
	draw_rect(Rect2(x, top, w, STRIP_HEIGHT), Color(Colors.SUN, 0.9 * a))
	draw_rect(Rect2(x, bottom, w, STRIP_HEIGHT), Color(Colors.SUN, 0.9 * a))

## One slot, exactly as StationLights._draw lights a window.
func _draw_slot(r: Rect2, a: float) -> void:
	if a <= 0.0:
		draw_rect(r, Colors.SPACE_BG)
		return
	draw_rect(r.grow(4.0), Color(Colors.SUN, 0.08 * a))
	draw_rect(r.grow(1.5), Color(Colors.SUN, 0.2 * a))
	draw_rect(r, Color(Colors.SUN, 0.9 * a))
