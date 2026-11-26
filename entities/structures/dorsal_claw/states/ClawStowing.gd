extends ClawState
class_name ClawStowing

## Jaws open, the arm lifts straight up clear of whatever it let go of, and folds back into a
## fin. A load left on the pad is taken below as the arm clears it (DorsalClaw.sink).

var _from := Vector2.ZERO
var _from_angle := 0.0
var _sunk := false

func enter() -> void:
	super.enter()
	_from = claw.wrist
	_from_angle = claw.claw_angle
	_sunk = false

func process(delta: float) -> void:
	super.process(delta)
	var open := claw.open_time
	claw.jaw = clampf(1.0 - t / open, 0.0, minf(claw.jaw, 1.0))
	if t < open:
		return
	var u := (t - open) / claw.stow_time
	var lift := Vector2(_from.x, minf(_from.y, claw.carry_height) - 10.0)
	if u < 0.35:
		claw.wrist = _from.lerp(lift, ease_io(u / 0.35))
	else:
		claw.wrist = lift.lerp(claw.stow_wrist, ease_io((u - 0.35) / 0.65))
		if not _sunk:
			_sunk = true
			claw.sink()
	claw.claw_angle = lerp_angle(_from_angle, 0.0, ease_io(u))
	if u >= 1.0:
		claw.wrist = claw.stow_wrist
		claw.state_machine.change_state("ClawStowed")
