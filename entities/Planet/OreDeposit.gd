extends Node2D
class_name OreDeposit

## A seam of ore sitting just under a planet's surface: a handful of rough rock chunks,
## dark against the crust and flecked with mineral, that only show once the Planetary
## Scanner has mapped the planet. Planets grow their own seams (Planet._spawn_ore, seeded
## from the planet's key, so they land in the same places every session). The seam is a
## child of its Planet, so it rides the orbit.
##
## Land on the plain surface anywhere within REACH of a seam to drill it (see Touchdown).
## `rich` seams (moons) run deeper and roll better gems. Drilling eats the seam from the
## top down: OreDrill reports its progress to set_dug(), and the chunks crumble away one
## by one, shallowest first. A finished dig spends the seam, so the last chunks break up
## and the seam leaves the view, the minimap and the tracker until it refills
## (REGROW_TIME of play, RICH_REGROW_TIME when rich; timers live in GameState, and are
## never shown as a clock).
##
## Deeper scans and deeper digs are a later iteration; for now every seam sits near the
## surface and is reached from the ground above it.

## How far along the surface the ship may land from the seam's centre and still drill it.
const REACH := 150.0
const DEPTH_MIN := 22.0  # how far under the surface the chunks sit
const DEPTH_MAX := 110.0
const CLUSTER := 70.0  # radius of the scatter around the seam's centre
const CHUNK_MIN := 8.0
const CHUNK_MAX := 17.0
const CHUNK_COUNT := Vector2i(2, 4)
const RICH_CHUNK_COUNT := Vector2i(4, 6)
const CHUNK_VERTS := 9
const CHUNK_JAG := 0.38  # how far a chunk's corners wander off a circle
const CHUNK_SKEW := 0.55  # how unevenly they're spaced around it
const CLEAVES := 2  # fracture lines across a chunk
const CROWN := 0.4  # the lit face, as a share of the chunk, shifted toward the surface
const FLECKS := Vector2i(1, 3)  # mineral specks per chunk
const FLECK_RADIUS := 1.2
const FILL_ALPHA := 0.88
const CROWN_ALPHA := 0.5
const EDGE_ALPHA := 0.9
const FACET_ALPHA := 0.45
const FLECK_ALPHA := 0.6
const LINE_WIDTH := 1.5
const REVEAL_TIME := 0.9
const CRUMBLE_TIME := 0.45  # how long the seam takes to break apart once fully dug
const CRUMBLE_SHRINK := 0.65  # how far a chunk collapses before it's gone
## A chunk breaking up throws rock: SHARDS splinters that arc back down under
## SHARD_GRAVITY, over a puff of dust. Local +x is up out of the surface.
const SHARDS := Vector2i(6, 10)
const SHARD_VERTS := 4
const SHARD_SIZE := Vector2(1.6, 4.2)
const SHARD_SPEED := Vector2(45.0, 130.0)
const SHARD_SPIN := 7.0
const SHARD_LIFE := Vector2(0.45, 0.85)
const SHARD_GRAVITY := 190.0
const PUFFS := 4
const PUFF_LIFE := Vector2(0.35, 0.6)
const PUFF_GROW := Vector2(14.0, 30.0)
const PUFF_ALPHA := 0.3
const PING_RADIUS := 170.0
const REGROW_TIME := 300.0
const RICH_REGROW_TIME := 450.0

## Where on the planet, in degrees (0 = the planet's +x side).
@export_range(0.0, 360.0) var angle_degrees: float = 0.0
## Richer seams (moons) run deeper and roll better gems.
@export var rich: bool = false
## Index within its planet; part of the save key.
@export var ore_index: int = 0

var planet: Planet = null
var minimap_target: OreMinimapTarget = null

# {pos: Vector2 (local), size: float, turn: float, jag: PackedFloat32Array,
#  cleave: int, flecks: Array[Vector2]}, ordered shallowest first (drilling order)
var _chunks: Array[Dictionary] = []
var _revealed := false
var _reveal_time := 0.0  # counts up after reveal, for the ping
var _dug := 0.0  # share of the seam drilled out (0..1), never falls until it refills
var _dug_shown := 0.0  # eases toward _dug, so chunks crumble instead of blinking out
var _tracking: OreTrackingTarget = null
var _gs: GameState = null
var _was_spent := false
# Rock thrown out by a chunk breaking up: {pos, vel, turn, spin, size, jag, life, age}
var _shards: Array[Dictionary] = []
# The dust it leaves hanging: {pos, radius, grow, life, age}
var _puffs: Array[Dictionary] = []
var _shattered := 0  # chunks that have already thrown their rock
## Debris rolls on its own generator, never the shared RNG: how a chunk happens to
## splinter must not shift the rolls the game plays with (gem scatter, drill drops).
var _debris_rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("ore_deposits")
	planet = get_parent() as Planet
	z_index = 1  # over the planet disc, under the ship
	if planet:
		var normal_angle := deg_to_rad(angle_degrees)
		position = Vector2.from_angle(normal_angle) * surface_radius()
		rotation = normal_angle
		_chunks = shape_chunks(rich, hash(ore_id()))
		_debris_rng.seed = hash(ore_id() + "#debris")
	EventBus.planet_scanned.connect(_on_planet_scanned)
	EventBus.planets_restored.connect(refresh)
	EventBus.ship_respawned.connect(refresh)
	refresh()
	_register_with_minimap.call_deferred()

func _exit_tree() -> void:
	if minimap_target:
		var minimap := Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

## The rock chunks of one seam, in the seam's local space (local +x points out of the
## surface, so the chunks sit at negative x), ordered shallowest first so the drill eats
## them in the order the bit reaches them. Seeded, so a seam looks the same every run.
static func shape_chunks(is_rich: bool, seed_value: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var span := RICH_CHUNK_COUNT if is_rich else CHUNK_COUNT
	var centre := Vector2(-(DEPTH_MIN + DEPTH_MAX) / 2.0, 0.0)
	var chunks: Array[Dictionary] = []
	for i in rng.randi_range(span.x, span.y):
		# Scattered evenly through a disc around the seam's centre, not strung out in a line
		var at := centre + Vector2.from_angle(rng.randf() * TAU) * (sqrt(rng.randf()) * CLUSTER)
		var jag := PackedFloat32Array()
		for v in CHUNK_VERTS:
			jag.append(rng.randf_range(1.0 - CHUNK_JAG, 1.0 + CHUNK_JAG))
		var flecks: Array[Vector2] = []
		for f in rng.randi_range(FLECKS.x, FLECKS.y):
			# Inside the chunk, as a fraction of its size
			flecks.append(Vector2.from_angle(rng.randf() * TAU) * (sqrt(rng.randf()) * 0.55))
		chunks.append({
			"pos": Vector2(-clampf(-at.x, DEPTH_MIN, DEPTH_MAX), at.y),
			"size": rng.randf_range(CHUNK_MIN, CHUNK_MAX) * (1.15 if is_rich else 1.0),
			"turn": rng.randf() * TAU,
			"jag": jag,
			"cleave": rng.randi_range(0, CHUNK_VERTS - 1),
			"flecks": flecks,
		})
	# Shallowest first: the bit breaks the rock nearest the surface before it digs deeper
	chunks.sort_custom(func(a, b): return a["pos"].x > b["pos"].x)
	return chunks

## Planet key + index, stable across sessions (for saves).
func ore_id() -> String:
	return "%s#%d" % [planet.save_key(), ore_index]

func surface_radius() -> float:
	return planet.radius * planet.collision_radius_ratio

## Outward surface normal (world space).
func normal() -> Vector2:
	return Vector2.from_angle(global_rotation)

## How far to either side the ship may set down, as an angle on the surface.
func reach_angle() -> float:
	return REACH / surface_radius()

## World velocity of the seam (the planet's orbital velocity).
func velocity() -> Vector2:
	return planet.linear_velocity if planet else Vector2.ZERO

func is_revealed() -> bool:
	return _revealed

func regrow_time() -> float:
	return RICH_REGROW_TIME if rich else REGROW_TIME

## Seconds until a dug-out seam refills (0 when it can be drilled). Never shown as a clock.
func regrow_left() -> float:
	var gs := _game_state()
	return gs.ore_regrow_left(ore_id()) if gs else 0.0

func is_spent() -> bool:
	return regrow_left() > 0.0

## Share of the rock still in the ground (1 = untouched, 0 = dug out).
func remaining() -> float:
	return 1.0 - _dug_shown

## Splinters and dust still in the air from the rock breaking up.
func debris_count() -> int:
	return _shards.size() + _puffs.size()

## How much of the seam the drill has broken through (0..1). The chunks crumble away to
## match; the seam only ever erodes, until it refills. Called by OreDrill as it digs.
func set_dug(share: float) -> void:
	var dug := maxf(_dug, clampf(share, 0.0, 1.0))
	if dug != _dug:
		_dug = dug
		queue_redraw()

## A dig finished here: break up what's left and start the regrow timer.
func spend() -> void:
	var gs := _game_state()
	if not gs:
		return
	gs.spend_ore(ore_id(), regrow_time())
	_was_spent = true
	set_dug(1.0)

func tracking_target() -> OreTrackingTarget:
	if not _tracking:
		_tracking = OreTrackingTarget.new(self)
	return _tracking

## Show or hide to match whether the planet has been scanned.
func refresh() -> void:
	_set_revealed(planet != null and planet.is_scanned(), false)

func _game_state() -> GameState:
	if not is_instance_valid(_gs) and is_inside_tree():
		_gs = get_tree().get_first_node_in_group("game_state") as GameState
	return _gs if is_instance_valid(_gs) else null

func _on_planet_scanned(scanned: Planet) -> void:
	if scanned == planet:
		_set_revealed(true, true)

func _set_revealed(value: bool, animate: bool) -> void:
	_revealed = value
	_was_spent = is_spent()
	# A seam that's already spent (a restored save, say) starts dug out, not mid-crumble,
	# and throws no rock - that dig was long ago
	_dug = 1.0 if _was_spent else 0.0
	_dug_shown = _dug
	_shattered = _chunks.size() if _was_spent else 0
	_shards.clear()
	_puffs.clear()
	_reveal_time = 0.0 if animate else REVEAL_TIME
	_update_visibility()
	queue_redraw()

## Hidden until the planet is scanned, and again once the rock has crumbled away and the
## last of its debris has settled.
func _update_visibility() -> void:
	visible = _revealed and (_dug_shown < 1.0 or not _shards.is_empty() or not _puffs.is_empty())

func _process(delta: float) -> void:
	if not _revealed:
		return
	var spent := is_spent()
	if _was_spent and not spent:
		# Refilled: fresh rock, surfacing again
		_reveal_time = 0.0
		_dug = 0.0
		_dug_shown = 0.0
		_shattered = 0
	elif spent:
		_dug = 1.0
	_was_spent = spent
	_reveal_time += delta
	_dug_shown = move_toward(_dug_shown, _dug, delta / CRUMBLE_TIME)
	_shatter_broken_chunks()
	_advance_debris(delta)
	_update_visibility()
	queue_redraw()

## Throw rock out of every chunk the drill has just broken into, once each.
func _shatter_broken_chunks() -> void:
	var step := 1.0 / float(maxi(_chunks.size(), 1))
	while _shattered < _chunks.size() and _dug_shown > float(_shattered) * step:
		_shatter(_chunks[_shattered])
		_shattered += 1

## One chunk gives way: splinters up out of the hole, and a puff of dust behind them.
func _shatter(chunk: Dictionary) -> void:
	var rng := _debris_rng
	var at: Vector2 = chunk["pos"]
	var size: float = chunk["size"]
	for i in rng.randi_range(SHARDS.x, SHARDS.y):
		var jag := PackedFloat32Array()
		for v in SHARD_VERTS:
			jag.append(rng.randf_range(1.0 - CHUNK_JAG, 1.0 + CHUNK_JAG))
		# Mostly up the hole (local +x), fanned out to either side
		var out := Vector2(rng.randf_range(0.4, 1.0), rng.randf_range(-0.75, 0.75)).normalized()
		_shards.append({
			"pos": at + Vector2.from_angle(rng.randf() * TAU) * size * 0.5,
			"vel": out * rng.randf_range(SHARD_SPEED.x, SHARD_SPEED.y),
			"turn": rng.randf() * TAU,
			"spin": rng.randf_range(-SHARD_SPIN, SHARD_SPIN),
			"size": rng.randf_range(SHARD_SIZE.x, SHARD_SIZE.y) * (0.6 + size / CHUNK_MAX),
			"jag": jag,
			"life": rng.randf_range(SHARD_LIFE.x, SHARD_LIFE.y),
			"age": 0.0,
		})
	for i in PUFFS:
		_puffs.append({
			"pos": at + Vector2.from_angle(rng.randf() * TAU) * size * 0.4,
			"radius": size * rng.randf_range(0.3, 0.6),
			"grow": rng.randf_range(PUFF_GROW.x, PUFF_GROW.y),
			"life": rng.randf_range(PUFF_LIFE.x, PUFF_LIFE.y),
			"age": 0.0,
		})

## Splinters arc back down into the hole; dust spreads and thins out.
func _advance_debris(delta: float) -> void:
	for i in range(_shards.size() - 1, -1, -1):
		var shard: Dictionary = _shards[i]
		shard["age"] = shard["age"] + delta
		if shard["age"] >= shard["life"]:
			_shards.remove_at(i)
			continue
		shard["vel"] = (shard["vel"] as Vector2) - Vector2(SHARD_GRAVITY * delta, 0.0)
		shard["pos"] = (shard["pos"] as Vector2) + (shard["vel"] as Vector2) * delta
		shard["turn"] = shard["turn"] + shard["spin"] * delta
	for i in range(_puffs.size() - 1, -1, -1):
		var puff: Dictionary = _puffs[i]
		puff["age"] = puff["age"] + delta
		if puff["age"] >= puff["life"]:
			_puffs.remove_at(i)
		else:
			puff["radius"] = puff["radius"] + puff["grow"] * delta

func _draw() -> void:
	var t := clampf(_reveal_time / REVEAL_TIME, 0.0, 1.0)
	var grow := ease(t, 0.4)
	var step := 1.0 / float(maxi(_chunks.size(), 1))
	# Dust hangs behind the rock
	for puff in _puffs:
		var fade: float = 1.0 - puff["age"] / puff["life"]
		draw_circle(puff["pos"], puff["radius"], Color(Colors.ORE_ROCK_EDGE, PUFF_ALPHA * fade * fade))
	for i in _chunks.size():
		# Each chunk owns a slice of the dig: it crumbles as the drill works through it
		var crumble := clampf((_dug_shown - float(i) * step) / step, 0.0, 1.0)
		if crumble >= 1.0:
			continue
		_draw_chunk(_chunks[i], grow * (1.0 - crumble * CRUMBLE_SHRINK), (1.0 - crumble) * t)
	# Splinters tumble in front of what's left
	for shard in _shards:
		_draw_shard(shard)
	# The scan surfacing the seam
	if _reveal_time < REVEAL_TIME:
		draw_arc(Vector2.ZERO, PING_RADIUS * t, 0.0, TAU, 48, Color(Colors.PRIMARY, 1.0 - t), 2.0)

## A tumbling splinter of rock, shrinking and fading as it settles.
func _draw_shard(shard: Dictionary) -> void:
	var fade: float = 1.0 - shard["age"] / shard["life"]
	var points := rock_points(shard["pos"], shard["size"] * (0.45 + 0.55 * fade), shard["turn"], shard["jag"])
	draw_colored_polygon(points, Color(Colors.ORE_ROCK, FILL_ALPHA * fade))
	points.append(points[0])
	draw_polyline(points, Color(Colors.ORE_ROCK_FACET, EDGE_ALPHA * fade), 1.0)

## One chunk of rock: a dark jagged body, a lit face toward the surface, a rim, fracture
## lines across it and a few mineral flecks. `scale` shrinks it as it breaks up (so the
## drill leaves a smaller and smaller lump before it's gone), `alpha` fades it out.
func _draw_chunk(chunk: Dictionary, scale: float, alpha: float) -> void:
	var at: Vector2 = chunk["pos"]
	var size: float = chunk["size"] * scale
	var jag: PackedFloat32Array = chunk["jag"]
	var turn: float = chunk["turn"]
	var points := rock_points(at, size, turn, jag)
	draw_colored_polygon(points, Color(Colors.ORE_ROCK, FILL_ALPHA * alpha))
	# The face turned toward the surface catches what light gets down here
	var crown := rock_points(at + Vector2(size * CROWN * 0.5, 0.0), size * (1.0 - CROWN), turn, jag)
	draw_colored_polygon(crown, Color(Colors.ORE_ROCK_EDGE, CROWN_ALPHA * alpha))
	var rim := points.duplicate()
	rim.append(rim[0])
	draw_polyline(rim, Color(Colors.ORE_ROCK_EDGE, EDGE_ALPHA * alpha), LINE_WIDTH)
	# Fractures: the lines this rock would split along
	var count := points.size()
	var cleave: int = chunk["cleave"]
	for c in CLEAVES:
		var from := (cleave + c * 2) % count
		draw_line(
			points[from],
			points[(from + count / 2) % count],
			Color(Colors.ORE_ROCK_FACET, FACET_ALPHA * alpha),
			1.0)
	for fleck in chunk["flecks"]:
		draw_circle(at + fleck * size, FLECK_RADIUS * scale, Color(Colors.ORE_FLECK, FLECK_ALPHA * alpha))

## A rough rock outline of `size` around `at`, turned by `turn` radians, with one radius
## multiplier per corner (`jag`) so no two chunks share a silhouette. The same jag also
## spaces the corners unevenly, which keeps the shape off a regular polygon.
static func rock_points(at: Vector2, size: float, turn := 0.0, jag := PackedFloat32Array()) -> PackedVector2Array:
	var count := maxi(jag.size(), 3)
	var points := PackedVector2Array()
	for i in count:
		var wobble := (jag[i] if i < jag.size() else 1.0)
		var angle := turn + TAU * i / float(count) + (wobble - 1.0) * CHUNK_SKEW
		points.append(at + Vector2.from_angle(angle) * size * wobble)
	return points

func _register_with_minimap() -> void:
	var minimap := Minimap.get_instance(get_tree())
	if minimap:
		minimap_target = OreMinimapTarget.new(self)
		minimap.register_target(minimap_target)
