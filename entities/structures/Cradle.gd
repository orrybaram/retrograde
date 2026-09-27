extends Node2D
class_name Cradle

## SR-7's Cradle (docs/adr/0012, docs/OPENING.md §9): where a Component delivered as Freight
## is let go of, to be fitted from the station's menus once the player docks. This is the
## contract the rest of the game talks to - the ship's release (CarryingState.home_for),
## the clamped piece's tracker (Freight.destination), the dock's FIT rows
## (SpacePortDialogue) - and the part every Cradle shares: what it holds, and fitting it.
## How a piece is taken is the subclass's: SR-7's is the drop bay worked by the DORSAL
## ARM's claw (DorsalClaw).
##
## The Cradle is always open: each Component let go of into it joins GameState.cradled, in
## the order it came, and waits there - below deck, out of sight - until it is fitted.

func _ready() -> void:
	add_to_group("cradles")

## SR-7's Cradle in `tree`, or null.
static func find(tree: SceneTree) -> Cradle:
	return tree.get_first_node_in_group("cradles") as Cradle

## The Cradle `f` would be taken into if let go of right now, or null.
static func accepting(tree: SceneTree, f: Freight) -> Cradle:
	if f == null or f.component == "":
		return null
	var c := find(tree)
	return c if c and c.fits(f) else null

## Whether `f` would be taken if let go of right now.
func fits(_f: Freight) -> bool:
	return false

## Take `f`, which has just been let go of within `fits`.
func seat(_f: Freight) -> void:
	pass

## Busy with a piece: taking it, not yet ready for the next.
func is_full() -> bool:
	return false

## Where a Component is let go of, in world space, Lug outboard: the middle of what `fits`.
func drop_pose() -> Transform2D:
	return global_transform

## Where a clamped Component is headed (Freight.destination): the tracker points here.
func tracking_target() -> NodeTrackingTarget:
	return null

## Match the saved or new game. Runs on every new game and load (planets_restored).
func refresh() -> void:
	pass

## Whether docking at `port` puts the ship alongside this Cradle: `port` is on SR-7.
func serves(port: Node) -> bool:
	return port != null and get_parent() != null and get_parent().is_ancestor_of(port)

## The Components waiting in the Cradle to be fitted, oldest first.
func waiting() -> PackedStringArray:
	var gs := _game_state()
	return gs.cradled if gs else PackedStringArray()

## Fit `id` - or, with none given, the first Component waiting - to the ship
## (docs/OPENING.md §9): it is the ship's now, not the Cradle's. The Cargo Bay makes the
## hold. Returns the Component fitted, or "" with nothing to fit.
func fit(id := "") -> String:
	var gs := _game_state()
	if gs == null or gs.cradled.is_empty():
		return ""
	if id == "":
		id = gs.cradled[0]
	var at := gs.cradled.find(id)
	if at < 0:
		return ""
	var left := gs.cradled
	left.remove_at(at)
	gs.cradled = left
	gs.mark_fitted(id)
	Save.save_fitted(PackedStringArray(gs.fitted.keys()))
	Save.save_cradled(gs.cradled)
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship:
		ship.refit(gs)
	EventBus.component_fitted.emit(id)
	return id

## Record `id` as in the Cradle, at once and in the save: from here it is never loose
## Freight again.
func _record(id: String) -> void:
	var gs := _game_state()
	if gs == null:
		return
	var waiting_now := gs.cradled
	waiting_now.append(id)
	gs.cradled = waiting_now
	Save.save_cradled(gs.cradled)

## Take `f` out of the world's Freight: no saves, marks or Sweep answers, no physics.
func _hold(f: Freight) -> void:
	f.handled = false
	f.lodged = false
	f.lodged_in = null
	f.remove_from_group("freight")
	f.remove_from_group("sonar_listeners")
	f.process_mode = Node.PROCESS_MODE_DISABLED

func _game_state() -> GameState:
	return get_tree().get_first_node_in_group("game_state") as GameState if is_inside_tree() else null
