extends ScrapNodeState
class_name ScrapHarvestingState

## Active extraction: beam fires while `action` is held and HarvestTiming sweeps.
## Releasing grades the attempt: EARLY returns to ScrapInRangeState with progress kept;
## anything else is a hit that knocks gems loose. The last hit breaks the scrap and
## moves to ScrapDepletedState; earlier hits arm a fresh timing and return to InRange.
## Ship's HarvestingState stays focused on this scrap between hits and manages its own exit.

func enter() -> void:
	super.enter()
	if not scrap_node.timing:
		scrap_node.timing = HarvestTiming.new(null, scrap_node.is_trophy)
	scrap_node.harvest_started.emit()
	var sparkles := scrap_node.get_node_or_null("SparkleParticles") as SparkleParticles
	if sparkles and is_instance_valid(sparkles):
		sparkles.set_harvesting(scrap_node._ship_in_range, scrap_node.color, scrap_node.health_component)

	var ship := scrap_node._ship_in_range
	if ship and is_instance_valid(ship):
		var ship_sm: StateMachine = ship.get_node_or_null("StateMachine") as StateMachine
		if ship_sm and ship_sm.has_state("HarvestingState"):
			var harvesting_state: HarvestingState = ship_sm.states.get("HarvestingState") as HarvestingState
			if harvesting_state:
				harvesting_state.focus_on(scrap_node)
				if not ship_sm.current_state is HarvestingState:
					ship_sm.change_state("HarvestingState")
	EventBus.harvest_began.emit(scrap_node)

func exit() -> void:
	var sparkles := scrap_node.get_node_or_null("SparkleParticles") as SparkleParticles
	if sparkles and is_instance_valid(sparkles):
		sparkles.set_idle()
	scrap_node.harvest_stopped.emit()
	# Ship's HarvestingState polls its own locked_resource_nodes and exits when all done.
	super.exit()

func process(delta: float) -> void:
	var timing := scrap_node.timing
	if Input.is_action_pressed("action"):
		var grade := timing.hold(delta)
		scrap_node.sync_harvest_visual()
		if grade == HarvestTiming.Grade.OVERLOAD:
			_hit(grade)
		return

	var grade := timing.release()
	if grade == HarvestTiming.Grade.EARLY:
		scrap_node._state_machine.change_state("ScrapInRangeState")
	else:
		_hit(grade)

func _hit(grade: HarvestTiming.Grade) -> void:
	var ship := scrap_node._ship_in_range
	scrap_node.hits_left -= 1
	var final := scrap_node.hits_left <= 0
	var drops := GemData.drops_for_hit(grade, final, scrap_node.is_trophy, RNG.rng)

	var world: Node = ship.get_parent() if ship and is_instance_valid(ship) else scrap_node.get_tree().current_scene
	Gem.burst(world, scrap_node.global_position, scrap_node.get_orbital_velocity(), drops, final, RNG.rng)
	EventBus.harvest_hit.emit(scrap_node, grade, drops, final)
	HarvestJuice.play(ship, scrap_node, grade, GemData.best_of(drops), final)

	if final:
		scrap_node.amount = 0
		scrap_node._state_machine.change_state("ScrapDepletedState")
		return
	# A fresh sweep (new zone) for the next hit; hold the key again to swing.
	scrap_node.timing = HarvestTiming.new(null, scrap_node.is_trophy)
	scrap_node.sync_harvest_visual()
	scrap_node._state_machine.change_state("ScrapInRangeState")
