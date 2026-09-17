extends ScrapNodeState
class_name ScrapHarvestingState

## Active extraction: beam fires while `action` is held and HarvestTiming sweeps.
## Releasing grades the attempt: EARLY returns to ScrapInRangeState with progress kept;
## anything else finishes the harvest and moves to ScrapDepletedState.
## Ship's HarvestingState manages its own exit; this state does not force it.

func enter() -> void:
	super.enter()
	if not scrap_node.timing:
		scrap_node.timing = HarvestTiming.new(RNG.rng, scrap_node.is_trophy)
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
				harvesting_state.add_locked_node(scrap_node)
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
			_finish(grade)
		return

	var grade := timing.release()
	if grade == HarvestTiming.Grade.EARLY:
		scrap_node._state_machine.change_state("ScrapInRangeState")
	else:
		_finish(grade)

func _finish(grade: HarvestTiming.Grade) -> void:
	var ship := scrap_node._ship_in_range
	var max_cargo := ship.max_cargo_weight if ship and is_instance_valid(ship) else 5.0

	var tier := TierData.roll_for_grade(grade, scrap_node.is_trophy, RNG.rng)
	var tier_item_id := TierData.get_item_id(tier)
	var tier_name := TierData.get_display_name(tier)

	if not InventoryManager.can_add_item(tier_item_id, 1, max_cargo):
		EventBus.action_message_changed.emit("Cargo full!")
		scrap_node.timing.progress = 0.0
		scrap_node.sync_harvest_visual()
		scrap_node._state_machine.change_state("ScrapInRangeState")
		return

	EventBus.harvest_finished.emit(scrap_node, grade, tier_item_id)
	InventoryManager.add_item(tier_item_id, 1)
	scrap_node.resource_harvested.emit(1, scrap_node.kind, scrap_node.global_position, tier_name)
	HarvestJuice.play(ship, scrap_node, grade, tier_item_id)

	scrap_node.amount = 0
	scrap_node._state_machine.change_state("ScrapDepletedState")
