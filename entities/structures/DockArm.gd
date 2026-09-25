extends Polygon2D
class_name DockArm

## SR-7's refuel boom and the dock at its head (docs/OPENING.md §3, §5). A new game finds
## it retracted: run back inside the belly module, out of sight, so the station has no dock
## at all and the ship wakes adrift beside it. It stays in until every piece of SR-7 is home.
## Then, on the core's standby battery (the same battery lighting the bay's aux strips,
## CoreHousing), it unlatches with a clunk, runs out along its track, locks with another,
## and the dock's lamps catch: the first thing on the station that invites the ship in.
##
## The node is the arm's track: a mask (`clip_children`) the boom and the port slide out
## through, so they emerge from the hull rather than appearing over it. `Slide` carries both,
## and the boom's own collision, and sits `STOWED_X` in while retracted - where nothing of it
## draws, collides, or offers DOCK (SpacePort.deployed).
##
## Whether it is out is the world's state, never saved on its own: the station whole, or the
## core already running (a dev skip, a playtest).

## A live extension has run to the end: the arm is locked out and the dock's lamps are lit.
signal extended

## How far in the slide sits when retracted, px: far enough that the port at its head is
## wholly behind the mask's edge.
const STOWED_X := -300.0
## The beat after the last piece goes home before the arm moves, s: long enough for the
## bay's aux strips to catch first, so the battery is seen to come up before it is used.
const DEPLOY_DELAY := 2.2
## The unlatch: a short shudder a few px out before the run.
const UNLATCH_TIME := 0.45
const UNLATCH_PX := 10.0
## The run out along the track, s.
const EXTEND_TIME := 3.4
## A beat between the lock and the lamps catching, s.
const LAMP_DELAY := 0.5
## Where the clunks land, in the track's space: where the boom leaves the hull, and the head.
const ROOT_POINT := Vector2(128.0, 100.0)
const HEAD_POINT := Vector2(370.0, 100.0)

@export var port: NodePath

var out := false
var _slide: Node2D
var _extending := false

func _ready() -> void:
	add_to_group("dock_arms")
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_slide = get_node("Slide") as Node2D
	EventBus.planets_restored.connect(refresh)
	EventBus.section_seated.connect(_on_section_seated)
	EventBus.core_started.connect(refresh)
	refresh.call_deferred()

## Whether SR-7's arm belongs out in the game `gs` describes.
static func should_be_out(gs: GameState) -> bool:
	return gs != null and (gs.station_whole() or gs.core_started)

func get_port() -> SpacePort:
	return get_node_or_null(port) as SpacePort

func is_extending() -> bool:
	return _extending

## Match the game's state, instantly: a load, a new game.
func refresh() -> void:
	if _extending:
		return
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	_set_out(should_be_out(gs))

## The last piece going home runs the arm out while the player watches.
func _on_section_seated(_id: String) -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if not out and not _extending and should_be_out(gs):
		extend()

## Run the arm out: unlatch, run, lock, lamps.
func extend() -> void:
	if out or _extending:
		return
	_extending = true
	await get_tree().create_timer(DEPLOY_DELAY, false).timeout
	Mount.clunk(self, ROOT_POINT)
	var unlatch := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	unlatch.tween_property(_slide, "position:x", STOWED_X + UNLATCH_PX, UNLATCH_TIME)
	await unlatch.finished
	var run := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	run.tween_property(_slide, "position:x", 0.0, EXTEND_TIME)
	await run.finished
	Mount.clunk(self, HEAD_POINT)
	_set_out(true, false)
	_extending = false
	await get_tree().create_timer(LAMP_DELAY, false).timeout
	var p := get_port()
	if p and out:
		p.set_lit(true)
	extended.emit()

## Out or in, snapped. The lamps come on with it unless `lamps` is false (a live run lights
## them itself, a beat after the lock).
func _set_out(on: bool, lamps := true) -> void:
	out = on
	_slide.position.x = 0.0 if on else STOWED_X
	_set_solid(on)
	var p := get_port()
	if p:
		p.deployed = on
		if lamps or not on:
			p.set_lit(on)

## Retracted, nothing on the slide collides or senses a ship: it is all inside the hull.
func _set_solid(on: bool) -> void:
	for shape in _slide.find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred("disabled", not on)
	for shape in _slide.find_children("*", "CollisionPolygon2D", true, false):
		shape.set_deferred("disabled", not on)
