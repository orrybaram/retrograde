extends Node2D
class_name CoreHousing

## SR-7's core, in its housing at the middle of the station (docs/OPENING.md §5): the end of
## Act 1. It is dark, and seated wrong - a previous clone unseated it by hand - and the
## placard on its housing is the game's first Procedure: SEAT·1, CYCLE·1, commit.
##
## - Until every piece of SR-7 is home it is dead: no answer to anything, and no bar.
## - Whole, it listens (group `procedure_listeners`): one standby lamp blinks on the housing,
##   the only light on the station; a Sweep that reaches it gets a cold thump back; and a
##   ship close by sees the placard (PlacardPanel) and the RESONANCE bar (Resonance).
## - A Commit of the wrong Marks thumps, and lights one segment on the housing per Mark in
##   its right place - how wrong, never where (docs/SWEEP.md §7).
## - The right Marks cold-start it: the core swings square in its housing with the seating
##   clunk (SEAT), turns over and catches (CYCLE), and the power comes up from it
##   (StationPower). Once the dish is on the Sun, UNIT-7 comes on the comms
##   (RobotRadio.wake_guide). The started state is GameState.core_started.

const PROCEDURE: ProcedureDef = preload("res://entities/procedure/sr7_core.tres")

## Where the unseated core sits off true in its housing, px.
const UNSEATED_OFFSET := Vector2(-7.0, 9.0)
## Cold start pacing, s: the core seating, the beat before it turns over, and the catch.
const SEAT_TIME := 0.5
const CYCLE_DELAY := 0.9
const CATCH_TIME := 1.4
## A near miss's segments stay lit this long, s.
const SEGMENT_HOLD := 1.8
## The core's own glow once running, and its radius (px).
const GLOW_RADIUS := 34.0
## The standby lamp: where on the housing, how big, and how slowly it blinks.
const STANDBY_AT := Vector2(96.0, -54.0)
const STANDBY_SIZE := 5.0
const STANDBY_PERIOD := 3.2
## The segments along the foot of the housing, one per Mark of the Procedure.
const SEGMENT_Y := 56.0
const SEGMENT_SIZE := Vector2(14.0, 4.0)
const SEGMENT_GAP := 20.0

## The core itself, which moves in its housing (Visuals/CentralCore/D1).
@export var core: NodePath

var started := false
var _starting := false
var _whole := false
var _lit := 0.0
var _clock := 0.0
var _segments_lit := 0
var _segment_time := 0.0

func _ready() -> void:
	z_index = 2  # over the station's Visuals
	add_to_group("core_housing")
	add_to_group("sonar_listeners")
	add_to_group("procedure_listeners")
	EventBus.planets_restored.connect(refresh)
	EventBus.section_seated.connect(func(_id: String) -> void: refresh())
	refresh.call_deferred()

## Whether every piece of SR-7 is home: the three Sections and the nudged wing.
static func is_whole(gs: GameState) -> bool:
	if gs == null:
		return false
	for id in Sections.DATA.keys() + [Sections.SOLAR_ARRAY_2]:
		if not gs.is_section_seated(id):
			return false
	return true

## Match the game's state: a load or a new game snaps it, seated or not.
func refresh() -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	_whole = is_whole(gs)
	if _starting:
		return
	started = gs != null and gs.core_started
	_lit = 1.0 if started else 0.0
	var disc := get_node_or_null(core) as Node2D
	if disc:
		disc.position = Vector2.ZERO if started else UNSEATED_OFFSET
	queue_redraw()

## Listening for a Procedure: the station whole, the core still cold.
func listens() -> bool:
	return _whole and not started and not _starting

## What its placard prints (PlacardPanel).
func placard() -> ProcedureDef:
	return PROCEDURE

func procedure_point() -> Vector2:
	return global_position

func sonar_point() -> Vector2:
	return global_position

## An ordinary Sweep: a cold thump if it is listening, nothing if it is dead or running.
func on_sonar_touched(_strength := 1.0) -> void:
	if listens():
		_thump(0)

## A Commit reached it.
func on_procedure(marks: Array) -> void:
	if not listens():
		return
	var result := PROCEDURE.check(marks)
	if result.ok:
		cold_start()
	else:
		_thump(result.right)

func segments_lit() -> int:
	return _segments_lit if _segment_time > 0.0 else 0

func is_starting() -> bool:
	return _starting

## Wrong, or just a Sweep: one dull ring off the housing, and `right` segments lit a while.
func _thump(right: int) -> void:
	_segments_lit = right
	_segment_time = SEGMENT_HOLD
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	var station := get_parent() as RigidBody2D
	var velocity := station.linear_velocity if station else Vector2.ZERO
	HarvestJuice.ring(ship.get_parent() if ship else get_parent(), global_position, Color(Colors.PRIMARY_DIM, 0.8), 90.0, velocity)
	queue_redraw()

## SEAT·1, CYCLE·1: it seats, turns over and catches, and the station comes up from it.
func cold_start() -> void:
	_starting = true
	_segment_time = 0.0
	var disc := get_node_or_null(core) as Node2D
	var seat := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if disc:
		seat.tween_property(disc, "position", Vector2.ZERO, SEAT_TIME)
	else:
		seat.tween_interval(SEAT_TIME)
	await seat.finished
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
	if _segment_time > 0.0:
		_segment_time -= delta
	if _whole or _lit > 0.0:
		queue_redraw()

func _draw() -> void:
	if _lit > 0.0:
		# Turning over, it stutters before it holds
		var on := _lit >= 1.0 or fmod(_clock, 0.14) > 0.05 * (1.0 - _lit)
		var a := _lit * (0.85 + 0.15 * sin(_clock * 1.7)) if on else _lit * 0.3
		draw_circle(Vector2.ZERO, GLOW_RADIUS * 2.2, Color(Colors.SUN, 0.06 * a))
		draw_circle(Vector2.ZERO, GLOW_RADIUS * 1.3, Color(Colors.SUN, 0.14 * a))
		draw_circle(Vector2.ZERO, GLOW_RADIUS * 0.9, Color(Colors.CREAM, 0.75 * a))
	if not _whole or started:
		return
	var count := PROCEDURE.marks().size()
	var left := -(count - 1) * SEGMENT_GAP * 0.5
	for i in count:
		var at := Vector2(left + i * SEGMENT_GAP, SEGMENT_Y) - SEGMENT_SIZE * 0.5
		var lit := i < segments_lit()
		draw_rect(Rect2(at, SEGMENT_SIZE), Colors.PRIMARY if lit else Colors.PRIMARY_DIM)
	if _starting:
		return
	# A slow breath, never quite out: on battery, the one light on the station
	var glow := 0.5 - 0.5 * cos(_clock / STANDBY_PERIOD * TAU)
	draw_circle(STANDBY_AT, STANDBY_SIZE * 3.5, Color(Colors.PRIMARY, 0.18 * glow))
	draw_circle(STANDBY_AT, STANDBY_SIZE, Colors.PRIMARY_DIM.lerp(Colors.PRIMARY, glow))
