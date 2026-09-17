extends ScrapNodeState
class_name ScrapInRangeState

## Ship is within harvest cone. Owns the velocity check, can_harvest indicator,
## action prompt, and the decision to begin harvesting.

var _can_harvest: bool = false

func enter() -> void:
	super.enter()
	scrap_node._register_indicator()

func exit() -> void:
	if _can_harvest:
		_can_harvest = false
		scrap_node.can_harvest_changed.emit(false)
	EventBus.action_message_changed.emit("")
	scrap_node._unregister_indicator()
	super.exit()

func process(delta: float) -> void:
	# Progress from an early release bleeds away while the beam is off.
	if scrap_node.timing and scrap_node.timing.progress > 0.0:
		scrap_node.timing.decay(delta)
		scrap_node.sync_harvest_visual()

	var ship := scrap_node._ship_in_range
	if not ship or not is_instance_valid(ship):
		scrap_node._state_machine.change_state("ScrapIdleState")
		return

	# If lock persisted through harvest but cone has since moved away, return to idle
	var cone: HarvestCone = ship.get_node_or_null("HarvestCone") as HarvestCone
	if cone and not cone.has_scrap(scrap_node):
		scrap_node._ship_in_range = null
		scrap_node._state_machine.change_state("ScrapIdleState")
		return

	var new_can_harvest := false
	if scrap_node.amount > 0 and not scrap_node._is_depleted and _ship_can_harvest(ship):
		var relative_velocity := ship.linear_velocity - scrap_node.get_orbital_velocity()
		if relative_velocity.length() < 100.0:
			new_can_harvest = true

	if new_can_harvest != _can_harvest:
		_can_harvest = new_can_harvest
		scrap_node.can_harvest_changed.emit(_can_harvest)

	if _can_harvest and Input.is_action_just_pressed("action") and _is_primary_target(ship, cone):
		_try_start_harvest()

## Only a ship under power harvests. A stranded ship's SPACE belongs to the robot's
## beacon offer, and starting a harvest would pull it out of StrandedState.
func _ship_can_harvest(ship: Ship) -> bool:
	var state := ship.state_machine.current_state if ship.state_machine else null
	return state is FlyingState or state is HarvestingState

## One extraction at a time. While the ship is focused on a live scrap, only that scrap
## answers the press; otherwise the nearest live scrap in the cone does.
func _is_primary_target(ship: Ship, cone: HarvestCone) -> bool:
	var harvesting := ship.state_machine.current_state as HarvestingState if ship.state_machine else null
	if harvesting and harvesting._focus_alive():
		return harvesting.focus == scrap_node
	if not cone:
		return true
	var best: ScrapNode = null
	var best_d := INF
	for s in cone.get_scraps_in_cone():
		if not is_instance_valid(s) or s._is_depleted or s.amount <= 0:
			continue
		var d := ship.global_position.distance_squared_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best == null or best == scrap_node

func _try_start_harvest() -> void:
	var ship := scrap_node._ship_in_range
	if not ship or not is_instance_valid(ship):
		return
	# A full hold doesn't block harvesting: loose gems wait in space.
	scrap_node._state_machine.change_state("ScrapHarvestingState")
