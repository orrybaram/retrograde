extends Control
class_name HullSegmentBar

## Segmented hull/HP display. One block per 10 HP.
## Filled blocks use amber gradient based on health %, empty blocks use dark outline.
##
## Below LowHullEffect's thresholds the bar stops being a readout and starts being a
## warning light: the filled blocks pulse, and at CRITICAL the empty ones light up
## rust red in counter-phase, so the damage is legible from the corner of the eye.
## A fresh hit flashes the whole bar for a beat.

const HP_PER_SEGMENT: float = 10.0
const SEGMENT_WIDTH: float = 10.0
const SEGMENT_HEIGHT: float = 14.0
const SEGMENT_GAP: float = 2.0

## Pulses per second at each level. CRITICAL is fast enough to feel like an alarm.
const PULSE_HZ := {LowHullEffect.Level.LOW: 1.2, LowHullEffect.Level.CRITICAL: 2.6}
## How far the pulse dips the filled blocks.
const PULSE_DEPTH := {LowHullEffect.Level.LOW: 0.35, LowHullEffect.Level.CRITICAL: 0.6}
## Seconds the bar stays lit after a hit.
const HIT_FLASH := 0.35

var current_hull: float = 100.0
var max_hull: float = 100.0

var _level := LowHullEffect.Level.OK
var _flash := 0.0

func _ready() -> void:
	EventBus.ship_damaged.connect(_on_ship_damaged)
	set_process(false)

func set_value(current: float, max_val: float) -> void:
	current_hull = current
	max_hull = max_val
	_level = LowHullEffect.level_for(current, max_val)
	# Only burn a _process on the bar while there is something to animate.
	set_process(_level != LowHullEffect.Level.OK or _flash > 0.0)
	custom_minimum_size.x = _total_segments() * (SEGMENT_WIDTH + SEGMENT_GAP) - SEGMENT_GAP
	custom_minimum_size.y = SEGMENT_HEIGHT
	queue_redraw()

func _on_ship_damaged(_amount: float, _hull_ratio: float) -> void:
	_flash = HIT_FLASH
	set_process(true)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	if _level == LowHullEffect.Level.OK and _flash <= 0.0:
		set_process(false)
	queue_redraw()

func _total_segments() -> int:
	return ceili(max_hull / HP_PER_SEGMENT)

func _draw() -> void:
	var total = _total_segments()
	if total <= 0:
		return

	var filled = ceili(current_hull / HP_PER_SEGMENT)
	filled = clampi(filled, 0, total)
	var hull_percent = (current_hull / max_hull * 100.0) if max_hull > 0 else 0.0
	var fill_color = _hull_color(hull_percent)
	var empty_color = Colors.PRIMARY_DIM

	var pulse := _pulse()
	if _level == LowHullEffect.Level.LOW:
		fill_color.a *= lerpf(1.0 - PULSE_DEPTH[_level], 1.0, pulse)
	elif _level == LowHullEffect.Level.CRITICAL:
		# The last blocks brighten rather than dim. Lighting the EMPTY blocks would read
		# as more alarming and would be a lie — it makes one block of hull look like ten,
		# which is the one thing this bar must never do.
		fill_color = fill_color.lerp(Colors.CREAM, pulse * PULSE_DEPTH[_level])
	# A hit whites the bar out for a beat, whatever the level.
	if _flash > 0.0:
		var t := _flash / HIT_FLASH
		fill_color = fill_color.lerp(Colors.CREAM, t)
		empty_color = empty_color.lerp(Colors.DANGER, t)

	for i in range(total):
		var x = i * (SEGMENT_WIDTH + SEGMENT_GAP)
		var rect = Rect2(x, 0, SEGMENT_WIDTH, SEGMENT_HEIGHT)
		if i < filled:
			draw_rect(rect, fill_color)
		else:
			draw_rect(rect, empty_color)

## 0..1 triangle-ish wave on the wall clock, so every hull readout on screen pulses
## together instead of each keeping its own phase.
func _pulse() -> float:
	if _level == LowHullEffect.Level.OK:
		return 1.0
	var hz: float = PULSE_HZ[_level]
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * hz)

func _hull_color(percent: float) -> Color:
	if percent < 10:
		return Colors.FUEL_EMPTY
	elif percent < 30:
		return Colors.FUEL_QUARTER
	elif percent < 60:
		return Colors.FUEL_HALF
	else:
		return Colors.PRIMARY
