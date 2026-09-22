extends FlyingState
class_name CarryingState

## Flying with Freight clamped to the nose (docs/adr/0012). Everything FlyingState does -
## thrust, turning (slowed by the load through Ship.turn_ratio), knocks, particles - except
## that `action` means one thing here: hold it to let go, anywhere - a deliberate hold, so
## a tap never drops the load. Let go within tolerance of its Mount, a Section is pulled
## home (Mount.seat), and the prompt reads RELEASE there before the hold starts. A carrying ship cannot Sweep, dock, harvest or touch down.
## Leaving this state lets go of the load, except into StrandedState - a ship that loses
## power keeps what is on its nose, and an abandoned hull keeps it after that (ADR 0011) -
## and ConsumedState, where the Void hands it back inside the edge.

## Seconds `action` must be held to let go.
const RELEASE_HOLD := 0.8
const METER_CELLS := 6

var _release_held := 0.0

func enter() -> void:
	super.enter()
	# Entered with the load already on (put back from a save), there is nothing pending
	var f: Freight = null
	if ship.has_meta("pending_freight"):
		f = ship.get_meta("pending_freight") as Freight
		ship.remove_meta("pending_freight")
	if f and is_instance_valid(f):
		ship.clamp_freight(f)
	_release_held = 0.0

func exit() -> void:
	let_go_of_freight()
	EventBus.action_message_changed.emit("")
	super.exit()

func holds_freight() -> bool:
	return true

func allows_sonar() -> bool:
	return false

## The load can go without a release (a load or a new game clears it) while a radio call
## or a menu holds the controls, so this is checked before anything else.
func physics_process(delta: float) -> void:
	if is_ship_valid() and not ship.is_carrying():
		ship.state_machine.change_state("FlyingState")
		return
	super.physics_process(delta)

func _update_action() -> void:
	if _action_armed and Input.is_action_pressed("action"):
		_release_held += get_physics_process_delta_time()
	else:
		_release_held = 0.0
	var mount := Mount.accepting(ship.get_tree(), ship.freight)
	if _release_held >= RELEASE_HOLD:
		var f := ship.freight
		ship.state_machine.change_state("FlyingState")
		# Let go within tolerance of its Mount: the Mount pulls it home
		if mount and is_instance_valid(f):
			mount.seat(f)
		return
	EventBus.action_message_changed.emit(action_label(_release_held / RELEASE_HOLD, mount != null))

## What the prompt reads: nothing until the hold starts - except RELEASE when the load
## would seat in its Mount - then the word and the bar filling.
static func action_label(progress: float, at_mount: bool) -> String:
	if progress > 0.0:
		return release_label(progress)
	return "RELEASE" if at_mount else ""

## What the prompt reads partway through the release hold: "RELEASING ███···".
static func release_label(progress: float) -> String:
	return "RELEASING " + release_meter(progress)

## The release hold as a row of cells, filling left to right: "███···".
static func release_meter(progress: float) -> String:
	var filled := clampi(int(progress * METER_CELLS), 0, METER_CELLS)
	return "█".repeat(filled) + "·".repeat(METER_CELLS - filled)

## No touching down with a load on: ground is ground, with the ordinary knocks.
func _ground_contact(_state: PhysicsDirectBodyState2D, _planet: Planet, _contact_velocity: Vector2) -> bool:
	return false
