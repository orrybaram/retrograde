extends RigidBody2D
class_name Gate

## The dormant Gate in orbit around a planet. Powering it brings that planet's Module
## online; a Module never goes back offline, so a Gate is powered once and stays powered.
##
## Drawn in code: seven quarried blocks set in a ring, weathered at the edges, thick
## enough to throw a shadow on their outer face and to show a cut end where each one
## stops. The whole inner face is carved with a script nobody has read in a long time.
## A docking cradle lies across the gap they leave at the bottom.
##
## The block at the top is the keystone: wider than the rest, standing proud of the
## ring, carrying a sigil no other block does and the one amber blinker that is still
## running while the Gate is dead. It is what a pilot lines up on coming in.
##
## Powering the Module lights what is cut into the Gate, not the rock: the script wakes
## up and a reading head travels it, the sigil comes up, and the channel behind the
## blocks fills with the Titan's purple. The stone itself only catches the spill.
##
## Orbits its parent planet with the same OrbitalMotion component the station uses, and
## docks with the same rules as a port: the cradle is the dock surface, the ship comes
## in slow and lined up, and GateDockedState clamps it there.
##
## Unidentified until flown to (CONTEXT.md): it is an unnamed ring on the minimap until
## the ship gets inside Identifiable.RANGE of it, at which point the Guide says what it
## is and the chart names it. The Guide never points at one beforehand (docs/adr/0002).
##
## One Gate in the system is not a planet's: the Core's Gate at the Sun Station, which
## waits on all five Modules rather than on credits (`is_core`).

const OrbitalMotionClass = preload("res://scripts/OrbitalMotion.gd")
const MSG_IDENTIFIED = preload("res://entities/Robot/radio/messages/gate_identified.tres")

## Ring radius; the Gate reads about 200 px across.
const RADIUS := 100.0
## Blocks around the ring, and the mouth they leave open at the bottom.
const SEGMENTS := 7
const MOUTH_ANGLE := deg_to_rad(52.0)
## How thick a block is, radially.
const RING_WIDTH := 42.0
## The keystone: which block it is, how much wider than the others, and how far it
## stands out past the ring. SEGMENTS is odd so the middle block sits dead opposite
## the mouth, at the top.
const KEYSTONE := 3
const KEYSTONE_WIDE := 1.5
const KEYSTONE_PROUD := 9.0
## The script is laid out by arc length, so a wider block simply carries more of it.
const GLYPH_SPACING := 13.0
## How much of the ring the reading head lights behind it, as a share of the whole.
const READ_TAIL := 0.26
## Half the width of the docking cradle laid across the mouth.
const CRADLE_HALF := 44.0
## How close the ship has to be to the cradle to dock (the port's range).
const DOCK_DISTANCE := 60.0
## Seconds for the ring to come up to full once the Module is online.
const POWER_UP_TIME := 1.6
## One slow blinker while dormant: seconds per cycle, and the share of it lit.
const BLINK_PERIOD := 2.4
const BLINK_DUTY := 0.18

## The Modules the Titan is made of, one per planet. The Core is a separate, final
## state, not a sixth Module.
const MODULE_COUNT := 5

## What the Titan asks for this Module, in credits.
@export var power_cost: int = 600

## The Core's Gate, beside the Sun Station: the Titan's sixth part rather than a
## planet's Module. It takes power only once all five Modules are online, it is never
## a transit destination, and powering it is the endgame — still to be designed, so
## for now it sits there inert.
@export var is_core: bool = false

# Orbital parameters (passed to OrbitalMotion component)
@export var orbital_distance: float = 10000.0
@export_range(0, 100) var orbital_speed: float = 3.0
@export_range(0, 360) var initial_angle_degrees: float = 0.0
var initial_angle: float:
	get: return deg_to_rad(initial_angle_degrees)
@export var enable_orbiting: bool = true

## Geostationary station-keeping: a sibling body in the same orbit system (a moon,
## usually) that this Gate holds the line on. Set, the Gate takes its angle from that
## body's orbit rather than its own clock, so it sits forever on the line between the
## planet and that body — flown up to, the moon is dead ahead through the ring, and it
## never has to be chased round the planet. `orbital_distance` still says how far out
## the Gate rides, and wants to be inside the body it follows.
@export var geosync_with: NodePath

var parent_planet: Planet = null
var minimap_target: GateMinimapTarget = null
## Off in tests so identifying a Gate never touches a save file (RobotRadio does the same).
var persist := true

var _orbital_motion = null  # OrbitalMotion
## The stonework, cut once in _ready and drawn every frame after that.
var _blocks: Array[PackedVector2Array] = []
var _bounds: Array = []   # per block: {from, to, mid}
var _script_lines: Array = []  # per block: Array of {t, lines}
var _sigil := PackedVector2Array()
var _clock := 0.0
var _glow := 0.0  # 0 dormant, 1 fully powered; ramps on power-up
var _ship: Node2D = null  # cached for the identification check

## Get current orbital angle (delegates to OrbitalMotion)
var orbital_angle: float:
	get:
		return _orbital_motion.orbital_angle if _orbital_motion else 0.0

func _ready() -> void:
	add_to_group("gates")
	add_to_group("dockable")

	var parent := get_parent()
	if parent is Planet:
		parent_planet = parent as Planet
		lock_rotation = true
		_setup_orbital_motion(parent_planet)

	_cut_the_stone()

	# A Gate powered in an earlier session is already lit when the world loads
	if is_powered():
		_glow = 1.0

	_register_with_minimap.call_deferred()

func _setup_orbital_motion(body: Node2D) -> void:
	_orbital_motion = OrbitalMotionClass.new()
	_orbital_motion.auto_initialize = false
	_orbital_motion.orbital_distance = orbital_distance
	_orbital_motion.orbital_speed = orbital_speed
	_orbital_motion.initial_angle = initial_angle
	_orbital_motion.eccentricity = 0.0  # circular
	_orbital_motion.enable_orbiting = enable_orbiting
	_orbital_motion.position_mode = OrbitalMotionClass.PositionMode.LOCAL
	_orbital_motion.update_velocity = true
	add_child(_orbital_motion)
	_orbital_motion.initialize(body)
	# Deferred: the body being followed has to have built its own orbit first, and the
	# scene makes no promise about which of two siblings is ready before the other.
	_lock_to_geosync.call_deferred()

## Take the followed body's orbit as this Gate's angle source. A path that leads
## nowhere, or to something that doesn't orbit, leaves the Gate on its own orbit.
func _lock_to_geosync() -> void:
	if geosync_with.is_empty() or _orbital_motion == null:
		return
	var body := get_node_or_null(geosync_with)
	if body == null:
		push_warning("Gate %s: geosync_with points at nothing (%s)" % [name, geosync_with])
		return
	var source = body.get("_orbital_motion")
	if source == null:
		push_warning("Gate %s: %s has no orbit to hold station on" % [name, body.name])
		return
	_orbital_motion.angle_source = source

func _register_with_minimap() -> void:
	var minimap := Minimap.get_instance(get_tree())
	if minimap:
		minimap_target = GateMinimapTarget.new(self)
		minimap.register_target(minimap_target)

func _exit_tree() -> void:
	if minimap_target:
		var minimap := Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

# --- State -------------------------------------------------------------------

## The planet whose Module this Gate powers; the key both are saved under.
func save_key() -> String:
	return parent_planet.save_key() if parent_planet else ""

func _game_state() -> GameState:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("game_state") as GameState

## True once this Gate's Module is online.
func is_powered() -> bool:
	var gs := _game_state()
	return gs != null and gs.is_gate_powered(save_key())

## True once the Guide has named this Gate. Until then the minimap reads `? ? ?`.
func is_identified() -> bool:
	var gs := _game_state()
	return gs != null and gs.is_gate_identified(save_key())

## Names the Gate. The Guide's line is `once` per save, so only the first Gate the
## player ever reaches gets a word about it; every later one flips silently.
## Returns true when this call is what identified it.
func identify() -> bool:
	var gs := _game_state()
	var key := save_key()
	if gs == null or key == "" or gs.is_gate_identified(key):
		return false
	gs.mark_gate_identified(key)
	EventBus.radio_message_requested.emit(MSG_IDENTIFIED)
	if persist:
		Save.save_identified_gates(PackedStringArray(gs.identified_gates.keys()))
	return true

## Identifies the Gate once the ship is close enough to make it out, and not before.
func identify_if_near(ship_position: Vector2) -> bool:
	if is_identified() or not Identifiable.in_range(ship_position, global_position):
		return false
	return identify()

## Whether the player can pay for it right now.
func can_afford(gs: GameState) -> bool:
	return gs != null and gs.credits >= power_cost

## True once every Module is online, which is all the Core's Gate is waiting for. A
## planet's Gate only ever waits on credits.
func modules_ready(gs: GameState) -> bool:
	return gs != null and gs.titan_influence() >= MODULE_COUNT

## Whether this Gate can be reached through the network once it is powered. The Core's
## Gate is the endgame, never somewhere to travel to.
func offers_transit() -> bool:
	return not is_core

## Pay the cost and bring this planet's Module online. Returns false if it is already
## online or the credits aren't there; nothing is charged in that case.
func power(gs: GameState) -> bool:
	# The Core is not a Module, and what happens when it comes online is a later
	# endgame issue: its Gate charges nothing and brings nothing online yet.
	if is_core:
		return false
	var key := save_key()
	if gs == null or key == "" or gs.is_gate_powered(key) or not can_afford(gs):
		return false
	gs.credits -= power_cost
	gs.mark_gate_powered(key)
	_glow = 0.0
	return true

# --- Dockable ----------------------------------------------------------------

## The cradle sits across the mouth at the bottom of the ring, so a docked ship
## rests inside it.
func get_dock_position() -> Vector2:
	return to_global(Vector2(0, RADIUS))

func get_dock_rotation() -> float:
	return global_rotation

func get_dock_distance() -> float:
	return DOCK_DISTANCE

func get_dock_velocity() -> Vector2:
	return linear_velocity

## The cradle's own frame: the docked ship is held just above its origin.
func get_dock_transform() -> Transform2D:
	return Transform2D(global_rotation, get_dock_position())

# --- Drawing -----------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if is_powered():
		_glow = minf(_glow + delta / POWER_UP_TIME, 1.0)
	else:
		# A Module never goes offline mid-run, but a new game clears every one of them
		# under Gates that are already lit. The ring follows the state back down rather
		# than carrying the last run's light into the new one.
		_glow = 0.0
	_watch_for_the_ship()
	queue_redraw()

## The only trigger for identification: the player flying within reach of the thing.
func _watch_for_the_ship() -> void:
	if is_identified():
		return
	if not is_instance_valid(_ship):
		_ship = get_tree().get_first_node_in_group("ship") as Node2D
	if is_instance_valid(_ship):
		identify_if_near(_ship.global_position)

func _draw() -> void:
	var stone := _stone()
	# The channel behind the blocks. Dead rock while dormant, and the way the Module's
	# light gets out once it is running.
	draw_arc(Vector2.ZERO, RADIUS, _arc_start(), _arc_start() + _arc_span(), 96,
		Colors.SPACE_BG.lerp(Colors.TITAN, _glow * 0.6), RING_WIDTH - 16.0, true)

	for i in SEGMENTS:
		_draw_block(i, stone)

	_draw_halo()
	_draw_sigil(stone)
	_draw_cradle(stone)
	_draw_blinker()

# --- The stonework -----------------------------------------------------------

## Cut the blocks and carve them, once. The weathering is random but stable: a Gate
## looks the same every time you fly back to it, and two Gates don't look alike.
##
## The generator is this Gate's own. Drawing never touches the RNG autoload — that one
## rolls gameplay, and taking numbers out of it here would shift what the game hands
## the player.
func _cut_the_stone() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("gate:" + save_key())

	var gap := deg_to_rad(3.4)
	var total := float(SEGMENTS - 1) + KEYSTONE_WIDE
	var cursor := _arc_start()
	for i in SEGMENTS:
		var arc: float = _arc_span() * (KEYSTONE_WIDE if i == KEYSTONE else 1.0) / total
		var from := cursor
		var to := cursor + arc - gap
		cursor += arc
		_bounds.append({"from": from, "to": to, "mid": (from + to) / 2.0})
		_blocks.append(_cut_block(r, from, to, i == KEYSTONE))
		_script_lines.append(_carve_script(r, from, to, i == KEYSTONE))

	# The keystone's sigil: one character, larger than the script and barred top and
	# bottom, set into the block above the writing.
	var mid: float = _bounds[KEYSTONE]["mid"]
	var strokes := _rune(r, 20.0)
	strokes.append(PackedVector2Array([Vector2(-7, 11), Vector2(7, 11)]))
	strokes.append(PackedVector2Array([Vector2(-5, -12), Vector2(5, -12)]))
	_sigil = _lay_flat(strokes, mid, RADIUS + 3.0)

## One block: both edges walked with a slow wander, so the rock reads as split and
## weathered rather than turned on a lathe.
func _cut_block(r: RandomNumberGenerator, from: float, to: float, key: bool) -> PackedVector2Array:
	var proud: float = KEYSTONE_PROUD if key else 0.0
	var outer := RADIUS + RING_WIDTH / 2.0 + proud
	var inner := RADIUS - RING_WIDTH / 2.0 - proud * 0.35
	var out_wander := _wander(r, 4.5)
	var in_wander := _wander(r, 3.0)
	var pts := PackedVector2Array()
	var steps := 7
	for s in steps + 1:
		var t := float(s) / steps
		pts.append(_polar(lerpf(from, to, t), outer + _wander_at(out_wander, t)))
	for s in range(steps, -1, -1):
		var t := float(s) / steps
		pts.append(_polar(lerpf(from, to, t), inner + _wander_at(in_wander, t)))
	return pts

## The writing along one block's inner face. Every character is laid flat against the
## ring here and kept as finished line pairs, so drawing it is just lines and a colour.
func _carve_script(r: RandomNumberGenerator, from: float, to: float, key: bool) -> Array:
	var band := RADIUS - RING_WIDTH / 2.0 + 12.0
	var count := int((to - from) * RADIUS / GLYPH_SPACING)
	var out: Array = []
	for g in count:
		var a: float = lerpf(from, to, (float(g) + 0.5) / count)
		var height := r.randf_range(7.5, 11.0) * (1.15 if key else 1.0)
		out.append({
			"t": (a - _arc_start()) / _arc_span(),
			"key": key,
			"lines": _lay_flat(_rune(r, height), a, band),
		})
	return out

## One character of the script: a stem with a few branches, and sometimes a bar across
## the head.
func _rune(r: RandomNumberGenerator, height: float) -> Array:
	var strokes: Array = []
	strokes.append(PackedVector2Array([Vector2(0, -height / 2.0), Vector2(0, height / 2.0)]))
	for i in r.randi_range(1, 3):
		var y := r.randf_range(-height / 2.0 + 1.0, height / 2.0 - 1.0)
		var w := height * r.randf_range(0.28, 0.5) * (1.0 if r.randf() < 0.5 else -1.0)
		strokes.append(PackedVector2Array([Vector2(0, y), Vector2(w, y + r.randf_range(-2.5, 2.5))]))
	if r.randf() < 0.4:
		strokes.append(PackedVector2Array([
			Vector2(-height * 0.3, -height / 2.0 - 1.5),
			Vector2(height * 0.3, -height / 2.0 - 1.5)]))
	return strokes

## Turn a character's strokes into point pairs sitting on the ring at `angle`, facing
## the centre.
func _lay_flat(strokes: Array, angle: float, radius: float) -> PackedVector2Array:
	var at := _polar(angle, radius)
	var out := PackedVector2Array()
	for stroke in strokes:
		out.append(at + (stroke[0] as Vector2).rotated(angle + PI / 2.0))
		out.append(at + (stroke[1] as Vector2).rotated(angle + PI / 2.0))
	return out

## Three harmonics with random phase. Sampled along an edge this gives rock that has
## weathered — long swells, the odd chip — where per-point randomness only ever gives
## sawtooth noise.
func _wander(r: RandomNumberGenerator, amplitude: float) -> Array:
	var out: Array = []
	for i in 3:
		out.append({
			"a": amplitude * r.randf_range(0.35, 1.0) / (i + 1.0),
			"f": (i + 1) * r.randf_range(1.6, 3.4),
			"p": r.randf() * TAU,
		})
	return out

func _wander_at(w: Array, t: float) -> float:
	var v := 0.0
	for h in w:
		v += h["a"] * sin(h["f"] * t * TAU + h["p"])
	return v

static func _polar(angle: float, radius: float) -> Vector2:
	return Vector2(cos(angle), sin(angle)) * radius

func _arc_span() -> float:
	return TAU - MOUTH_ANGLE

func _arc_start() -> float:
	return PI / 2.0 + MOUTH_ANGLE / 2.0

## Quarried rock. The stone only ever catches the spill of the Module's light; what
## actually lights up is what was cut into it.
func _stone() -> Color:
	return Colors.HULL_MID.darkened(0.18).lerp(
		Colors.HULL_MID.darkened(0.12).lerp(Colors.TITAN, 0.18), _glow)

# --- The parts ---------------------------------------------------------------

## One block: the rock, the shadow it throws outward, the lip that catches light on the
## inside, and the cut ends that show how thick it is.
func _draw_block(i: int, stone: Color) -> void:
	var b: Dictionary = _bounds[i]
	var from: float = b["from"]
	var to: float = b["to"]
	var key := i == KEYSTONE
	var proud: float = KEYSTONE_PROUD if key else 0.0

	draw_colored_polygon(_blocks[i], stone.lightened(0.07) if key else stone)
	draw_polyline(_blocks[i], stone.darkened(0.55), 2.4, true)
	draw_arc(Vector2.ZERO, RADIUS + RING_WIDTH / 2.0 + proud - 3.0, from, to, 40,
		stone.darkened(0.42), 6.0, true)
	draw_arc(Vector2.ZERO, RADIUS - RING_WIDTH / 2.0 + 4.0, from, to, 40,
		stone.lightened(0.14 if key else 0.1), 3.0, true)
	for a in [from, to]:
		draw_line(_polar(a, RADIUS - RING_WIDTH / 2.0 - proud * 0.35),
			_polar(a, RADIUS + RING_WIDTH / 2.0 + proud), stone.darkened(0.5), 3.5)

	_draw_script(i)

## The script on one block. Powered, a reading head runs the whole ring and each
## character lights as it passes, fading out behind it. Dormant, nothing runs and the
## carving is barely there at all.
func _draw_script(i: int) -> void:
	var head := fmod(_clock * 0.16, 1.0)
	for rune in _script_lines[i]:
		var behind: float = fposmod(head - rune["t"], 1.0)
		var read: float = clampf(1.0 - behind / READ_TAIL, 0.0, 1.0)
		var carve := Color(Colors.PRIMARY, 0.1 if rune["key"] else 0.07)
		var color := carve.lerp(Color(Colors.TITAN, 0.3 + 0.7 * read), _glow)
		var width := 1.3 + _glow * read * 1.2
		var lines: PackedVector2Array = rune["lines"]
		var j := 0
		while j + 1 < lines.size():
			draw_line(lines[j], lines[j + 1], color, width)
			j += 2

## The sigil on the keystone, and the light behind it. It is the one character that is
## lit while the Gate is dead — faintly, the way the blinker is.
func _draw_sigil(stone: Color) -> void:
	var mid: float = _bounds[KEYSTONE]["mid"]
	var at := _polar(mid, RADIUS + 3.0)
	var breath := 0.75 + 0.25 * sin(_clock * 1.2)
	if _glow > 0.0:
		draw_circle(at, 20.0, Color(Colors.TITAN, _glow * 0.16 * breath))
		draw_circle(at, 11.0, Color(Colors.TITAN, _glow * 0.2 * breath))
	var color := Color(Colors.PRIMARY, 0.16 * breath).lerp(
		Color(Colors.TITAN, 0.55 + 0.45 * breath), _glow)
	var j := 0
	while j + 1 < _sigil.size():
		draw_line(_sigil[j], _sigil[j + 1], color, 2.2 + _glow * 1.0)
		j += 2
	# A cut frame down both sides, so the sigil reads as set into the block.
	var b: Dictionary = _bounds[KEYSTONE]
	for edge in [b["from"] + 0.05, b["to"] - 0.05]:
		draw_line(_polar(edge, RADIUS - 14.0), _polar(edge, RADIUS + 18.0),
			stone.darkened(0.45), 2.0)

## The Module's light, bled out past the rock.
func _draw_halo() -> void:
	if _glow <= 0.0:
		return
	for i in 3:
		draw_arc(Vector2.ZERO, RADIUS + RING_WIDTH / 2.0 + i * 5.0,
			_arc_start(), _arc_start() + _arc_span(), 72,
			Color(Colors.TITAN, _glow * 0.22 / (i + 1.0)), 4.0, true)

## The cradle across the mouth: a cut stone on two footings, with the ship resting on
## it. The lit line along its head is the same light the script runs on.
func _draw_cradle(stone: Color) -> void:
	for x in [-CRADLE_HALF, CRADLE_HALF]:
		var foot := PackedVector2Array([
			Vector2(x - 9, RADIUS + 3), Vector2(x + 9, RADIUS + 4),
			Vector2(x * 1.28 + 10, RADIUS + 26), Vector2(x * 1.28 - 10, RADIUS + 25),
		])
		draw_colored_polygon(foot, stone.darkened(0.3))
		draw_polyline(foot, stone.darkened(0.55), 2.0, true)
	var slab := PackedVector2Array([
		Vector2(-CRADLE_HALF - 10, RADIUS - 8), Vector2(CRADLE_HALF + 9, RADIUS - 9),
		Vector2(CRADLE_HALF + 12, RADIUS + 8), Vector2(-CRADLE_HALF - 13, RADIUS + 7),
	])
	draw_colored_polygon(slab, stone.lightened(0.05))
	draw_polyline(slab, stone.darkened(0.55), 2.4, true)
	draw_line(Vector2(-CRADLE_HALF, RADIUS - 4), Vector2(CRADLE_HALF, RADIUS - 4),
		Color(Colors.PRIMARY, 0.12).lerp(Color(Colors.TITAN, 0.8), _glow), 2.0)

## The blinker sits on the keystone, so the thing that marks the top of the Gate and
## the thing a pilot lines up on are the same object. Powered, it holds steady in the
## Titan's purple.
func _draw_blinker() -> void:
	var at := _polar(_bounds[KEYSTONE]["mid"],
		RADIUS + RING_WIDTH / 2.0 + KEYSTONE_PROUD + 9.0)
	if _glow >= 1.0:
		draw_circle(at, 5.0, Color(Colors.TITAN, 0.3))
		draw_circle(at, 2.5, Colors.TITAN)
		return
	var lit := fmod(_clock, BLINK_PERIOD) < BLINK_PERIOD * BLINK_DUTY
	draw_circle(at, 4.0, Color(Colors.PRIMARY, 0.25 if lit else 0.06))
	draw_circle(at, 2.0, Colors.PRIMARY if lit else Colors.PRIMARY_DIM)
