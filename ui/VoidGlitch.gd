extends Node
class_name VoidGlitch

## The Void's glitch for an instrument that isn't the dashboard: the waypoint tracker,
## and the ship's Log with its chart. Add one as a child of the Control it wrecks; it
## runs after its parent (children process after their parent), so it corrupts the
## finished readouts each frame rather than fighting them - the same rules as
## HudGlitch, driven by the same thing: how deep into the Void the ship is
## (VoidZone.shroud). The panel wanders off its anchor, drops out in longer and longer
## cuts, and its text rots into line noise. Back inside the system it is handed back
## exactly as it was.

var target: Control = null

var _anchor := Vector2.ZERO
var _clean := {}    ## Label -> the text its owner last wrote, before we got to it
var _written := {}  ## Label -> what we last wrote, to tell ours from theirs
var _tint := {}     ## Label -> its own modulate, to hand back
var _cut_left := 0.0
var _next_cut := 0.0
var _dirty := false  ## something of ours is on the panel
## Own RNG: HUD VFX must never draw from the shared gameplay stream.
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "VoidGlitch"
	_rng.randomize()
	target = get_parent() as Control
	add_to_group("screen_effects")
	if target:
		_anchor = target.position

func _process(delta: float) -> void:
	if target == null:
		return
	var sev := VoidZone.shroud
	if sev <= 0.001:
		if _dirty:
			clear_now()
		# Still, so wherever the panel sits is home (layout passes, resolution changes).
		_anchor = target.position
		return
	_dirty = true
	_advance_cuts(delta, sev)
	target.position = _anchor + Vector2(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * HudGlitch.MAX_JITTER * sev * sev
	target.modulate.a = 0.0 if _cut_left > 0.0 else lerpf(1.0, 0.55, sev)
	_rot_labels(sev)

## Handed back exactly as it was: lit, still, where the layout put it, words intact.
func clear_now() -> void:
	_cut_left = 0.0
	_next_cut = 0.0
	_dirty = false
	if target == null:
		return
	target.position = _anchor
	target.modulate.a = 1.0
	for label in _clean.keys():
		if not is_instance_valid(label):
			continue
		label.modulate = _tint.get(label, Color.WHITE)
		if label.text == _written.get(label, ""):
			label.text = _clean[label]
	_clean.clear()
	_written.clear()
	_tint.clear()

func _advance_cuts(delta: float, sev: float) -> void:
	if _cut_left > 0.0:
		_cut_left -= delta
		return
	_next_cut -= delta
	if _next_cut > 0.0:
		return
	var severity_curve := smoothstep(0.2, 1.0, sev)
	_cut_left = _rng.randf_range(0.04, HudGlitch.MAX_CUTOUT * severity_curve)
	_next_cut = _rng.randf_range(0.15, lerpf(4.0, 0.12, severity_curve))
	if sev >= HudGlitch.BLACKOUT:
		_cut_left = maxf(_cut_left, _next_cut)

## Labels are looked up every frame: a Log tab builds its rows when it opens.
func _rot_labels(sev: float) -> void:
	var rot := smoothstep(HudGlitch.ROT_THRESHOLD, 1.0, sev) * HudGlitch.MAX_ROT
	for node in target.find_children("*", "Label", true, false):
		var label := node as Label
		# Text its owner rewrote since our last pass is fresh; anything matching our
		# last output is ours, so we corrupt the clean copy instead of the rot.
		if not _tint.has(label):
			_tint[label] = label.modulate
		if label.text != _written.get(label, "\u0000"):
			_clean[label] = label.text
		if rot <= 0.0:
			continue
		var out := HudGlitch.corrupt(_clean[label], rot, _rng)
		label.text = out
		_written[label] = out
		label.modulate = _tint[label] * Colors.PRIMARY.lerp(Colors.DANGER, rot * _rng.randf())
