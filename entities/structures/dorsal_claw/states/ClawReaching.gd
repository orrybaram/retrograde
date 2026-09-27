extends ClawState
class_name ClawReaching

## The ship is holding a load at the drop point. The arm unfolds to line the claw up with
## the load's free end, slides on and closes - and then keeps hold of it as the ship drifts,
## until the player lets go (DorsalClaw.seat) or the load leaves the tolerance, when the arm
## gives up and folds (ClawStowing).

var _from := Vector2.ZERO
var _from_angle := 0.0

func enter() -> void:
	super.enter()
	_from = claw.wrist
	_from_angle = claw.claw_angle

func process(delta: float) -> void:
	super.process(delta)
	var f := claw.reachable_load()
	if f == null:
		claw.state_machine.change_state("ClawStowing")
		return
	var xf := claw.pose_of(f)
	var grip := claw.grip_wrist(f, xf)
	var lined_up := grip + xf.x.normalized() * claw.standoff
	var u := t / claw.reach_time
	# Up and over to the line-up point for most of the time, then slide on along the load
	var over := Vector2(_from.x, minf(_from.y, lined_up.y) - 80.0)
	if u < 0.8:
		var v := ease_io(u / 0.8)
		claw.wrist = _from.bezier_interpolate(over, lined_up + Vector2(0, -40), lined_up, v)
	else:
		claw.wrist = lined_up.lerp(grip, ease_io((u - 0.8) / 0.2))
	claw.claw_angle = lerp_angle(_from_angle, claw.grip_angle(xf), ease_io(u / 0.8))
	claw.jaw = clampf((u - 0.85) / 0.15, 0.0, 1.0)
