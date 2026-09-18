extends Node
class_name HudGlitch

## What goes wrong with the dashboard, from whatever is going wrong with the ship.
## Added by HUD, and inert until something gives it a reason.
##
## It runs after HUD._update_labels (children process after their parent), so it
## corrupts the finished readouts each frame rather than fighting them: characters
## rot into line noise, the panel wanders off its anchor, and it drops out in
## longer and longer cuts. The radio panel is left alone on purpose — the robot is
## the one voice still telling you what to do.
##
## Two things drive it, and the louder one wins:
## - The Void, a slow swell over half a minute that ends with the panel not coming back.
## - A hit on the hull, a hard spike that decays in a fraction of a second. The
##   instruments take the blow with the ship, then steady up.
## Low hull deliberately does NOT drive it: a player down to their last few blocks
## needs to be able to READ the hull bar, so that alarm is carried by HullSegmentBar,
## HullAlarm and the ship itself instead of by rotting the numbers.

## Below this the instruments are merely nervous; above it they start lying.
const ROT_THRESHOLD := 0.35
## Fraction of characters eaten at full severity.
const MAX_ROT := 0.7
## Pixels the panel wanders at full severity.
const MAX_JITTER := 7.0
## Longest a dropout holds, in seconds, at full severity.
const MAX_CUTOUT := 0.9
## Severity past which the panel is dark more often than it's lit.
const BLACKOUT := 0.88

## How hard a full-strength hit hits the readouts, and how long it takes to shake off.
const HIT_SEVERITY := 0.62
const HIT_DECAY := 3.2  # severity per second

var hud: Control = null
var dashboard: Control = null

var _labels: Array[Label] = []
var _clean: Array[String] = []   ## what the HUD last wrote, before we got to it
var _written: Array[String] = [] ## what we last wrote, to tell ours from theirs
var _anchor := Vector2.ZERO
var _cut_left := 0.0  ## seconds remaining in the current dropout
var _next_cut := 0.0  ## seconds until the next one
var _hit := 0.0       ## the decaying kick from the last hull hit
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	hud = get_parent() as Control
	EventBus.ship_respawned.connect(_on_respawned)
	EventBus.ship_damaged.connect(_on_ship_damaged)

## A hit scrambles the panel in proportion to how much hull it cost, and a hit that
## lands on an already-failing hull lands harder — the last block hurts most.
func _on_ship_damaged(amount: float, hull_ratio: float) -> void:
	var weight := clampf(amount / Ship.DAMAGE_REFERENCE, 0.3, 1.0)
	var desperation := 1.0 + (1.0 - clampf(hull_ratio, 0.0, 1.0)) * 0.5
	hit(HIT_SEVERITY * weight * desperation)

## Kicks the readouts by `strength` (0-1). Never lowers a bigger kick already ringing.
func hit(strength: float) -> void:
	_hit = maxf(_hit, clampf(strength, 0.0, 1.0))

## The loudest thing currently wrong. The Void swells, a hit spikes.
func severity() -> float:
	return maxf(VoidZone.dread, _hit)

func _process(delta: float) -> void:
	_bind()
	if dashboard == null:
		return

	_hit = maxf(_hit - HIT_DECAY * delta, 0.0)
	var sev := severity()
	if sev <= 0.001:
		if _cut_left > 0.0 or dashboard.position != _anchor:
			restore()
		# Clear of it all, so wherever the dashboard sits now is home. Keeps the
		# anchor honest through layout passes and resolution changes.
		_anchor = dashboard.position
		return

	_advance_cuts(delta, sev)
	dashboard.position = _anchor + Vector2(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * MAX_JITTER * sev * sev
	dashboard.modulate.a = 0.0 if _cut_left > 0.0 else lerpf(1.0, 0.55, sev)
	_rot_labels(sev)

## Deferred until the dashboard has been laid out, so the anchor we snap back to
## is the one HUD._fit_dashboard settled on.
func _bind() -> void:
	if dashboard != null:
		return
	dashboard = hud.get_node_or_null("DashboardAnchor") as Control if hud else null
	if dashboard == null:
		return
	_anchor = dashboard.position
	for node in dashboard.find_children("*", "Label", true, false):
		_labels.append(node as Label)
		_clean.append((node as Label).text)
		_written.append("")

## Dropouts get longer and closer together as it gets worse, until past BLACKOUT
## the next gap is always swallowed by the current one.
func _advance_cuts(delta: float, sev: float) -> void:
	if _cut_left > 0.0:
		_cut_left -= delta
		return
	_next_cut -= delta
	if _next_cut > 0.0:
		return
	var severity_curve := smoothstep(0.2, 1.0, sev)
	_cut_left = _rng.randf_range(0.04, MAX_CUTOUT * severity_curve)
	_next_cut = _rng.randf_range(0.15, lerpf(4.0, 0.12, severity_curve))
	if sev >= BLACKOUT:
		_cut_left = maxf(_cut_left, _next_cut)

func _rot_labels(sev: float) -> void:
	var rot := smoothstep(ROT_THRESHOLD, 1.0, sev) * MAX_ROT
	for i in _labels.size():
		var label := _labels[i]
		if not is_instance_valid(label):
			continue
		# Text the HUD rewrote this frame is fresh; anything matching our last
		# output is ours, so we corrupt the clean copy instead of the rot.
		if label.text != _written[i]:
			_clean[i] = label.text
		if rot <= 0.0:
			continue
		var out := corrupt(_clean[i], rot, _rng)
		label.text = out
		_written[i] = out
		# Mustard is the readout color; damage and the void aren't, so the rot reads as alarm.
		label.modulate = Colors.PRIMARY.lerp(Colors.DANGER, rot * _rng.randf())

## Replaces about `amount` of the characters with line noise, leaving spaces be
## so the layout doesn't shift under the corruption.
static func corrupt(text: String, amount: float, rng: RandomNumberGenerator) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		if c != " " and rng.randf() < amount:
			out += RobotFaces.GLITCH_CHARS[rng.randi() % RobotFaces.GLITCH_CHARS.length()]
		else:
			out += c
	return out

func _on_respawned() -> void:
	_hit = 0.0
	restore()

## Back to a working dashboard: on respawn, and the moment nothing is wrong.
func restore() -> void:
	_cut_left = 0.0
	_next_cut = 0.0
	if dashboard:
		dashboard.position = _anchor
		dashboard.modulate.a = 1.0
	for i in _labels.size():
		var label := _labels[i]
		if not is_instance_valid(label):
			continue
		label.modulate = Color.WHITE
		if label.text == _written[i]:
			label.text = _clean[i]
		_written[i] = ""
