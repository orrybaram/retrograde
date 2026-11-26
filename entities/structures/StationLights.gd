extends Node2D
class_name StationLights

## SR-7's running lights and windows. Dark glass and dead lenses while the station has no
## power; lit once the core is running (StationPower). Coming on while the player
## watches, they catch one by one, slowly, outward from the core where the power comes from,
## each with a flicker, so the station wakes up rather than switching on. `woken` fires as
## the last one catches.
##
## Nothing about them is quite regular: each window sits a little off its line, some are
## wider or narrower, a few are gone altogether (more on one side than the other), some burn
## dimmer, a handful stay dark even with the power on, and a few flicker. All of it comes
## from fixed seeds and never from the shared RNG, so it is the same station every run.

signal woken

## Where the windows and beacons sit, in the station's space.
const WINDOW_SIZE := Vector2(6, 4)
const BEACON_SIZE := 3.5
## Beacons blink: a short flash every BEACON_PERIOD s.
const BEACON_PERIOD := 2.0
const BEACON_FLASH := 0.35
## Powering up while watched: a light catches every WAKE_STEP s, flickering for
## WAKE_FLICKER s first, starting WAKE_DELAY s after the power comes in, nearest
## WAKE_ORIGIN first.
const WAKE_DELAY := 0.8
const WAKE_STEP := 0.16
const WAKE_FLICKER := 0.3
const WAKE_ORIGIN := Vector2(0, 15)  # the core (CoreHousing)

## The windows' irregularity: how far each strays off its line (px), how much wider or
## narrower it can be, and how often one is missing - the left side of the station more
## often than the right, so it stops mirroring itself.
const WINDOWS_SEED := 22
const WINDOW_NUDGE := Vector2(3.5, 1.5)
const WINDOW_WIDTHS: Array[float] = [4.0, 5.0, 6.0, 6.0, 7.0, 8.0]
const MISSING_LEFT := 0.2
const MISSING_RIGHT := 0.07
## With the power on: one window in DEAD_EVERY never lights, one in FAULTY_EVERY flickers,
## and the rest burn somewhere between DIM and full.
const DEAD_EVERY := 9
const FAULTY_EVERY := 7
const DIM := 0.55

var windows := PackedVector2Array()
var beacons := PackedVector2Array()
var lit := false
## Per window: {size, glow (0 dead), faulty}. Built for whatever `windows` holds.
var _quirks: Array[Dictionary] = []

var _clock := 0.0
var _waking := false
## Seconds until each light (windows, then beacons) catches, while waking.
var _delays := PackedFloat32Array()

func _ready() -> void:
	if windows.is_empty():
		windows = default_windows()
	if beacons.is_empty():
		beacons = default_beacons()
	_quirks = window_quirks(windows.size())

## Two windows on each ring pod, a row along each module and the hub - each nudged off its
## line, and a few missing.
static func default_windows(seed_value := WINDOWS_SEED) -> PackedVector2Array:
	var grid := PackedVector2Array()
	for i in 8:
		var x := -350.0 + i * 100.0
		grid.append(Vector2(x - 18, -380))
		grid.append(Vector2(x + 18, -380))
	for x: float in [-190.0, -148.0, -106.0, -25.0, 0.0, 25.0, 106.0, 148.0, 190.0]:
		grid.append(Vector2(x, -228))
	for j in 9:
		grid.append(Vector2(-160 + j * 40, -134))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedVector2Array()
	for p in grid:
		var missing := MISSING_LEFT if p.x < 0.0 else MISSING_RIGHT
		var nudge := Vector2(rng.randf_range(-1.0, 1.0) * WINDOW_NUDGE.x, rng.randf_range(-1.0, 1.0) * WINDOW_NUDGE.y)
		if rng.randf() < missing:
			continue
		out.append(p + nudge)
	return out

## How each of `count` windows looks: its size, how bright it burns lit (0: dead, it never
## comes on), and whether it flickers.
static func window_quirks(count: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = WINDOWS_SEED + 1
	var out: Array[Dictionary] = []
	for i in count:
		var w: float = WINDOW_WIDTHS[rng.randi_range(0, WINDOW_WIDTHS.size() - 1)]
		var h := WINDOW_SIZE.y + (1.0 if rng.randf() < 0.25 else 0.0)
		var roll := rng.randi_range(0, DEAD_EVERY * FAULTY_EVERY - 1)
		var dead := roll % DEAD_EVERY == 0
		out.append({
			"size": Vector2(w, h),
			"glow": 0.0 if dead else rng.randf_range(DIM, 1.0),
			"faulty": not dead and roll % FAULTY_EVERY == 1,
			"phase": rng.randf() * 10.0,
		})
	return out

## Mast tips, the ends of the ring, and the foot of the keel.
static func default_beacons() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-181, -542), Vector2(181, -542),
		Vector2(-400, -374), Vector2(400, -374),
		Vector2(0, 294),
	])

## Lights on or off. `instant` (a load, a new game) skips the waking flicker.
func set_lit(on: bool, instant := true) -> void:
	lit = on
	_delays.clear()
	_waking = on and not instant
	if _waking:
		_delays = wake_order_delays(windows, beacons)
	queue_redraw()

## When each light (windows, then beacons) catches, s from the power coming in: one every
## WAKE_STEP, nearest WAKE_ORIGIN first.
static func wake_order_delays(w: PackedVector2Array, b: PackedVector2Array) -> PackedFloat32Array:
	var all := w + b
	var order := range(all.size())
	order.sort_custom(func(i: int, j: int) -> bool:
		return all[i].distance_to(WAKE_ORIGIN) < all[j].distance_to(WAKE_ORIGIN))
	var out := PackedFloat32Array()
	out.resize(all.size())
	for rank in order.size():
		out[order[rank]] = WAKE_DELAY + rank * WAKE_STEP
	return out

## How long a full wake takes, s.
func wake_time() -> float:
	return WAKE_DELAY + (windows.size() + beacons.size()) * WAKE_STEP

func is_waking() -> bool:
	for d in _delays:
		if d > 0.0:
			return true
	return false

func _process(delta: float) -> void:
	_clock += delta
	for i in _delays.size():
		_delays[i] -= delta
	if _waking and not is_waking():
		_waking = false
		woken.emit()
	if lit:
		queue_redraw()

## Whether light `i` is showing right now: out until it catches, stuttering just before.
func _showing(i: int) -> bool:
	if not lit:
		return false
	if i >= _delays.size():
		return true
	var d := _delays[i]
	if d <= 0.0:
		return true
	return d < WAKE_FLICKER and fmod(d, 0.1) < 0.05

## How brightly window `i` burns right now, 0-1: its power, then its own quirks.
func window_glow(i: int) -> float:
	if not _showing(i):
		return 0.0
	if _quirks.size() != windows.size():
		_quirks = window_quirks(windows.size())
	var q := _quirks[i]
	var g: float = q["glow"]
	if q["faulty"]:
		# a bad contact: mostly on, dropping out in short stutters
		var t: float = _clock + q["phase"]
		if fmod(t, 3.7) < 0.35 and fmod(t * 9.0, 1.0) < 0.5:
			return g * 0.15
	return g

func _draw() -> void:
	if _quirks.size() != windows.size():
		_quirks = window_quirks(windows.size())
	for i in windows.size():
		var size: Vector2 = _quirks[i]["size"]
		var r := Rect2(windows[i] - size * 0.5, size)
		var g := window_glow(i)
		if g > 0.0:
			draw_rect(r.grow(4.0), Color(Colors.SUN, 0.08 * g))
			draw_rect(r.grow(1.5), Color(Colors.SUN, 0.2 * g))
			draw_rect(r, Color(Colors.SUN, 0.9 * g))
		else:
			draw_rect(r, Colors.SPACE_BG)
	var flash := fposmod(_clock, BEACON_PERIOD) < BEACON_FLASH
	for j in beacons.size():
		var at := beacons[j]
		if _showing(windows.size() + j) and flash:
			draw_circle(at, 18.0, Color(Colors.SUN, 0.1))
			draw_circle(at, 8.0, Color(Colors.SUN, 0.25))
			draw_circle(at, BEACON_SIZE, Colors.SUN)
		else:
			draw_circle(at, BEACON_SIZE, Colors.HULL_DARK)
