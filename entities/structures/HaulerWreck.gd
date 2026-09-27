extends Node2D
class_name HaulerWreck

## The crashed hauler on Veld (docs/OPENING.md §9): a long freighter broken in two across
## the planet's ground, and between the halves, standing Lug-up out of the dirt where it
## was torn from the spine, its hold - the Cargo Bay, the first Component. The wreck is
## only looks; the Cargo Bay is Freight like any other, buried (Freight.bury_in) so it
## takes the Burn to tear free (Components.CARGO_BAY).
##
## A child of its planet, placed on the ground at `ground_angle_degrees` from the planet's
## centre; its own -Y points up out of the ground. It draws under the planet's disc, so
## whatever of it is below the ground line is simply not seen.

## How much of the Cargo Bay stands out of the ground (px, along its length): the Lug end
## and a good part of the box, enough to read as something that was never ground.
const BAY_EXPOSED := 70.0
## How far off straight up it leans (radians).
const BAY_LEAN := 0.12

## Unidentified until flown to (docs/GLOSSARY.md, Identifiable): once SR-7's cold start has
## UNIT-7 awake to look, the ship coming within Identifiable.RANGE gets it named, flatly.
const NAME := "HAULER, DOWN"
const MSG_IDENTIFIED := preload("res://entities/Robot/radio/messages/hauler_identified.tres")

## SR-7's dish ping at the cold start (CommDish.ping) reaching the wreck puts it on the
## minimap as a ping (HaulerWreckMinimapTarget) until it has been identified.

## Where on the planet it lies: degrees round from the planet's +X.
@export var ground_angle_degrees := 205.0
@export var component := Components.CARGO_BAY

## The two halves of the hull, in the wreck's space (-Y up, the ground line at y = 0):
## the aft section lying on its side, the bow nosed into the ground.
const AFT := [
	Vector2(-230, 14), Vector2(-226, -26), Vector2(-196, -44), Vector2(-92, -52),
	Vector2(-70, -46), Vector2(-60, -30), Vector2(-66, -18), Vector2(-54, -6), Vector2(-58, 14),
]
const BOW := [
	Vector2(56, 14), Vector2(50, -8), Vector2(62, -20), Vector2(56, -34), Vector2(74, -42),
	Vector2(150, -34), Vector2(206, -16), Vector2(232, 14),
]
## Frames across each half (x positions), and the loose plates thrown clear of the crash.
const AFT_RIBS := [-200.0, -170.0, -140.0, -110.0, -84.0]
const BOW_RIBS := [86.0, 116.0, 146.0, 176.0]
const PLATES := [
	[Vector2(-30, -2), Vector2(-18, -10), Vector2(-10, -4), Vector2(-20, 2)],
	[Vector2(26, 0), Vector2(36, -8), Vector2(44, -2)],
	[Vector2(252, 2), Vector2(266, -6), Vector2(276, 0), Vector2(262, 4)],
	[Vector2(-268, 2), Vector2(-256, -8), Vector2(-246, -2)],
]

var planet: Planet
## Off in tests so naming the wreck never touches a save file (Gate does the same).
var persist := true
## The dish's ping has reached it: it pings on the minimap until it is identified.
var heard := false
var _ship: Node2D = null
var _minimap_target: HaulerWreckMinimapTarget = null

func _ready() -> void:
	add_to_group("hauler_wrecks")
	add_to_group("dish_listeners")
	planet = get_parent() as Planet
	z_index = 0  # under the planet's disc (PlanetVisual is 1): below ground is hidden
	if planet:
		var dir := Vector2.from_angle(deg_to_rad(ground_angle_degrees))
		position = dir * Mount.ground_radius(planet)
		rotation = dir.angle() + PI * 0.5
	EventBus.planets_restored.connect(ensure_cargo_bay)
	EventBus.planets_restored.connect(_restore_heard)
	queue_redraw()
	_register_with_minimap.call_deferred()

func _register_with_minimap() -> void:
	var minimap := Minimap.get_instance(get_tree())
	if minimap:
		_minimap_target = HaulerWreckMinimapTarget.new(self)
		minimap.register_target(_minimap_target)

func _exit_tree() -> void:
	if _minimap_target:
		var minimap := Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(_minimap_target)
		_minimap_target = null

## SR-7's dish ping has reached the wreck (CommDish.ping).
func on_dish_ping() -> void:
	heard = true

## A load or a new game: the dish has already pinged if the core is running (a load skips
## the wake, so no ping will come to set it).
func _restore_heard() -> void:
	var gs := _game_state()
	heard = gs != null and gs.core_started

## The hauler wreck in `tree`, or null.
static func find(tree: SceneTree) -> HaulerWreck:
	return tree.get_first_node_in_group("hauler_wrecks") as HaulerWreck

## Named in the save under its planet: one hauler per Body.
func save_key() -> String:
	return "hauler_" + planet.save_key() if planet else ""

## True once UNIT-7 has named it.
func is_identified() -> bool:
	var gs := _game_state()
	return gs != null and gs.is_wreck_identified(save_key())

## Names the wreck (MSG_IDENTIFIED). Nobody can make it out before the cold start: UNIT-7
## is dark until then. Returns true when this call is what identified it.
func identify() -> bool:
	var gs := _game_state()
	var key := save_key()
	if gs == null or key == "" or not gs.core_started or gs.is_wreck_identified(key):
		return false
	gs.mark_wreck_identified(key)
	EventBus.radio_message_requested.emit(MSG_IDENTIFIED)
	if persist:
		Save.save_identified_wrecks(PackedStringArray(gs.identified_wrecks.keys()))
	return true

## Identifies the wreck once the ship is close enough to make it out, and not before.
func identify_if_near(ship_position: Vector2) -> bool:
	if is_identified() or not Identifiable.in_range(ship_position, global_position):
		return false
	return identify()

## The only trigger for identification: the player flying within reach of it.
func _process(_delta: float) -> void:
	if is_identified():
		return
	if not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("ship") as Node2D
	if is_instance_valid(_ship):
		identify_if_near(_ship.global_position)

func _game_state() -> GameState:
	return get_tree().get_first_node_in_group("game_state") as GameState if is_inside_tree() else null

## Straight up out of the ground here, in the planet's frame.
func up() -> Vector2:
	return Vector2.UP.rotated(rotation)

## The Cargo Bay is never lost: while no piece of it is anywhere in the world (a new game,
## or a save from before it), it is put back buried in the wreck. A piece put back from a
## save still buried is buried again, as hard as ever. Once it is in SR-7's Cradle it is
## home, and no copy is left out here - nor once it is fitted. Runs on every new game and load.
func ensure_cargo_bay() -> void:
	if planet == null:
		return
	var piece := find_piece()
	var gs := _game_state()
	if gs and (component in gs.cradled or gs.is_fitted(component)):
		if piece:  # already home: a stale copy must not linger
			piece.remove_from_group("freight")
			piece.queue_free()
		return
	if piece == null:
		var world := get_tree().get_first_node_in_group("ship")
		world = world.get_parent() if world else planet.get_parent()
		var offset := bay_offset()
		piece = Freight.new()
		Components.apply(piece, component)
		world.add_child(piece)
		piece.global_position = planet.to_global(offset)
		# Standing out of the ground, Lug end up
		piece.global_rotation = planet.global_rotation + offset.angle() + PI + BAY_LEAN
		piece.lodge_in(planet, offset)
		piece.bury_in(planet, Components.pull_threshold(component))
	elif piece.lodged:
		piece.lodge_in(planet, piece.lodged_offset, piece.lodged_spin)
		if piece.is_buried():
			piece.bury_in(planet, Components.pull_threshold(component))

## Where a new game's Cargo Bay stands, in the planet's frame: in the gap between the
## hull's halves, sunk to BAY_EXPOSED.
func bay_offset() -> Vector2:
	var half_length := Freight.bounds(PackedVector2Array(Components.DATA[component]["outline"])).size.x * 0.5
	return position + up() * (BAY_EXPOSED - half_length)

func find_piece() -> Freight:
	for node in get_tree().get_nodes_in_group("freight"):
		var f := node as Freight
		if f and f.component == component and not f.is_queued_for_deletion():
			return f
	return null

func _draw() -> void:
	# A dark scar in the ground where it came down, under everything
	var scar := PackedVector2Array([Vector2(-290, 0), Vector2(-240, -6), Vector2(240, -6), Vector2(290, 0), Vector2(0, 20)])
	draw_colored_polygon(scar, Colors.SPACE_BG)
	for half in [AFT, BOW]:
		var poly := PackedVector2Array(half)
		draw_colored_polygon(poly, Colors.HULL_DARK)
		draw_polyline(poly, Colors.HULL_LIGHT, 1.0, true)
	_draw_ribs(AFT, AFT_RIBS)
	_draw_ribs(BOW, BOW_RIBS)
	# A light strip down each flank, the hauler's running line, dead
	draw_line(Vector2(-210, -30), Vector2(-96, -38), Color(Colors.HULL_LIGHT, 0.35), 1.5)
	draw_line(Vector2(80, -30), Vector2(196, -12), Color(Colors.HULL_LIGHT, 0.35), 1.5)
	for plate in PLATES:
		var p := PackedVector2Array(plate)
		draw_colored_polygon(p, Colors.HULL_MID)
		draw_polyline(p + PackedVector2Array([p[0]]), Colors.HULL_LIGHT, 1.0)

## Frames across a half of the hull, cut off where its outline ends.
func _draw_ribs(half: Array, xs: Array) -> void:
	var poly := PackedVector2Array(half)
	for x: float in xs:
		var top := _top_at(poly, x)
		if top < 0.0:
			draw_line(Vector2(x, top + 3.0), Vector2(x, -2.0), Colors.HULL_MID, 2.0)

## The highest point (least y) of `poly`'s outline at `x`, or 0 if it doesn't reach there.
static func _top_at(poly: PackedVector2Array, x: float) -> float:
	var top := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if (a.x - x) * (b.x - x) > 0.0 or is_equal_approx(a.x, b.x):
			continue
		var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		top = minf(top, y)
	return top
