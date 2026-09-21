extends FlyingState
class_name CarryingState

## Flying with Freight clamped to the nose (docs/adr/0012). Everything FlyingState does -
## thrust, turning (slowed by the load through Ship.turn_ratio), knocks, particles - except
## that `action` means one thing here: let go, anywhere. A carrying ship cannot Sweep,
## dock, harvest or touch down. Leaving this state for any reason lets go of the load.

func enter() -> void:
	super.enter()
	var f := ship.get_meta("pending_freight", null) as Freight
	ship.remove_meta("pending_freight")
	if f and is_instance_valid(f):
		ship.clamp_freight(f)

func exit() -> void:
	if is_ship_valid() and ship.is_carrying():
		ship.release_freight()
	EventBus.action_message_changed.emit("")
	super.exit()

func allows_sonar() -> bool:
	return false

func _update_action() -> void:
	if not ship.is_carrying():
		ship.state_machine.change_state("FlyingState")
		return
	EventBus.action_message_changed.emit(EventBus.action_prompt("RELEASE"))
	if _action_armed and Input.is_action_just_pressed("action"):
		ship.state_machine.change_state("FlyingState")

## No touching down with a load on: ground is ground, with the ordinary knocks.
func _ground_contact(_state: PhysicsDirectBodyState2D, _planet: Planet, _contact_velocity: Vector2) -> bool:
	return false
