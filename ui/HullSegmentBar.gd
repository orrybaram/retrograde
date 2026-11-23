extends Control
class_name HullSegmentBar

## Segmented hull/HP display, wrapped around the minimap's left rim: the boost gauge's
## mirror. One block per 10 HP, climbing from the bottom; filled blocks use an amber
## gradient based on health %, empty ones the dim mustard. "HP" curves along the rim
## outside the bottom blocks and goes red with the warning.
##
## Shares the minimap's centre and sits outside its clip mask, like BoostGauge.
##
## Below LowHullEffect's thresholds the bar stops being a readout and starts being a
## warning light: the filled blocks pulse, and at CRITICAL the empty ones light up
## rust red in counter-phase, so the damage is legible from the corner of the eye.
## A fresh hit flashes the whole bar for a beat.

const HP_PER_SEGMENT: float = 10.0
## Matches BoostGauge's fuel arc so the two sides of the dial mirror: half-sweep either
## side of 9 o'clock, radial offset outside the rim, stroke width, gap between blocks.
const ARC := BoostGauge.ARC
const OFFSET := BoostGauge.FUEL_OFFSET
const WIDTH := BoostGauge.FUEL_WIDTH
const BLOCK_GAP := BoostGauge.BLOCK_GAP
## "HP" outside the arc, one letter at each fraction of the sweep up from the bottom.
## Tops face the minimap like BoostGauge's AUX, lettering round the bottom of a badge, so
## on this side it reads downward, toward the bottom of the dial.
const LABEL := "HP"
const LABEL_AT := [0.11, 0.05]
const LABEL_SIZE := 8
const LABEL_OFFSET := 7.0  # letter centres, px outside the arc's outer edge

## Pulses per second at each level. CRITICAL is fast enough to feel like an alarm.
const PULSE_HZ := {LowHullEffect.Level.LOW: 1.2, LowHullEffect.Level.CRITICAL: 2.6}
## How far the pulse dips the filled blocks.
const PULSE_DEPTH := {LowHullEffect.Level.LOW: 0.35, LowHullEffect.Level.CRITICAL: 0.6}
## Seconds the bar stays lit after a hit.
const HIT_FLASH := 0.35

@export var rim_center := Vector2(80, 80)
@export var rim_radius := 70.0

var current_hull: float = 100.0
var max_hull: float = 100.0

var _level := LowHullEffect.Level.OK
var _flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.ship_damaged.connect(_on_ship_damaged)
	set_process(false)

func set_value(current: float, max_val: float) -> void:
	current_hull = current
	max_hull = max_val
	_level = LowHullEffect.level_for(current, max_val)
	# Only burn a _process on the bar while there is something to animate.
	set_process(_level != LowHullEffect.Level.OK or _flash > 0.0)
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
	var total := _total_segments()
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

	var r := rim_radius + OFFSET
	var span := ARC * 2.0 / total
	var gap := BLOCK_GAP / r
	for i in range(total):
		# 9 o'clock is PI; y is down, so PI - ARC is the bottom and the angle climbs upward.
		var bottom := PI - ARC + i * span + gap / 2.0
		var top := bottom + span - gap
		_arc(r, bottom, top, fill_color if i < filled else empty_color)
	_draw_label(r + WIDTH / 2.0 + LABEL_OFFSET)

func _arc(r: float, from: float, to: float, color: Color) -> void:
	var points := maxi(2, ceili(absf(to - from) / deg_to_rad(4.0)) + 1)
	draw_arc(rim_center, r, from, to, points, color, WIDTH, false)

## Red from LOW down, in step with the warning, so it starts at the readout.
func _draw_label(radius: float) -> void:
	var font := get_theme_default_font()
	var color := Colors.PRIMARY if _level == LowHullEffect.Level.OK else Colors.DANGER
	for i in LABEL.length():
		var letter := LABEL[i]
		var angle: float = PI - ARC + ARC * 2.0 * LABEL_AT[i]
		var glyph := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE)
		draw_set_transform(rim_center + Vector2.from_angle(angle) * radius, angle - PI / 2.0)
		draw_string(font, Vector2(-glyph.x / 2.0, font.get_ascent(LABEL_SIZE) - glyph.y / 2.0), letter,
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, color)
	draw_set_transform(Vector2.ZERO)

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
