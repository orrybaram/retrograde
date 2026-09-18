extends Node2D
class_name EncounterField

## Streams deep-space encounters in and out around the ship.
##
## What lives in a cell is a pure function of (seed, cell coordinates), computed on demand
## and never stored, so the void between planets is stable without being saved and costs
## the same at Veld as it does at the sun. Only a 3x3 window of cells is ever resident.
##
## Cells are polar: a cell is a slice of a ring around the sun, and each ring turns at its
## own rate. The field therefore orbits like everything else in the game, and because it
## does not keep pace with the planets, the stretch of space between any two of them is
## different every time you cross it.
##
## The one piece of persistent state is which slots the player has harvested, and how far
## the rings have turned. See docs/ENCOUNTERS.md.

## Radial thickness of a ring, and roughly the arc each cell spans — cells come out about
## square. Smaller than both the scanner's reach (Minimap.world_range, 10000) and the
## distance at which nodes put themselves to sleep (OrbitalNode.SLEEP_DISTANCE_SQ, 8000),
## so with a 3x3 window nothing is ever seen to appear.
const BAND_WIDTH := 8000.0
const WINDOW_RADIUS := 1
const CELL_CHECK_INTERVAL := 0.25

## How fast the rings turn. Tangential speed falls off with distance the way an orbit's
## does (angular rate goes as r^-1.5), pinned to `DRIFT_REFERENCE_SPEED` at the middle of
## the system. The planets here turn on a much flatter curve, so the field runs ahead of
## them on the inside and lags behind them on the outside — that difference is what makes
## a route change between one crossing and the next.
const DRIFT_REFERENCE_RADIUS := 112500.0  # Sonder's orbit
const DRIFT_REFERENCE_SPEED := 12.0       # px/s tangential there
const MAX_DRIFT_SPEED := 30.0             # px/s, a ceiling for the innermost rings

## Rings closer in than this hold nothing — the sun's own gravity well owns that space.
## `_is_clear()` is the exact test; this is the cheap one that skips the roll entirely.
const SUN_EXCLUSION := 20000.0
## Clearance from a planet's gravity field before deep space will place anything, so
## encounters never land inside the orbital rings the planet spawners already fill.
const PLANET_CLEARANCE := 4000.0
## Keeps encounter origins away from the cell edges, so a cluster's spread stays inside
## the cell that owns it.
const CELL_MARGIN := 1500.0

@export var table: EncounterTable
@export var enabled: bool = true

var _cells: Dictionary = {}      # Vector2i(band, sector) -> Array[EncounterContact]
var _consumed: Dictionary = {}   # slot key -> true
var _claimed: Dictionary = {}    # slot key -> def id, for encounters with a budget
var _handlers: Dictionary = {}   # Node -> Callable, the bound resource_depleted listener
var _elapsed: float = 0.0        # game seconds the rings have been turning
var _ship: Node2D = null
var _sun: Planet = null
var _current_cell := Vector2i.ZERO
var _streaming := false
var _check_timer := 0.0

static func get_instance(tree: SceneTree) -> EncounterField:
	return tree.get_first_node_in_group("encounter_field") as EncounterField

func _ready() -> void:
	add_to_group("encounter_field")
	EventBus.planets_restored.connect(_on_planets_restored)

# --- Lifecycle ---------------------------------------------------------------

## New game: forget everything, including what previous runs harvested and how far the
## rings had turned.
func reset() -> void:
	_release_all()
	_consumed.clear()
	_claimed.clear()
	_elapsed = 0.0
	_streaming = false

## Everything worth saving. The cells themselves come back from the seed.
func snapshot() -> Dictionary:
	var claims := PackedStringArray()
	for slot in _claimed:
		claims.append("%s=%s" % [slot, _claimed[slot]])
	return {"consumed": consumed_keys(), "claimed": claims, "elapsed": _elapsed}

## Restore a saved field. Call before streaming starts, or the first cells will come back
## unturned and holding scrap the player already took.
func restore(data: Dictionary) -> void:
	load_consumed(PackedStringArray(data.get("consumed", PackedStringArray())))
	_claimed.clear()
	for claim in PackedStringArray(data.get("claimed", PackedStringArray())):
		var parts := claim.split("=", true, 1)
		if parts.size() == 2:
			_claimed[parts[0]] = parts[1]
	_elapsed = float(data.get("elapsed", 0.0))

func load_consumed(keys: PackedStringArray) -> void:
	_consumed.clear()
	for key in keys:
		_consumed[key] = true

func consumed_keys() -> PackedStringArray:
	return PackedStringArray(_consumed.keys())

func elapsed() -> float:
	return _elapsed

## Everything the loaded cells are holding right now, counted in nodes.
func node_count() -> int:
	var total := 0
	for cell in _cells:
		for contact in _cells[cell]:
			total += contact.remaining()
	return total

## What the scanner can see from `origin`, nearest first. One entry per encounter, not
## per node — see EncounterContact.
func contacts_in_range(origin: Vector2, radius: float) -> Array[EncounterContact]:
	var found: Array[EncounterContact] = []
	for cell in _cells:
		for contact in _cells[cell]:
			if contact.is_alive() and contact.position().distance_to(origin) <= radius:
				found.append(contact)
	found.sort_custom(func(a, b):
		return a.position().distance_squared_to(origin) < b.position().distance_squared_to(origin))
	return found

## How many of a budgeted encounter this game has already handed out.
func claimed_count(def_id: StringName) -> int:
	var total := 0
	for slot in _claimed:
		if _claimed[slot] == String(def_id):
			total += 1
	return total

func _on_planets_restored() -> void:
	if not enabled:
		return
	_release_all()
	_streaming = true
	_check_timer = 0.0
	_ship = null
	_sun = null
	_reconcile(true)

func _process(delta: float) -> void:
	if not _streaming:
		return
	# Game seconds only: _process doesn't run while the tree is paused, which is the same
	# stretch of time OrbitalMotion skips, so the rings and the nodes on them stay in step.
	_elapsed += delta
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = CELL_CHECK_INTERVAL
	_reconcile(false)

# --- Cell geometry -----------------------------------------------------------
# A cell is Vector2i(band, sector): a ring counted outward from the sun, and a slice of
# that ring counted round from its own rotating zero. Sector indices are fixed to the
# ring, so a cell keeps its contents as the ring turns.

## The sun, which everything here is measured from. Vector2.ZERO until it is found.
func centre() -> Vector2:
	if _sun and is_instance_valid(_sun):
		return _sun.global_position
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Planet
		if planet and planet.planet_type == Planet.PlanetType.SUN:
			_sun = planet
			return planet.global_position
	return Vector2.ZERO

func band_of(radius: float) -> int:
	return floori(radius / BAND_WIDTH)

func band_mid(band: int) -> float:
	return (band + 0.5) * BAND_WIDTH

## Sectors in a ring, chosen so each one spans about BAND_WIDTH of arc.
func sectors(band: int) -> int:
	return maxi(1, roundi(TAU * band_mid(band) / BAND_WIDTH))

func angle_step(band: int) -> float:
	return TAU / sectors(band)

## Angular rate of a ring, in radians per second.
func band_rate(band: int) -> float:
	var radius := maxf(band_mid(band), BAND_WIDTH * 0.5)
	var rate := (DRIFT_REFERENCE_SPEED / DRIFT_REFERENCE_RADIUS) \
			* pow(DRIFT_REFERENCE_RADIUS / radius, 1.5)
	return minf(rate, MAX_DRIFT_SPEED / radius)

## How far a ring has turned from its zero.
func band_rotation(band: int) -> float:
	return fposmod(band_rate(band) * _elapsed, TAU)

func cell_of(world_position: Vector2) -> Vector2i:
	var offset := world_position - centre()
	var band := band_of(offset.length())
	return Vector2i(band, sector_of(band, offset.angle()))

## Which sector of `band` a world heading falls in, right now.
func sector_of(band: int, world_angle: float) -> int:
	var local := fposmod(world_angle - band_rotation(band), TAU)
	return posmod(floori(local / angle_step(band)), sectors(band))

## Where the middle of a cell is, right now.
func cell_centre(cell: Vector2i) -> Vector2:
	var angle := (cell.y + 0.5) * angle_step(cell.x) + band_rotation(cell.x)
	return centre() + Vector2.RIGHT.rotated(angle) * band_mid(cell.x)

## Seed offset for a cell. The two large primes scatter neighbouring cells to unrelated
## parts of the sequence, so adjacent cells don't come out looking alike.
static func cell_seed(cell: Vector2i) -> int:
	return cell.x * 73856093 + cell.y * 19349663

# --- Streaming ---------------------------------------------------------------

func _reconcile(force: bool) -> void:
	if not _ship or not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("ship") as Node2D
		if not _ship:
			return
		force = true

	var offset := _ship.global_position - centre()
	var cell := Vector2i(band_of(offset.length()), 0)
	cell.y = sector_of(cell.x, offset.angle())
	if not force and cell == _current_cell:
		return
	_current_cell = cell

	# Rings have different sector counts, so a neighbour is "the sector of that ring the
	# ship is under", not "the same index one ring out".
	var wanted: Dictionary = {}
	for band in range(maxi(cell.x - WINDOW_RADIUS, 0), cell.x + WINDOW_RADIUS + 1):
		var here := sector_of(band, offset.angle())
		var divisions := sectors(band)
		for step in range(-WINDOW_RADIUS, WINDOW_RADIUS + 1):
			wanted[Vector2i(band, posmod(here + step, divisions))] = true

	for loaded in _cells.keys():
		if not wanted.has(loaded):
			_release_cell(loaded)

	for target in wanted.keys():
		if not _cells.has(target):
			_cells[target] = _generate(target)

func _release_cell(cell: Vector2i) -> void:
	for contact in _cells.get(cell, []):
		for node in contact.nodes:
			_detach(node)
	_cells.erase(cell)

func _release_all() -> void:
	for cell in _cells.keys():
		for contact in _cells[cell]:
			for node in contact.nodes:
				_detach(node)
	_cells.clear()
	_handlers.clear()

func _detach(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_unhook(node)
	var def := node.get_meta("encounter_def", null) as EncounterDef
	node.remove_meta("encounter_def")
	if def:
		def.release(node)
	elif node is OrbitalNode:
		ResourceNodePool.return_instance(node)
	else:
		node.queue_free()

## Drop our depletion listener. Pooled nodes outlive the cell that borrowed them, so a
## connection left behind would fire for whoever spawns them next.
func _unhook(node: Node) -> void:
	var handler = _handlers.get(node)
	_handlers.erase(node)
	if handler is Callable and node.has_signal("resource_depleted") \
			and node.resource_depleted.is_connected(handler):
		node.resource_depleted.disconnect(handler)

# --- Generation --------------------------------------------------------------

## Everything a cell holds, from its seed alone. Slot indices advance for every planned
## node whether or not it is built, so a slot key means the same thing in every session.
func _generate(cell: Vector2i) -> Array[EncounterContact]:
	var contacts: Array[EncounterContact] = []
	if not table or band_mid(cell.x) < SUN_EXCLUSION:
		return contacts

	var rng := RNG.get_seeded_rng(cell_seed(cell))
	var count := rng.randi_range(table.min_per_cell, table.max_per_cell)
	var index := 0

	for i in count:
		var def := table.pick(rng, band_mid(cell.x))
		var origin := _point_in_cell(cell, rng)
		if not def:
			continue
		var contact := EncounterContact.new(def.contact_label)
		for entry in def.plan(rng, origin):
			var slot := "%d:%d:%d" % [cell.x, cell.y, index]
			index += 1
			if _consumed.has(slot):
				continue
			# Planets move, so this is a "not right now" test, not part of the seed.
			if not _is_clear(entry.get("pos", origin)):
				continue
			# A budgeted encounter belongs to the slots that already claimed it. Once they
			# are all spoken for, this one is simply not there.
			if def.budget > 0 and not _claimed.has(slot) \
					and claimed_count(def.id) >= def.budget:
				continue
			var node := def.build(self, entry)
			if not node:
				continue
			if def.budget > 0:
				_claimed[slot] = String(def.id)
			node.set_meta("encounter_def", def)
			if node is OrbitalNode:
				var orbital := node as OrbitalNode
				orbital.spawner_key = slot
				_set_adrift(orbital, cell.x)
			if node is ScrapNode:
				var handler := _on_node_depleted.bind(node)
				_handlers[node] = handler
				(node as ScrapNode).resource_depleted.connect(handler)
			contact.add(node)
		if contact.is_alive():
			contacts.append(contact)

	return contacts

## Put a node on a slow circular orbit about the sun at its ring's rate. The whole ring
## turns as one, so a cluster keeps its shape and nothing drifts out of the cell that
## owns it. It also gives the node a real velocity, so flying into one bounces off what
## it is actually doing rather than off something standing still.
func _set_adrift(node: OrbitalNode, band: int) -> void:
	var sun_position := centre()
	var motion = node._orbital_motion
	if not motion or not _sun or not is_instance_valid(_sun):
		return
	var offset := node.global_position - sun_position
	motion.orbital_distance = offset.length()
	motion.orbital_speed = (band_rate(band) / motion.speed_scale) * 100.0
	motion.initial_angle = offset.angle()
	motion.initialize(_sun)

## A point inside the cell, held off its edges so a cluster's spread stays inside it.
func _point_in_cell(cell: Vector2i, rng: RandomNumberGenerator) -> Vector2:
	var step := angle_step(cell.x)
	var radius := band_mid(cell.x)
	var angle_margin := minf(CELL_MARGIN / maxf(radius, 1.0), step * 0.4)
	var angle := (cell.y + 0.5) * step \
			+ rng.randf_range(-1.0, 1.0) * (step * 0.5 - angle_margin) \
			+ band_rotation(cell.x)
	var reach := maxf(BAND_WIDTH * 0.5 - CELL_MARGIN, 0.0)
	return centre() + Vector2.RIGHT.rotated(angle) * (radius + rng.randf_range(-reach, reach))

## False inside any planet's gravity field (plus clearance), where the planet's own
## spawners already put resources.
func _is_clear(world_position: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("planets"):
		var planet := node as Planet
		if not planet:
			continue
		var keep_out := planet.radius * planet.gravity_radius_multiplier + PLANET_CLEARANCE
		if world_position.distance_to(planet.global_position) < keep_out:
			return false
	return true

# --- Consumption -------------------------------------------------------------

## Harvested for good. Deep space does not refill, so the slot is recorded and skipped
## the next time its cell is generated.
func _on_node_depleted(node: OrbitalNode) -> void:
	if not is_instance_valid(node):
		return
	# The node returns itself to the pool from here, so let go of it first.
	_unhook(node)
	node.remove_meta("encounter_def")
	var slot := node.spawner_key
	if slot == "":
		return
	_consumed[slot] = true
	var parts := slot.split(":")
	if parts.size() < 3:
		return
	var cell := Vector2i(int(parts[0]), int(parts[1]))
	if not _cells.has(cell):
		return
	for contact in _cells[cell]:
		if node in contact.nodes:
			contact.drop(node)
			if not contact.is_alive():
				_cells[cell].erase(contact)
			return
