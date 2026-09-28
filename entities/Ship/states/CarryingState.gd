extends FlyingState
class_name CarryingState

## Flying with Freight clamped to the nose (docs/adr/0012). Everything FlyingState does -
## thrust, turning (slowed by the load through Ship.turn_ratio), knocks, particles - except
## that `action` means one thing here: hold it to let go, anywhere - a deliberate hold, so
## a tap never drops the load. Let go within tolerance of its Mount, a Section is pulled
## home (Mount.seat), a Component into SR-7's Cradle (Cradle.seat), and the prompt reads
## RELEASE there before the hold starts. A carrying ship cannot Sweep, dock, harvest or touch down.
## The ship is here exactly while it holds Freight: the only way in is Ship.carry, which
## stages the piece for enter() to clamp, and leaving lets go of whatever is still on the
## nose (the other verbs - surrender_to_void, hand_over, discard_freight - take it off first).

## Seconds `action` must be held to let go.
const RELEASE_HOLD := 0.8
const METER_CELLS := 6

var _release_held := 0.0
var _staged: Freight = null
var _staged_quiet := false

## Ship.carry: the piece the next enter() clamps, and whether without the clunk.
func stage(f: Freight, quiet: bool) -> void:
	_staged = f
	_staged_quiet = quiet

func enter() -> void:
	super.enter()
	var f := _staged
	_staged = null
	if is_ship_valid() and f and is_instance_valid(f):
		ship._clamp_freight(f, _staged_quiet)
	_release_held = 0.0
	# Only Ship.carry comes in here: without a load there is nothing to carry
	if is_ship_valid() and not ship.is_carrying():
		push_error("CarryingState entered with no Freight: use Ship.carry")
		ship.state_machine.change_state("FlyingState")

func exit() -> void:
	if is_ship_valid():
		ship._release_freight()
	EventBus.action_message_changed.emit("")
	super.exit()

## How far the release hold has got, 0 to 1 (the manual check's RELEASE row, BootLog).
func release_progress() -> float:
	return clampf(_release_held / RELEASE_HOLD, 0.0, 1.0)

func allows_sonar() -> bool:
	return false

## A safety net, not a way out: carry is the only way in and the verbs are the ways out,
## but a piece freed out from under the clamp (a scenario or a lab clearing it) leaves
## nothing to carry, so the ship flies on unladen without touching the freed node.
func physics_process(delta: float) -> void:
	if is_ship_valid() and not ship.is_carrying():
		ship.state_machine.change_state("FlyingState")
		return
	super.physics_process(delta)

func _update_action() -> void:
	if _action_armed and Input.is_action_pressed("action") and ControlLock.allows(ControlLock.RELEASE):
		_release_held += get_physics_process_delta_time()
	else:
		_release_held = 0.0
	var home := home_for(ship.get_tree(), ship.freight)
	if _release_held >= RELEASE_HOLD:
		var f := ship.let_go()
		# Let go within tolerance of its place: the Mount or the Cradle pulls it home
		if home and is_instance_valid(f):
			home.call("seat", f)
		return
	EventBus.action_message_changed.emit(action_label(_release_held / RELEASE_HOLD, home != null))

## Where `f` would be pulled home if let go of right now - a Section's Mount, a
## Component's Cradle - or null.
static func home_for(tree: SceneTree, f: Freight) -> Node2D:
	var mount := Mount.accepting(tree, f)
	if mount:
		return mount
	return Cradle.accepting(tree, f)

## What the prompt reads: nothing until the hold starts - except RELEASE when the load
## would seat in its Mount or the Cradle - then the word and the bar filling.
static func action_label(progress: float, at_home: bool) -> String:
	if progress > 0.0:
		return release_label(progress)
	return "RELEASE" if at_home else ""

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
