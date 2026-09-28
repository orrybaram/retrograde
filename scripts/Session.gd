extends RefCounted
class_name Session

## Brings a clone up: the one pipeline behind every way the game puts the ship in the world.
## Each way in is a Launch, a small description of how it differs; the pipeline around it,
## and its order, is always this:
##
##   reset -> cover -> unpause, a frame -> world restored -> ship placed -> uncover
##     -> live (Main: PLAYING) -> EventBus.ship_respawned -> save -> wake from black
##
## The world is restored before the ship is placed: a resumed save has to put the orbits
## back before any dock on them is found. The save comes last, after the respawn has been
## announced, so it records the world every listener has already reacted to (and no save
## ever holds a clone the game hasn't announced).
##
## A RefCounted Main drives, not a node or an autoload: it holds no state between launches,
## and a test can build one around a bare ship with a quiet Screen and its own save.
## Every way in runs through it: new_game(), resume() and relaunch().

## Emitted once the clone is up and uncovered, just before the respawn is announced. Main
## goes to PLAYING on it.
signal live

## How one way of bringing a clone up differs from the others. Every step may await.
class Launch extends RefCounted:
	## Whether the boot terminal covers this spawn (a powered SR-7); otherwise the dark does.
	var boots := false
	## Before anything shows: put the ship and anything the clone doesn't keep back.
	var reset: Callable = func() -> void: pass
	## Put the world the clone wakes into in place, and say so.
	var restore_world: Callable = func() -> void: pass
	## Put the ship where it comes up.
	var place_ship: Callable = func() -> void: pass

## What the player sees while the ship is placed. This one shows nothing and never wakes
## (tests); Main's covers the spawn with the boot terminal or the dark.
class Screen extends RefCounted:
	## Hide the spawn; returns whether the boot terminal is what hides it.
	func cover(_boots: bool) -> bool:
		return false

	## Take the cover away; `wake` leaves the dark up for wake_up().
	func uncover(_booting: bool, _wake: bool) -> void:
		pass

	## Whether this launch wakes up out of the dark.
	func wakes() -> bool:
		return false

	## Hold the dark for a beat, then bring the world up.
	func wake_up() -> void:
		pass

var _tree: SceneTree
var _ship: Ship
var _spawner: ShipSpawner
var _gs: GameState
var _screen: Screen
## (gs, ship) -> void. Save.save in the game.
var _save: Callable


func _init(tree: SceneTree, ship: Ship, spawner: ShipSpawner, gs: GameState, screen: Screen = null, save := Callable()) -> void:
	_tree = tree
	_ship = ship
	_spawner = spawner
	_gs = gs
	_screen = screen if screen else Screen.new()
	_save = save if save.is_valid() else func(state: GameState, ship_: Ship) -> void: Save.save(state, ship_)


## Bring a clone up as `launch` describes.
func run(launch: Launch) -> void:
	await launch.reset.call()
	var polygon := _ship.ship_polygon if _ship else null
	if polygon:
		polygon.visible = false  # never seen where it was before it is placed
	var wake := _screen.wakes()
	var booting := _screen.cover(launch.boots)
	_tree.paused = false  # the spawner needs physics
	await _tree.process_frame

	await launch.restore_world.call()
	await launch.place_ship.call()

	await _screen.uncover(booting, wake)
	if polygon:
		polygon.visible = true
	_tree.paused = false
	live.emit()
	EventBus.ship_respawned.emit()
	if _gs and _ship:
		_save.call(_gs, _ship)
	if wake:
		await _screen.wake_up()


## A new game: the world as the scene starts it, nothing earned, and the ship adrift outside
## SR-7 with its dock's arm still in (docs/OPENING.md §3). SR-7 is dark, so nothing boots:
## the dark covers the spawn. The planets are announced before the ship is placed, as on a
## resume; EncounterField waits for the respawn to load the cells around the ship.
func new_game() -> Launch:
	var launch := Launch.new()
	launch.boots = false  # a fresh ledger has never started the core
	launch.reset = func() -> void:
		_clear_world()
		if _gs:
			_gs.reset_all_state()
		RobotRadio.reset()
		RobotRadio.guide_awake = false  # UNIT-7 is off until the core's cold start
		var field := EncounterField.get_instance(_tree)
		if field:
			field.reset()
		_reset_orbits()
		if _ship:
			_ship.reset_to_initial_state()
	launch.restore_world = func() -> void:
		EventBus.planets_restored.emit()
	launch.place_ship = func() -> void:
		if not _spawner:
			return
		var station := await _spawner.find_home_station()
		if station:
			await _spawner.spawn_adrift(station)
		else:
			push_warning("Session: no home station for a new game")
	return launch


## Continue the save at `path` (the game save when empty). The world comes back in the order
## it depends on: the save's state, then its wrecks and Freight swapped in in one step (so no
## save in between can drop them), the deep-space field, the orbits, and only then are the
## planets announced; a physics frame settles them before the ship is placed. A ship saved
## with Freight clamped comes back in flight where it was, carrying it; otherwise it comes
## home. It boots if the save's SR-7 is powered, which the ledger says before anything loads.
func resume(path := "") -> Launch:
	var launch := Launch.new()
	launch.boots = _gs != null and _gs.progress.resumed().flagged(Progress.CORE_STARTED)
	# Handed from restore_world to place_ship (a lambda can't reassign a captured local)
	var held := {"clamped": null}
	launch.restore_world = func() -> void:
		if _gs and _ship:
			Save.load_into(_gs, _ship, path)
			_clear_world()
			var world := _ship.get_parent()
			Save.restore_wreck_gems(world, path)
			Save.restore_derelicts(world, _ship.ship_polygon, path)
			held.clamped = Save.restore_freight(world, _gs.progress, path)
		var field := EncounterField.get_instance(_tree)
		if field:
			field.restore(Save.load_encounters(path))
		Save.restore_planet_angles(_tree, path)
		EventBus.planets_restored.emit()
		await _tree.physics_frame
	launch.place_ship = func() -> void:
		if not _spawner:
			return
		var clamped: Variant = held.clamped
		if clamped != null:
			await _spawner.spawn_in_flight(Save.load_spawn_position(path), Save.load_spawn_rotation(path), Save.load_spawn_velocity(path))
			if is_instance_valid(clamped):
				_ship.carry(clamped, true)
		else:
			await _spawner.spawn_home(_gs, path)
	return launch


## The ship was lost (destroyed, or taken by the Void) and the next clone comes up at
## home. It keeps the world as it was: wreck gems stay where the ship went, and the rings
## are only topped back up. The clone keeps its fitted spec and Stores; the hold is gone.
func relaunch() -> Launch:
	var launch := Launch.new()
	launch.boots = StationPower.is_powered(_gs)
	launch.reset = func() -> void:
		if _ship:
			_ship.relaunch(_gs)
		Gem.clear_all(true)
		if _gs:
			_gs.clear_cargo()
	launch.restore_world = func() -> void:
		EventBus.resources_refresh_requested.emit()
	launch.place_ship = func() -> void:
		if _spawner:
			await _spawner.spawn_home(_gs)
	return launch


## Everything a new game or a load replaces: wreck gems, abandoned ships, and every piece of
## Freight, the one on the ship's nose included.
func _clear_world() -> void:
	Gem.clear_all()
	DerelictShip.clear_all(_tree)
	Freight.clear_all(_tree)


## Every orbit back to where the scene starts it, parents first so each body is placed off
## its parent's new position.
func _reset_orbits() -> void:
	var bodies := _tree.get_nodes_in_group("orbiting_bodies")
	bodies.sort_custom(func(a: Node, b: Node) -> bool: return _depth(a) < _depth(b))
	for body in bodies:
		body.reset_orbit()


static func _depth(n: Node) -> int:
	var d := 0
	while n.get_parent():
		n = n.get_parent()
		d += 1
	return d
