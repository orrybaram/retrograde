extends Node
class_name VoidGlitch

## What the Void does to the dashboard. Added by HUD, and inert until VoidZone
## says the ship is out there.
##
## It runs after HUD._update_labels (children process after their parent), so it
## corrupts the finished readouts each frame rather than fighting them: characters
## rot into line noise, the panel wanders off its anchor, and it drops out in
## longer and longer cuts until the last one doesn't come back. The radio panel is
## left alone on purpose — the robot is the one voice still telling you to turn around.

## Below this the instruments are merely nervous; above it they start lying.
const ROT_THRESHOLD := 0.35
## Fraction of characters eaten at full dread.
const MAX_ROT := 0.7
## Pixels the panel wanders at full dread.
const MAX_JITTER := 7.0
## Longest a dropout holds, in seconds, at full dread.
const MAX_CUTOUT := 0.9
## Dread past which the panel is dark more often than it's lit.
const BLACKOUT := 0.88

var hud: Control = null
var dashboard: Control = null

var _labels: Array[Label] = []
var _clean: Array[String] = []   ## what the HUD last wrote, before we got to it
var _written: Array[String] = [] ## what we last wrote, to tell ours from theirs
var _anchor := Vector2.ZERO
var _cut_left := 0.0  ## seconds remaining in the current dropout
var _next_cut := 0.0  ## seconds until the next one
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	hud = get_parent() as Control
	EventBus.ship_respawned.connect(restore)

func _process(delta: float) -> void:
	_bind()
	if dashboard == null:
		return

	var dread := VoidZone.dread
	if dread <= 0.001:
		if _cut_left > 0.0 or dashboard.position != _anchor:
			restore()
		# Clear of the void, so wherever the dashboard sits now is home. Keeps the
		# anchor honest through layout passes and resolution changes.
		_anchor = dashboard.position
		return

	_advance_cuts(delta, dread)
	dashboard.position = _anchor + Vector2(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * MAX_JITTER * dread * dread
	dashboard.modulate.a = 0.0 if _cut_left > 0.0 else lerpf(1.0, 0.55, dread)
	_rot_labels(dread)

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

## Dropouts get longer and closer together as the dark settles in, until past
## BLACKOUT the next gap is always swallowed by the current one.
func _advance_cuts(delta: float, dread: float) -> void:
	if _cut_left > 0.0:
		_cut_left -= delta
		return
	_next_cut -= delta
	if _next_cut > 0.0:
		return
	var severity := smoothstep(0.2, 1.0, dread)
	_cut_left = _rng.randf_range(0.04, MAX_CUTOUT * severity)
	_next_cut = _rng.randf_range(0.15, lerpf(4.0, 0.12, severity))
	if dread >= BLACKOUT:
		_cut_left = maxf(_cut_left, _next_cut)

func _rot_labels(dread: float) -> void:
	var rot := smoothstep(ROT_THRESHOLD, 1.0, dread) * MAX_ROT
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
		# Mustard is the readout color; the void isn't, so the rot reads as alarm.
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

## Back to a working dashboard: on respawn, and the moment the ship is clear.
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
