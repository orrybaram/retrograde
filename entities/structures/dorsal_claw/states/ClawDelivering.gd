extends ClawState
class_name ClawDelivering

## The player has let go: the claw has the load. It lifts it clear of the right mast, swings
## it round over the bay, turning it level and Lug outboard, and sets it down on the pad.

var _from := Vector2.ZERO
var _from_rot := 0.0

func enter() -> void:
	super.enter()
	claw.jaw = 1.0
	var xf := claw.pose_of(claw.piece)
	_from_rot = xf.get_rotation()
	# Where the wrist is on the load right now: if the player let go before the claw got
	# there, it is taken where it is
	_from = claw.grip_wrist(claw.piece, xf)
	claw.wrist = _from

func process(delta: float) -> void:
	super.process(delta)
	var f := claw.piece
	if f == null or not is_instance_valid(f):
		claw.state_machine.change_state("ClawStowing")
		return
	var slot := claw.slot_wrist()
	var above := Vector2(slot.x, claw.carry_height)
	var r := PI
	if t < claw.swing_time:
		var v := ease_io(t / claw.swing_time)
		claw.wrist = _from.bezier_interpolate(Vector2(_from.x, claw.carry_height - 110.0), Vector2(above.x, claw.carry_height - 70.0), above, v)
		r = lerp_angle(_from_rot, PI, v)
		claw.claw_angle = claw.grip_angle(Transform2D(r, Vector2.ZERO))
	else:
		var v := ease_io((t - claw.swing_time) / claw.set_time)
		claw.wrist = above.lerp(slot, v)
		claw.claw_angle = 0.0
		if v >= 1.0:
			claw.wrist = slot
			f.transform = claw.held_pose(f, slot, PI)
			claw.state_machine.change_state("ClawStowing")
			return
	f.transform = claw.held_pose(f, claw.reachable(claw.wrist), r)
