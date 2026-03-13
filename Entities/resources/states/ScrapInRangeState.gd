extends ScrapNodeState
class_name ScrapInRangeState

## Ship is within harvest range. Owns the velocity check, can_harvest indicator,
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

func process(_delta: float) -> void:
	var ship := scrap_node._ship_in_range
	if not ship or not is_instance_valid(ship):
		return

	var new_can_harvest := false
	if scrap_node.amount > 0 and not scrap_node._is_depleted:
		var relative_velocity := ship.linear_velocity - scrap_node.get_orbital_velocity()
		if relative_velocity.length() < 100.0:
			new_can_harvest = true

	if new_can_harvest != _can_harvest:
		_can_harvest = new_can_harvest
		scrap_node.can_harvest_changed.emit(_can_harvest)

	if _can_harvest and Input.is_action_just_pressed("action"):
		_try_start_harvest()

func _try_start_harvest() -> void:
	var ship := scrap_node._ship_in_range
	if not ship or not is_instance_valid(ship):
		return

	# Don't start if ship is already in a HarvestingState
	var ship_sm := ship.get_node_or_null("StateMachine") as StateMachine
	if ship_sm and ship_sm.current_state and ship_sm.current_state is HarvestingState:
		return

	if InventoryManager.get_remaining_capacity(ship.max_cargo_weight) <= 0:
		EventBus.action_message_changed.emit("Cargo full!")
		return

	scrap_node._state_machine.change_state("ScrapHarvestingState")
