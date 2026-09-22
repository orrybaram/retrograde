extends Node2D
class_name CommDish

## SR-7's comm dish, on its post below the keel. The station never turns, but it goes round
## the Sun, so the dish swings to keep its bowl on the Sun. Its local +x is the way the bowl faces.
## With the station dead (StationPower) it has no drive: it hangs limp off its post, bowl
## down, swaying a little. Power back, it swings slowly up and finds the Sun again, and
## once it is on the Sun it sends out one great ping in the Titan's purple - SR-7 is back
## on the air, and on whose frequency is left for the player to wonder. From then on, with
## the power on, a Sweep that reaches the dish is answered with the same great ping.

signal settled  ## Power back, and it has found the Sun.

## Limp: the bowl hangs this far round from the post's +x (down and a touch out), and
## sways this much either way, this slowly.
const LIMP_ANGLE := deg_to_rad(115.0)
const SWAY := deg_to_rad(4.0)
const SWAY_PERIOD := 5.0
## How fast it swings between the two (radians/s at a full turn's error).
const SWING_RATE := 2.5
## Coming back up under power it swings this much slower: a heavy dish, straining.
const WAKE_SWING_RATE := 0.8
## On the Sun to within this: settled.
const SETTLE_ANGLE := deg_to_rad(1.5)
## The ping it sends once settled: this many ordinary Sweep rings' reach - broadcast far,
## but faint: it must not read as a strong signal - drawn this bright
## and thick.
const PING_STRENGTH := 12.0
const PING_ALPHA := 0.3
const PING_WIDTH := 2.5
## How long the dish glows purple as it pings, and how long after a ping it won't answer
## another - its own ring reaches it the instant it leaves.
const PING_GLOW_TIME := 0.9
const PING_COOLDOWN := 2.5

var limp := false:
	set(on):
		if limp and not on:
			_waking = true  # swinging up under power, to ping once it is there
		limp = on
var _clock := 0.0
var _settled := false
var _waking := false
var _pulse: SonarPulse
var _cooldown := 0.0
var _glow: Tween

func _ready() -> void:
	add_to_group("sonar_listeners")

## A Sweep reaches the middle of the dish.
func sonar_point() -> Vector2:
	return global_position

## Pinged with the power on and the dish up on the Sun, it answers with the same great
## ping it came back on the air with. Dead, or still swinging up, it says nothing.
func on_sonar_touched(_strength := 1.0) -> void:
	if can_answer():
		ping()

func can_answer() -> bool:
	return not limp and not _waking and _settled and _cooldown <= 0.0

func _process(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target := limp_rotation(_clock) if limp else _sun_rotation()
	if not _settled:
		# The first frame lands where it belongs: a load shouldn't show it swinging
		rotation = target
		_settled = true
		return
	var rate := WAKE_SWING_RATE if _waking else SWING_RATE
	rotation = lerp_angle(rotation, target, minf(1.0, rate * delta))
	if _waking and absf(angle_difference(rotation, target)) <= SETTLE_ANGLE:
		_waking = false
		settled.emit()
		ping()

## SR-7 back on the air: one great ring out from the dish, reaching everything a Sweep
## would - scrap lights up out of the debris across the ring.
func ping() -> void:
	if _pulse == null:
		_pulse = SonarPulse.new()
		_pulse.name = "Ping"
		add_child(_pulse)
	_cooldown = PING_COOLDOWN
	_pulse.send(PING_STRENGTH, PING_ALPHA, PING_WIDTH, Colors.TITAN)
	# The dish itself lights up purple and fades back to its own colours (its parts only,
	# not the ring riding on it)
	if _glow:
		_glow.kill()
	_glow = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	for part in get_children():
		if part is CanvasItem and part != _pulse:
			part.modulate = Colors.TITAN.lerp(Colors.CREAM, 0.25)
			_glow.tween_property(part, "modulate", Color.WHITE, PING_GLOW_TIME)
	EventBus.sonar_pulsed.emit(global_position)
	_pulse._reach_listeners(global_position, PING_STRENGTH)

## A load or a new game: no swing, no ping - it is simply where it belongs next frame.
func cancel_wake() -> void:
	_waking = false
	_settled = false

func is_waking() -> bool:
	return _waking

## Where a limp dish hangs `t` s in, in its parent's space.
static func limp_rotation(t: float) -> float:
	return LIMP_ANGLE + sin(t * TAU / SWAY_PERIOD) * SWAY

func _sun_rotation() -> float:
	var parent := get_parent() as Node2D
	var world := (VoidZone.sun_position() - global_position).angle()
	return world - (parent.global_rotation if parent else 0.0)
