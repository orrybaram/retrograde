extends Control
class_name BoostGauge

## The boost gauge wrapped around the minimap's right rim. Fuel only ever pays for the
## boost, so the tank reads as blocks climbing the rim (one per FUEL_PER_BLOCK, the same
## unit as the hull bar), and a bar outside their lower half shows what the engine is
## putting out right now: 1x on ordinary thrust, the boost multiplier on a burn. Ordinary
## thrust runs on aux power, so a low-fuel cough only drops the bar back to 1x.
##
## Shares the minimap's centre and sits outside its clip mask, so the arcs can draw past
## the scope's edge. HUD feeds it the tank through set_fuel; it reads the ship's wants
## itself for the engine bar.

const FUEL_PER_BLOCK := 10.0
## Half-sweep of the fuel arc either side of 3 o'clock. y is down, so +ARC is the bottom.
const ARC := deg_to_rad(62.0)
## Radial distances outside the minimap rim, px, and stroke widths.
const FUEL_OFFSET := 8.0
const FUEL_WIDTH := 6.0
const BLOCK_GAP := 2.0
const ENGINE_OFFSET := 17.0
const ENGINE_WIDTH := 4.0
## The engine bar runs from the bottom of the fuel arc to 3 o'clock, 0x to this.
## The boost multiplier sits just under it, so the rust band at the top is short.
const ENGINE_SCALE := 3.0
## How fast the bar chases the engine, per second, rising and falling.
const ENGINE_RISE := 10.0
const ENGINE_FALL := 4.0
## How far the bar flutters on a burn, in multiplier units.
const FLUTTER := 0.15
## Alpha the fuel blocks drop to on the dim half of a low-fuel blink.
const BLINK_DIM := 0.35

@export var rim_center := Vector2(80, 80)
@export var rim_radius := 70.0

var ship: Ship = null
var fuel := 0.0
var max_fuel := 100.0
var engine := 0.0  # shown multiplier, eased toward engine_output()

var _burning := false
var _flutter := 0.0
var _rng := RandomNumberGenerator.new()  # VFX: never RNG.rng, it would shift gameplay rolls

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_fuel(current: float, max_val: float) -> void:
	fuel = current
	max_fuel = max_val
	queue_redraw()

## The tank's color steps down toward rust as it empties.
static func fuel_color(current: float, max_val: float) -> Color:
	var percent := (current / max_val * 100.0) if max_val > 0.0 else 0.0
	if current <= 0.0:
		return Colors.FUEL_EMPTY
	if percent <= 12.5:
		return Colors.FUEL_EIGHTH
	if percent <= 25.0:
		return Colors.FUEL_QUARTER
	if percent <= 50.0:
		return Colors.FUEL_HALF
	if percent <= 75.0:
		return Colors.FUEL_THREE_QUARTERS
	return Colors.FUEL_FULL

static func block_count(max_val: float) -> int:
	return ceili(max_val / FUEL_PER_BLOCK)

## How full block `i` (0 = bottom) is, 0..1.
static func block_fill(current: float, i: int) -> float:
	return clampf(current / FUEL_PER_BLOCK - i, 0.0, 1.0)

## The thrust multiplier the engine is putting out. The boost only multiplies thrust,
## so boosting without thrusting is still nothing.
static func engine_output(thrusting: bool, boosting: bool, boost_multiplier: float) -> float:
	if not thrusting:
		return 0.0
	return boost_multiplier if boosting else 1.0

## Whether the blink is on its dim half at time `t`. Low fuel blinks, critical blinks
## faster. A dry tank holds still: a new game starts on one, and a gauge flashing from
## the first frame is noise.
static func blink_dim(current: float, max_val: float, t: float) -> bool:
	var level := LowFuelEffect.level_for(current, max_val)
	if current <= 0.0 or level == LowFuelEffect.Level.OK:
		return false
	var period := 0.5 if level == LowFuelEffect.Level.CRITICAL else 1.0
	return fmod(t, period) > period * 0.6

func _process(delta: float) -> void:
	var target := 0.0
	_burning = false
	if ship and is_instance_valid(ship) and not ship.is_locked_to_planet() and not ship.is_landed_on_planet():
		var coughing := ship.low_fuel_effect != null and ship.low_fuel_effect.is_coughing()
		var thrusting := ship.want_thrust or ship.want_reverse_thrust
		_burning = thrusting and ship.want_boost and ship.fuel > 0.0 and not coughing
		target = engine_output(thrusting, _burning, ship.boost_power_multiplier)
	var rate := ENGINE_RISE if target > engine else ENGINE_FALL
	engine += (target - engine) * minf(1.0, delta * rate)
	_flutter = _rng.randf_range(-FLUTTER, FLUTTER) * 0.5 if _burning else 0.0
	queue_redraw()

func _draw() -> void:
	_draw_fuel()
	_draw_engine()

func _draw_fuel() -> void:
	var total := block_count(max_fuel)
	if total <= 0:
		return
	var r := rim_radius + FUEL_OFFSET
	var span := ARC * 2.0 / total
	var gap := BLOCK_GAP / r
	var color := fuel_color(fuel, max_fuel)
	if blink_dim(fuel, max_fuel, Time.get_ticks_msec() / 1000.0):
		color.a = BLINK_DIM
	for i in total:
		var bottom := ARC - i * span - gap / 2.0
		var top := bottom - span + gap
		_arc(r, bottom, top, Colors.PRIMARY_DIM, FUEL_WIDTH)
		var fill := block_fill(fuel, i)
		if fill > 0.0:
			_arc(r, bottom, lerpf(bottom, top, fill), color, FUEL_WIDTH)

func _draw_engine() -> void:
	var r := rim_radius + ENGINE_OFFSET
	var boost := ship.boost_power_multiplier if ship and is_instance_valid(ship) else 2.667
	_arc(r, _engine_angle(0.0), _engine_angle(ENGINE_SCALE), Color(Colors.PRIMARY_DIM, 0.6), ENGINE_WIDTH)
	_arc(r, _engine_angle(boost), _engine_angle(ENGINE_SCALE), Color(Colors.DANGER, 0.6), ENGINE_WIDTH)
	var shown := clampf(engine + _flutter, 0.0, ENGINE_SCALE)
	if shown > 0.03:
		_arc(r, _engine_angle(0.0), _engine_angle(shown), Colors.CREAM if _burning else Colors.MUSTARD_PALE, ENGINE_WIDTH)
	# One tick where ordinary thrust tops out
	var cruise := Vector2.from_angle(_engine_angle(1.0))
	var outer := r + ENGINE_WIDTH / 2.0
	draw_line(rim_center + cruise * (outer + 1.0), rim_center + cruise * (outer + 4.0), Colors.PRIMARY, 1.0)

## 0x sits at the bottom of the fuel arc, ENGINE_SCALE at 3 o'clock.
func _engine_angle(multiplier: float) -> float:
	return lerpf(ARC, 0.0, multiplier / ENGINE_SCALE)

func _arc(r: float, from: float, to: float, color: Color, width: float) -> void:
	var points := maxi(2, ceili(absf(to - from) / deg_to_rad(4.0)) + 1)
	draw_arc(rim_center, r, from, to, points, color, width, false)
