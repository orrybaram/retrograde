class_name SegmentGauge
extends Control

## Segmented bar for terminal panels. `pulse` throbs the filled part (low fuel, full hold).

const HEIGHT := 12.0
const GAP := 2.0

var ratio := 0.0
var color := Colors.PRIMARY
var segments := 20
var pulse := false


func _init() -> void:
	custom_minimum_size.y = HEIGHT
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_fill(r: float, c: Color, count: int, pulsing: bool = false) -> void:
	ratio = clampf(r, 0.0, 1.0)
	color = c
	segments = maxi(count, 1)
	pulse = pulsing
	set_process(pulse)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := (size.x - GAP * (segments - 1)) / segments
	var filled := ceili(ratio * segments - 0.001)
	var fill := color
	if pulse:
		fill.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.5)
	for i in segments:
		var rect := Rect2(floorf(i * (w + GAP)), 0, maxf(floorf(w), 1.0), HEIGHT)
		if i < filled:
			draw_rect(rect, fill)
		else:
			draw_rect(rect, Colors.PRIMARY_DIM, false, 1.0)
