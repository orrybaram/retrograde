extends Node2D
class_name StationLights

## SR-7's running lights and windows. Dark glass and dead lenses while the station has no
## power; lit once the core is running (StationPower). Coming on while the player
## watches, they catch one by one, slowly, outward from the core where the power comes from,
## each with a flicker, so the station wakes up rather than switching on. `woken` fires as
## the last one catches.

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

var windows := PackedVector2Array()
var beacons := PackedVector2Array()
var lit := false

var _clock := 0.0
var _waking := false
## Seconds until each light (windows, then beacons) catches, while waking.
var _delays := PackedFloat32Array()

func _ready() -> void:
	if windows.is_empty():
		windows = default_windows()
	if beacons.is_empty():
		beacons = default_beacons()

## Two windows on each ring pod, a row along each module and the hub.
static func default_windows() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 8:
		var x := -350.0 + i * 100.0
		out.append(Vector2(x - 18, -380))
		out.append(Vector2(x + 18, -380))
	for x: float in [-190.0, -148.0, -106.0, -25.0, 0.0, 25.0, 106.0, 148.0, 190.0]:
		out.append(Vector2(x, -228))
	for j in 9:
		out.append(Vector2(-160 + j * 40, -134))
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

func _draw() -> void:
	for i in windows.size():
		var r := Rect2(windows[i] - WINDOW_SIZE * 0.5, WINDOW_SIZE)
		if _showing(i):
			draw_rect(r.grow(4.0), Color(Colors.SUN, 0.08))
			draw_rect(r.grow(1.5), Color(Colors.SUN, 0.2))
			draw_rect(r, Color(Colors.SUN, 0.9))
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
