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
## Three things drive it, and the loudest one wins:
## - The Void, swelling with every step deeper, until the panel doesn't come back.
## - A hit on the hull, a hard spike that decays in a fraction of a second. The
##   instruments take the blow with the ship, then steady up.
## - Titan Influence, a floor that rises one step per Module online and never drops.
##   The first two pass; this one doesn't, so after the first Gate the dashboard is
##   never quite clean again. It stays under ROT_THRESHOLD by design (TitanInfluence):
##   the Titan dims the readouts, and every so often - more often with each Module -
##   breaks in for a fraction of a second (the panel tears sideways, flickers, and its
##   readouts scramble into the Titan's purple) before handing it back exactly as it
##   was, so five Modules in the HUD is still legible.
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
var _blink_left := 0.0  ## seconds remaining in the Titan's own interruption
var _blinking := false  ## one was running last frame, so its mess needs clearing up
var _next_blink := 0.0  ## seconds until the next one
var _hit := 0.0       ## the decaying kick from the last hull hit
var _acute := false   ## something is wrong right now, as opposed to always
var _gs: GameState = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	hud = get_parent() as Control
	add_to_group("screen_effects")
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

## The loudest thing currently wrong. The Void swells, a hit spikes, and under both
## sits however much of the Titan is already awake.
func severity() -> float:
	return maxf(maxf(VoidZone.shroud, _hit), baseline())

## The Titan's share, which is simply how many Modules are online. Nothing to recover
## from: this is where the readouts sit from now on.
func baseline() -> float:
	return TitanInfluence.baseline_glitch(_influence())

func _influence() -> int:
	if not is_instance_valid(_gs):
		_gs = get_tree().get_first_node_in_group("game_state") as GameState
	return _gs.titan_influence() if _gs else 0

func _process(delta: float) -> void:
	_bind()
	if dashboard == null:
		return

	_hit = maxf(_hit - HIT_DECAY * delta, 0.0)
	var acute := maxf(VoidZone.shroud, _hit) > 0.001
	var sev := severity()

	if not acute:
		# Nothing is acutely wrong any more, so undo what the Void or a hit did to the
		# panel — but only on the way out, because the Titan's baseline runs blinks of
		# its own below and a restore every frame would hold the dashboard dark.
		if _acute or (sev <= 0.001 and not _pristine()):
			restore()
		# The panel is still now, so wherever the dashboard sits is home. Keeps the
		# anchor honest through layout passes and resolution changes - except while the
		# Titan has it torn sideways.
		if not _blinking:
			_anchor = dashboard.position
	_acute = acute

	if sev <= 0.001:
		return

	# Rot, wander and dropouts belong to whatever is acutely wrong. The Titan doesn't
	# push the dashboard around at all — it sits underneath, dimming the readouts and
	# blinking them, because a HUD that never stopped shaking couldn't be lived with.
	if acute:
		_advance_cuts(delta, sev)
		dashboard.position = _anchor + Vector2(_rng.randfn(0.0, 1.0), _rng.randfn(0.0, 1.0)) * MAX_JITTER * sev * sev
	_advance_blink(delta)
	var titan := _blink_left > 0.0
	if _blinking and not titan and not acute:
		restore()  # the Titan lets go: the panel is back exactly as it was
	_blinking = titan
	if _cut_left > 0.0:
		dashboard.modulate.a = 0.0
	elif titan:
		dashboard.modulate.a = _rng.randf_range(TitanInfluence.BLINK_FLICKER_MIN, 1.0)
	else:
		dashboard.modulate.a = lerpf(1.0, 0.55, sev)
	if titan and not acute:
		dashboard.position = _anchor + Vector2(_rng.randf_range(-1.0, 1.0) * TitanInfluence.BLINK_TEAR_PX, 0.0)
	_rot_labels(sev, titan)

## True while the Titan is breaking in on the dashboard.
func is_titan_glitching() -> bool:
	return _blink_left > 0.0

## Nothing of ours left on the panel: lit, still, and where the layout put it. Checked
## whenever there is no reason for a glitch at all, which includes a new game taking the
## Modules back offline mid-blink.
func _pristine() -> bool:
	return _cut_left <= 0.0 and _blink_left <= 0.0 \
			and is_equal_approx(dashboard.modulate.a, 1.0) \
			and dashboard.position == _anchor

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

## The Titan's own dropout, on its own clock. The cuts above come off a curve tuned for
## the Void's swell, which down at the baseline barely moves between one Module and
## five; the whole point here is that every Gate the player powers shows, so the Titan
## keeps its own schedule: the same short blink, steadily more often.
func _advance_blink(delta: float) -> void:
	if _blink_left > 0.0:
		_blink_left -= delta
		return
	var gap := TitanInfluence.blink_gap(_influence())
	if is_inf(gap):
		return
	_next_blink -= delta
	if _next_blink > 0.0:
		return
	_blink_left = TitanInfluence.BLINK_SEC
	var spread := TitanInfluence.BLINK_GAP_SPREAD
	_next_blink = gap * _rng.randf_range(1.0 - spread, 1.0 + spread)

func _rot_labels(sev: float, titan := false) -> void:
	var rot := smoothstep(ROT_THRESHOLD, 1.0, sev) * MAX_ROT
	if titan:
		rot = maxf(rot, TitanInfluence.BLINK_ROT)
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
		# Mustard is the readout color; damage and the void aren't, so the rot reads as
		# alarm. The Titan's interference is its own purple.
		label.modulate = Colors.PRIMARY.lerp(Colors.TITAN if titan else Colors.DANGER, rot * _rng.randf())

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

## Every glitch off at once, for a relaunch or a load.
func clear_now() -> void:
	_hit = 0.0
	restore()

func _on_respawned() -> void:
	_hit = 0.0
	restore()

## Back to a working dashboard: on respawn, and the moment nothing is wrong.
func restore() -> void:
	_cut_left = 0.0
	_next_cut = 0.0
	_blink_left = 0.0
	_blinking = false
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
