extends ScrapNodeState
class_name ScrapDepletedState

## Terminal state for this spawn cycle. Runs the pop animation then returns node to pool.
## The pool resets the state machine back to ScrapIdleState via on_despawn/on_spawn.

func enter() -> void:
	super.enter()

	# Kill trophy pulse so it doesn't fight the pop tween
	if scrap_node._trophy_pulse_tween:
		scrap_node._trophy_pulse_tween.kill()
		scrap_node._trophy_pulse_tween = null

	scrap_node._pop_and_deplete()
