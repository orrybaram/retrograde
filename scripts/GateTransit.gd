extends RefCounted
class_name GateTransit

## Transit along the link two powered Gates make. A Gate powers its own Module on its
## own; the link only exists between Modules that are already online, which is why the
## destination list is exactly the other powered Gates.
##
## The Titan carries the ship, so nothing aboard pays for it: no fuel, no hull, no hold,
## no credits. The screen cuts to black and the ship comes out of the dark already in
## the destination's cradle. Nothing is reloaded or reset on the way — orbits, the
## encounter field and every Gate's own clock keep running through the cut.

## How long the dark holds before the destination comes up.
const BLACK_HOLD := 0.9

## The Gates this one is linked to: every other Gate whose Module is online, read from
## the sun outwards so the list matches the order the Chart draws them in.
static func destinations(from: Gate, tree: SceneTree) -> Array[Gate]:
	var linked: Array[Gate] = []
	if from == null or tree == null:
		return linked
	for node in tree.get_nodes_in_group("gates"):
		var gate := node as Gate
		if gate == null or gate == from or not gate.is_powered():
			continue
		linked.append(gate)
	linked.sort_custom(func(a: Gate, b: Gate) -> bool:
		return _orbit_distance(a) < _orbit_distance(b))
	return linked

## How far out the Gate's planet orbits; what the destination list sorts on.
static func _orbit_distance(gate: Gate) -> float:
	return gate.parent_planet.orbital_distance if gate.parent_planet else 0.0

## What a destination reads as on the terminal: the planet whose Module it powers.
static func label_for(gate: Gate) -> String:
	if gate == null or gate.parent_planet == null:
		return "UNIDENTIFIED"
	return gate.parent_planet.planet_name.to_upper()

## Both ends have to be online: one powered Gate on its own has nowhere to go.
static func can_transit(from: Gate, to: Gate) -> bool:
	if from == null or to == null or from == to:
		return false
	return from.is_powered() and to.is_powered()

## The move itself, with nothing around it: the ship is set down in the destination's
## cradle and locked there. Costs nothing and touches nothing else aboard.
static func arrive(ship: Ship, destination: Gate) -> void:
	if ship == null or not is_instance_valid(destination):
		return
	var dock := destination.get_dock_transform()
	ship.global_position = dock.origin
	ship.rotation = dock.get_rotation() + PI / -2.0
	ship.linear_velocity = destination.get_dock_velocity()
	ship.angular_velocity = 0.0
	ship.set_meta("pending_dockable", destination)
	ship.set_meta("instant_dock", true)
	if ship.state_machine and ship.state_machine.has_state("GateDockedState"):
		ship.state_machine.change_state("GateDockedState")

## The whole transit as the player sees it: dark, the move, then waking up in the
## other cradle. The tree is never paused, so the system keeps turning underneath.
static func run(ship: Ship, destination: Gate) -> void:
	if ship == null or not ship.is_inside_tree() or not is_instance_valid(destination):
		return
	var tree := ship.get_tree()
	var main := tree.get_first_node_in_group("main")
	if main and main.has_method("_black_out"):
		main._black_out()
	await tree.create_timer(BLACK_HOLD, true, false, true).timeout
	if not is_instance_valid(ship) or not is_instance_valid(destination):
		return
	arrive(ship, destination)
	_persist(ship)
	if main and main.has_method("_wake_from_black"):
		await main._wake_from_black()
	# The guide only has something to say about it the first time it happens
	RobotRadio.request(RobotRadio.MSG_FIRST_TRANSIT)

## Coming out of the dock the Titan put the ship in is worth keeping: a transit moves
## the ship across the system without so much as a burn to show for it.
static func _persist(ship: Ship) -> void:
	var gs := ship.get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		Save.save(gs, ship)
