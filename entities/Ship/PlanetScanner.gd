extends Node
class_name PlanetScanner

## The Planetary Scanner upgrade at work. While the ship holds inside an unscanned
## planet's gravity field, a PlanetScan meter fills and a ScanSweep turns around the
## planet; leaving the field resets it. A finished scan is recorded in GameState,
## written to the save and announced with EventBus.planet_scanned (which reveals its
## landing sites); the nav tracker then points at the nearest site.
## Inert until GameState.has_planet_scanner. Added to the Ship at runtime.

var scan := PlanetScan.new()

var _ship: Ship = null
var _gs: GameState = null
var _sweep: ScanSweep = null

func _ready() -> void:
	_ship = get_parent() as Ship

func progress() -> float:
	return scan.progress

## Planet being scanned right now, or null.
func target() -> Planet:
	return scan.target if is_instance_valid(scan.target) else null

func is_scanning() -> bool:
	return target() != null

func _physics_process(delta: float) -> void:
	if scan.target != null and not is_instance_valid(scan.target):
		scan.reset()
	var planet := _candidate()
	var previous := scan.target
	if scan.update(planet, delta):
		_complete(planet)
	elif scan.target != previous:
		_end_sweep(false)
		if scan.target:
			_sweep = ScanSweep.attach(scan.target, _ship.global_position)
	if is_instance_valid(_sweep):
		_sweep.progress = scan.progress

func _candidate() -> Planet:
	if not _active():
		return null
	return PlanetScan.pick(_ship.global_position, get_tree().get_nodes_in_group("planets"))

func _active() -> bool:
	if not _ship or _ship.is_destroyed() or _ship.is_locked_to_planet():
		return false
	if not _gs or not is_instance_valid(_gs):
		_gs = get_tree().get_first_node_in_group("game_state") as GameState
	if not _gs or not _gs.has_planet_scanner:
		return false
	var main := get_tree().get_first_node_in_group("main")
	return main == null or main.current_game_state == main.MainGameState.PLAYING

func _complete(planet: Planet) -> void:
	_end_sweep(true)
	_gs.mark_planet_scanned(planet.save_key())
	Save.save_scanned_planets(PackedStringArray(_gs.scanned_planets.keys()))
	EventBus.planet_scanned.emit(planet)
	# Point the way to the closest site found, unless the player is headed somewhere else
	var site := nearest_site(planet, _ship.global_position)
	if site and NavSystem.is_tracking_home():
		NavSystem.track(site.tracking_target())

## The planet's closest landing site to `pos`, or null when it has none.
static func nearest_site(planet: Planet, pos: Vector2) -> LandingSite:
	var best: LandingSite = null
	for site in planet.get_landing_sites():
		if best == null or pos.distance_squared_to(site.global_position) < pos.distance_squared_to(best.global_position):
			best = site
	return best

func _end_sweep(completed: bool) -> void:
	if is_instance_valid(_sweep):
		_sweep.finish(completed)
	_sweep = null
