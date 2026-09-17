extends ScrapNodeState
class_name ScrapHarvestingState

## Active harvesting: beam fires, HP drains, ship velocity is locked.
## Transitions to ScrapInRangeState on action release, or ScrapDepletedState on HP zero.
## Ship's HarvestingState manages its own exit; this state does not force it.

func enter() -> void:
	super.enter()
	scrap_node.harvest_started.emit()
	scrap_node.health_component.died.connect(_on_depleted)
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

func exit() -> void:
	if scrap_node.health_component.died.is_connected(_on_depleted):
		scrap_node.health_component.died.disconnect(_on_depleted)

	var sparkles := scrap_node.get_node_or_null("SparkleParticles") as SparkleParticles
	if sparkles and is_instance_valid(sparkles):
		sparkles.set_idle()
	scrap_node.harvest_stopped.emit()
	# Ship's HarvestingState polls its own locked_resource_nodes and exits when all done.
	super.exit()

func process(delta: float) -> void:
	if Input.is_action_pressed("action"):
		scrap_node.health_component.take_damage(scrap_node.harvest_rate * delta)
		scrap_node._update_visual()
	else:
		scrap_node._state_machine.change_state("ScrapInRangeState")

func _on_depleted() -> void:
	var ship := scrap_node._ship_in_range
	var max_cargo := ship.max_cargo_weight if ship and is_instance_valid(ship) else 5.0

	var tier: TierData.Tier
	if scrap_node.is_trophy:
		tier = TierData.roll_tier_trophy(RNG.rng)
	else:
		tier = TierData.roll_tier(RNG.rng)

	var tier_item_id := TierData.get_item_id(tier)
	var tier_name := TierData.get_display_name(tier)

	if not InventoryManager.can_add_item(tier_item_id, 1, max_cargo):
		EventBus.action_message_changed.emit("Cargo full!")
		scrap_node.health_component.reset()
		scrap_node._state_machine.change_state("ScrapInRangeState")
		return

	InventoryManager.add_item(tier_item_id, 1)
	scrap_node.resource_harvested.emit(1, scrap_node.kind, scrap_node.global_position, tier_name)

	if ship and is_instance_valid(ship):
		var mult: float = ScrapNode.TIER_SHAKE_MULT.get(tier_item_id, 1.0)
		ship.damage_shake_time = ship.harvest_shake_duration
		ship.damage_shake_current_intensity = ship.harvest_shake_intensity * mult

	var sparkles := scrap_node.get_node_or_null("SparkleParticles") as SparkleParticles
	if sparkles and is_instance_valid(sparkles):
		sparkles.pop(tier_item_id)
	scrap_node.amount = 0
	scrap_node._state_machine.change_state("ScrapDepletedState")
