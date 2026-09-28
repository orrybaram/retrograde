extends GdUnitTestSuite

## The relaunch after a loss runs through Session's one pipeline: the world is restored,
## the respawn announced, and only then the save, which holds the relaunched clone. The Ship
## resets itself for it, every flight field, on the dock path and the adrift one.

## The smallest thing a ship can dock at: every method Dockable asks for, and nothing else.
const BERTH_SOURCE := """extends Node2D
func get_dock_position() -> Vector2:
	return global_position
func get_dock_rotation() -> float:
	return global_rotation
func get_dock_distance() -> float:
	return 30.0
func get_dock_velocity() -> Vector2:
	return Vector2.ZERO
func accepts_docking() -> bool:
	return true
"""

## Written in place of the player's save, and removed after each test.
const SAVE_PATH := "user://session_test_save.cfg"

## Counts what the pipeline shows, and never wakes.
class RecordingScreen extends Session.Screen:
	var events: Array
	var boots_asked := false

	func _init(log_: Array) -> void:
		events = log_

	func cover(boots: bool) -> bool:
		boots_asked = boots
		events.append("cover")
		return false

	func uncover(_booting: bool, _wake: bool) -> void:
		events.append("uncover")

var _world: Node2D
var _ship: Ship
var _spawner: ShipSpawner
var _gs: GameState
var _events: Array = []
var _connections: Array = []

func before_test() -> void:
	_events = []
	_world = auto_free(Node2D.new()) as Node2D
	add_child(_world)
	_ship = load("res://entities/Ship/Ship.tscn").instantiate() as Ship
	_ship.name = "Ship"
	_world.add_child(_ship)
	_spawner = ShipSpawner.new()
	_world.add_child(_spawner)
	# Kept out of the tree: a GameState there would let the dock autosave to the real save.
	_gs = auto_free(GameState.new()) as GameState
	_listen(EventBus.planets_restored, "planets_restored")
	_listen(EventBus.resources_refresh_requested, "world_refreshed")
	_listen(EventBus.ship_respawned, "ship_respawned")

func after_test() -> void:
	for c in _connections:
		if (c[0] as Signal).is_connected(c[1]):
			(c[0] as Signal).disconnect(c[1])
	_connections.clear()
	get_tree().paused = false
	Freight.clear_all(get_tree())
	Gem.clear_all()
	InventoryManager.clear_inventory()
	NavSystem.track_home()
	DirAccess.remove_absolute(SAVE_PATH)

func _listen(sig: Signal, name_: String) -> void:
	var f := func() -> void: _events.append(name_)
	sig.connect(f)
	_connections.append([sig, f])

func _berth(pos := Vector2(3000, 0)) -> Node2D:
	var script := GDScript.new()
	script.source_code = BERTH_SOURCE
	script.reload()
	var berth := Node2D.new()
	berth.set_script(script)
	berth.add_to_group(Dockable.GROUP)
	berth.global_position = pos
	_world.add_child(berth)
	return berth

## A session saving to SAVE_PATH; the saved file is read back as it was written.
func _session() -> Session:
	var save := func(state: GameState, ship: Ship) -> void:
		_events.append("save")
		Save.save(state, ship, SAVE_PATH)
	var session := Session.new(get_tree(), _ship, _spawner, _gs, RecordingScreen.new(_events), save)
	session.live.connect(func() -> void: _events.append("live"))
	return session

## A ship that has been through something: every flight field off its rest value.
func _rough_up() -> void:
	_ship.global_position = Vector2(-5000, 800)
	_ship.linear_velocity = Vector2(420, -90)
	_ship.angular_velocity = 3.0
	_ship.rotation = 1.2
	_ship.drift_spin = 1.7
	_ship.camera_shake_time = 0.8
	_ship.damage_shake_time = 0.9
	_ship.damage_shake_current_intensity = 5.0
	_ship.boost_particles.amount = 7
	_ship.boost_particles.one_shot = true
	_ship.boost_particles.position = Vector2(40, 40)

func _destroy() -> void:
	_rough_up()
	_ship.take_damage(_ship.max_hull * 10.0)
	assert_bool(_ship.is_destroyed()).is_true()

## Every flight field is back at rest, whatever it was before the loss.
func _assert_reset() -> void:
	_assert_whole()
	assert_vector(_ship.linear_velocity).is_equal(Vector2.ZERO)
	assert_float(_ship.angular_velocity).is_equal(0.0)

## The hull, the shake, the boost plume and processing: what no spawn touches.
func _assert_whole() -> void:
	assert_float(_ship.hull_strength).is_equal(_ship.max_hull)
	assert_float(_ship.camera_shake_time).is_equal(0.0)
	assert_float(_ship.damage_shake_time).is_equal(0.0)
	assert_float(_ship.damage_shake_current_intensity).is_equal(0.0)
	assert_int(_ship.boost_particles.amount).is_equal(_ship.original_boost_amount)
	assert_bool(_ship.boost_particles.one_shot).is_false()
	assert_bool(_ship.boost_particles.emitting).is_false()
	assert_vector(_ship.boost_particles.position).is_equal(Vector2(-10, 0))
	assert_bool(_ship.is_processing()).is_true()
	assert_bool(_ship.is_physics_processing()).is_true()
	assert_bool(_ship.is_gone()).is_false()

# --- the pipeline ---

func test_a_relaunch_restores_the_world_then_announces_the_respawn_then_saves() -> void:
	_berth()
	_destroy()
	_events.clear()
	var session := _session()
	await session.run(session.relaunch())
	assert_array(_events).contains_exactly(
		["cover", "world_refreshed", "uncover", "live", "ship_respawned", "save"])

func test_a_relaunch_keeps_the_world_it_came_back_to() -> void:
	# planets_restored rebuilds every ring and encounter: a relaunch never asks for that
	_berth()
	_destroy()
	var session := _session()
	await session.run(session.relaunch())
	assert_array(_events).not_contains(["planets_restored"])

func test_the_save_holds_the_relaunched_clone_and_the_ledger() -> void:
	var berth := _berth()
	_gs.core_started = true
	_ship.drive.fuel = 0.0
	_gs.death_count = 3
	_gs.stores = 12
	_gs.progress.mark(Progress.IDENTIFIED_GATES, "Veld")
	# A fact earned as the respawn is announced reaches the save: it is written last
	var mark := func() -> void: _gs.progress.mark(Progress.IDENTIFIED_GATES, "Rook")
	EventBus.ship_respawned.connect(mark)
	_connections.append([EventBus.ship_respawned, mark])
	InventoryManager.add_item("gem", 2)
	_destroy()

	var session := _session()
	await session.run(session.relaunch())

	var cfg := ConfigFile.new()
	assert_int(cfg.load(SAVE_PATH)).is_equal(OK)
	assert_float(cfg.get_value("stats", "hull_strength")).is_equal(_ship.max_hull)
	assert_float(cfg.get_value("stats", "fuel")).is_equal(_ship.drive.free_floor(_gs))
	assert_int(cfg.get_value("stats", "death_count")).is_equal(3)
	assert_int(cfg.get_value("stats", "stores")).is_equal(12)
	assert_float(cfg.get_value("stats", "spawn_position_x")).is_equal_approx(berth.global_position.x, 0.5)
	assert_float(cfg.get_value("stats", "spawn_velocity_x")).is_equal(0.0)
	assert_array(cfg.get_section_keys("cargo") if cfg.has_section("cargo") else []).is_empty()
	assert_array(Array(cfg.get_value("gates", "identified"))).contains_exactly(["Veld", "Rook"])

func test_a_relaunch_boots_only_on_a_powered_station() -> void:
	_berth()
	_destroy()
	var screen := RecordingScreen.new(_events)
	var session := Session.new(get_tree(), _ship, _spawner, _gs, screen, func(_g, _s) -> void: pass)
	await session.run(session.relaunch())
	assert_bool(screen.boots_asked).is_false()
	_gs.core_started = true
	_destroy()
	await session.run(session.relaunch())
	assert_bool(screen.boots_asked).is_true()

# --- the Ship's reset ---

func test_relaunch_resets_every_flight_field_including_the_spin() -> void:
	_destroy()
	_ship.relaunch(_gs)
	_assert_reset()
	assert_float(_ship.rotation).is_equal(0.0)
	assert_float(_ship.drift_spin).is_equal(0.0)
	assert_str(_ship.state_machine.get_current_state_name()).is_equal("FlyingState")

func test_relaunch_tops_the_tank_up_to_the_free_quarter_once_the_core_runs() -> void:
	_gs.core_started = true
	_ship.drive.fuel = 0.0
	_destroy()
	_ship.relaunch(_gs)
	assert_float(_ship.drive.fuel).is_equal(_ship.drive.free_floor(_gs))

func test_relaunch_lets_go_of_a_load_where_the_ship_was() -> void:
	var f := Freight.spawn(_world, Vector2(500, 0))
	_ship.carry(f, true)
	_ship.relaunch(_gs)
	assert_bool(_ship.is_carrying()).is_false()
	assert_bool(is_instance_valid(f)).is_true()

func test_a_ship_lost_and_relaunched_at_its_dock_comes_up_docked_and_still() -> void:
	var berth := _berth()
	_destroy()
	var session := _session()
	await session.run(session.relaunch())
	_assert_reset()
	assert_float(_ship.drift_spin).is_equal(0.0)
	assert_str(_ship.state_machine.get_current_state_name()).is_equal("LandedState")
	assert_float(_ship.global_position.distance_to(berth.global_position)).is_less(1.0)

func test_a_ship_taken_by_the_void_and_relaunched_adrift_carries_no_spin_from_before() -> void:
	# The adrift path: the spawner gives the clone the slow waking tumble, never the old one's
	var station := Node2D.new()
	_world.add_child(station)
	_rough_up()
	_ship.surrender_to_void()
	assert_bool(_ship.is_gone()).is_true()
	_ship.relaunch(_gs)
	assert_float(_ship.drift_spin).is_equal(0.0)
	await _spawner.spawn_adrift(station, false)
	_assert_whole()
	assert_float(_ship.drift_spin).is_equal(ShipSpawner.ADRIFT_SPIN)
	assert_str(_ship.state_machine.get_current_state_name()).is_equal("FlyingState")
