extends Node2D
class_name Cradle

## SR-7's Cradle (docs/adr/0012, docs/OPENING.md §9): the place a Component delivered as
## Freight is released, to be fitted from the station's menus once the player docks. It is
## slung under the refuel boom's root: a frame hanging off the boom's underside, closed at
## the hull end and open outboard, so a piece is pushed in from the right, under the dock's
## head, and let go of.
##
## Seating works as a Mount's does: released within Mount.SEAT_RANGE px and
## Mount.SEAT_ANGLE of the Cradle's pose, either way round, the piece is pulled home over
## Mount.SEAT_TIME with a clunk. Unlike a Section it does not become the station: it stays
## in the Cradle, as itself, until it is fitted. Which Component is in it lives in
## GameState.cradled, and the piece shown there is rebuilt from that on every load.
##
## The frame hangs off the arm, so it is only there while the arm is out (DockArm): a
## retracted arm has no Cradle, and takes nothing. Its end plate and floor are solid - part
## of the station's own body - so a piece pushed in stops against the plate, in the seat,
## rather than sailing through into the hull.

## Where the boom's underside is, in the Cradle's space: the hangers run up to it.
const BOOM_Y := -70.0
## The frame, in the Cradle's space, around a piece the Cargo Bay's size: the saddle bar
## over it, the end plate at the hull end, and the floor it rests on.
const SADDLE_Y := -36.0
const FLOOR_Y := 36.0
const END_X := -66.0
const OPEN_X := 52.0
const HANGER_XS := [-44.0, 22.0]
const BAR := 5.0

@export var arm: NodePath

## The Component sitting in the Cradle, as itself: out of the Freight group (it is the
## station's now, not something to mark or save), out of physics.
var piece: Freight = null
var _arm: DockArm
var _tracking: NodeTrackingTarget
var _seating: Tween
## The end plate's and floor's collision, on the station's body.
var _stops: Array[CollisionPolygon2D] = []

func _ready() -> void:
	add_to_group("cradles")
	z_index = 1
	_arm = get_node_or_null(arm) as DockArm
	EventBus.planets_restored.connect(refresh)
	refresh.call_deferred()
	_add_stops.call_deferred()

## SR-7's Cradle in `tree`, or null.
static func find(tree: SceneTree) -> Cradle:
	return tree.get_first_node_in_group("cradles") as Cradle

## The Cradle `f` would seat in if let go of right now, or null.
static func accepting(tree: SceneTree, f: Freight) -> Cradle:
	if f == null or f.component == "":
		return null
	var c := find(tree)
	return c if c and c.fits(f) else null

## Whether the arm is out, so the Cradle hangs off it at all.
func is_deployed() -> bool:
	return _arm == null or _arm.out

## Whether `f` is a Component, the Cradle is out and empty, and the piece is close enough
## in place and turn to be pulled home.
func fits(f: Freight) -> bool:
	return is_deployed() and not is_full() and f != null and f.component != "" \
		and Mount.matching_seat(f.global_transform, seats()) >= 0

## Something is in it, or on its way in. (GameState.cradled says the same for saving.)
func is_full() -> bool:
	return piece != null and is_instance_valid(piece)

## The poses a piece can be pulled home into, in world space: Lug outboard (the way a
## pushed piece arrives, and how a loaded one is shown), and turned end for end.
func seats() -> Array[Transform2D]:
	return [global_transform * Transform2D(PI, Vector2.ZERO), global_transform]

func tracking_target() -> NodeTrackingTarget:
	if _tracking == null:
		_tracking = NodeTrackingTarget.new(self, "CRADLE", 60.0)
	return _tracking

## Pull `f` home and keep it. `f` has just been let go of, within tolerance.
func seat(f: Freight) -> void:
	if f == null or is_full():
		return
	var gs := _game_state()
	if gs:
		gs.cradled = f.component
		Save.save_cradled(f.component)
	_hold(f)
	var poses := seats()
	var home := poses[maxi(Mount.matching_seat(f.global_transform, poses), 0)]
	f.reparent(self, true)
	NavSystem.clear()
	_seating = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_seating.tween_property(f, "transform", global_transform.affine_inverse() * home, Mount.SEAT_TIME)
	_seating.tween_callback(func() -> void:
		Mount.clunk(self)
		f.punch(0.1))

## Whether docking at `port` puts the ship alongside this Cradle: `port` is on SR-7.
func serves(port: Node) -> bool:
	return port != null and get_parent() != null and get_parent().is_ancestor_of(port)

## Fit what is in the Cradle to the ship (docs/OPENING.md §9): the Component is the ship's
## now, not the Cradle's, and the Cradle is empty again. The Cargo Bay makes the hold.
## Returns the Component fitted, or "" with nothing to fit.
func fit() -> String:
	var gs := _game_state()
	if gs == null or gs.cradled == "":
		return ""
	var id := gs.cradled
	gs.mark_fitted(id)
	gs.cradled = ""
	Save.save_fitted(PackedStringArray(gs.fitted.keys()))
	refresh()
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship:
		ship.refit(gs)
	return id

func is_seating() -> bool:
	return _seating != null and _seating.is_running()

## Match the saved or new game: the Component the save has in the Cradle, sitting in it,
## or nothing. Runs on every new game and load (planets_restored).
func refresh() -> void:
	var gs := _game_state()
	var id := gs.cradled if gs else ""
	if piece and is_instance_valid(piece) and piece.component == id:
		return
	if piece and is_instance_valid(piece):
		piece.queue_free()
	piece = null
	if id == "" or not Components.exists(id):
		return
	var f := Freight.new()
	Components.apply(f, id)
	add_child(f)
	f.transform = Transform2D(PI, Vector2.ZERO)
	_hold(f)

## Take `f` out of the world's Freight: no saves, marks or Sweep answers, no physics.
func _hold(f: Freight) -> void:
	piece = f
	f.handled = false
	f.lodged = false
	f.lodged_in = null
	f.remove_from_group("freight")
	f.remove_from_group("sonar_listeners")
	f.process_mode = Node.PROCESS_MODE_DISABLED

## The arm is run out live, snapped out on a load, or pulled in on a new game: follow it.
func _process(_delta: float) -> void:
	_update_shown()

func _update_shown() -> void:
	var on := is_deployed()
	if visible == on:
		return
	visible = on
	for stop in _stops:
		stop.set_deferred("disabled", not on)

## The solid parts of the frame - the end plate and the floor - as shapes on the station's
## body, in the Cradle's place on it.
func _add_stops() -> void:
	var body := get_parent() as CollisionObject2D
	if body == null:
		return
	for r: Rect2 in stop_rects():
		var stop := CollisionPolygon2D.new()
		stop.name = "CradleStop"
		stop.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		stop.transform = transform
		stop.disabled = not visible
		body.add_child(stop)
		_stops.append(stop)

## The end plate and the floor, in the Cradle's space.
static func stop_rects() -> Array[Rect2]:
	return [
		Rect2(END_X - BAR, SADDLE_Y - BAR, BAR, FLOOR_Y - SADDLE_Y + BAR * 2.0),
		Rect2(END_X, FLOOR_Y, OPEN_X - END_X, BAR),
	]

func _game_state() -> GameState:
	return get_tree().get_first_node_in_group("game_state") as GameState if is_inside_tree() else null

## The frame: two hangers down from the boom to a saddle bar, an end plate at the hull
## end, and the floor, left open outboard.
func _draw() -> void:
	for x: float in HANGER_XS:
		_bar(Vector2(x - BAR * 0.5, BOOM_Y), Vector2(x + BAR * 0.5, SADDLE_Y))
	_bar(Vector2(END_X, SADDLE_Y - BAR), Vector2(OPEN_X - 18.0, SADDLE_Y))
	for r: Rect2 in stop_rects():
		_bar(r.position, r.end)
	# Pads the piece rests on, and a stop at the floor's open end to catch its corner
	for x: float in [-40.0, -8.0, 24.0]:
		draw_rect(Rect2(x, FLOOR_Y - 2.0, 10.0, 2.0), Colors.HULL_LIGHT)
	draw_rect(Rect2(OPEN_X - 3.0, FLOOR_Y - 3.0, 3.0, 3.0), Colors.HULL_LIGHT)

func _bar(from: Vector2, to: Vector2) -> void:
	var r := Rect2(from, to - from).abs()
	draw_rect(r, Colors.HULL_MID)
	draw_rect(r, Colors.HULL_LIGHT, false, 1.0)
