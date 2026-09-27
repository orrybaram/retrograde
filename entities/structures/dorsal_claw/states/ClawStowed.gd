extends ClawState
class_name ClawStowed

## Folded upright, a fin on the strip, jaws open. Waits for a laden ship to hold a load at
## the drop point.

func process(delta: float) -> void:
	super.process(delta)
	claw.jaw = move_toward(claw.jaw, 0.0, delta / claw.open_time)
	if claw.reachable_load():
		claw.state_machine.change_state("ClawReaching")
