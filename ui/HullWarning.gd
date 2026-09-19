extends Control
class_name HullWarning

## The loudest hull warning: a banner across the top of the screen while the hull is
## failing. Added by HUD, and deliberately NOT a child of DashboardAnchor — HudGlitch
## rots everything under that anchor, and the one line telling the player what is wrong
## is the one line that has to stay readable through a hit.
##
## Blinks rather than sitting lit, on the same clock as HullSegmentBar and HullAlarm,
## so the bar, the rim of the screen and this all pulse as one warning.

const MARGIN_TOP := 26.0
## Pulses per second at each level, matching HullSegmentBar.PULSE_HZ.
const PULSE_HZ := {LowHullEffect.Level.LOW: 1.2, LowHullEffect.Level.CRITICAL: 2.6}
## Fraction of each cycle the banner is dark. CRITICAL is lit more of the time.
const DARK_FRACTION := {LowHullEffect.Level.LOW: 0.45, LowHullEffect.Level.CRITICAL: 0.3}
const TEXT := {
	LowHullEffect.Level.LOW: "H U L L   B R E A C H",
	LowHullEffect.Level.CRITICAL: "H U L L   C R I T I C A L",
}

var _label: Label
var _level := LowHullEffect.Level.OK

func _ready() -> void:
	add_to_group("hull_warning")
	# ..._and_offsets_preset, not set_anchors_preset: the latter rewrites the offsets to
	# preserve the current rect, and a Control built in code starts out zero-sized.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_top = MARGIN_TOP
	offset_bottom = MARGIN_TOP + 20.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Colors.DANGER)
	add_child(_label)

	visible = false
	EventBus.ship_hull_changed.connect(_on_hull_changed)
	EventBus.ship_respawned.connect(func() -> void: _set_level(LowHullEffect.Level.OK))
	set_process(false)

func _on_hull_changed(current: float, max_hull: float) -> void:
	# Zero hull is a destroyed ship; the explosion is the warning by then.
	_set_level(LowHullEffect.Level.OK if current <= 0.0 else LowHullEffect.level_for(current, max_hull))

func _set_level(level: int) -> void:
	if level == _level:
		return
	_level = level
	visible = _level != LowHullEffect.Level.OK
	set_process(visible)
	if visible:
		_label.text = TEXT[_level]

func _process(_delta: float) -> void:
	# Hidden while a full-screen panel is up: the player is reading, not flying.
	if _blocked():
		modulate.a = 0.0
		return
	var period := 1.0 / float(PULSE_HZ[_level])
	var dark: bool = fmod(Time.get_ticks_msec() / 1000.0, period) > period * (1.0 - DARK_FRACTION[_level])
	modulate.a = 0.0 if dark else 1.0

func _blocked() -> bool:
	for group in ["system_map", "pause_menu", "log_ui", "store_ui"]:
		var panel := get_tree().get_first_node_in_group(group) as CanvasItem
		if panel and panel.visible:
			return true
	return false
