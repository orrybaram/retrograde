extends ShipState
class_name PlanetLandedState

## The ship sitting on a planet's surface, over an ore seam. (LandedState is docking.)
## Entered from FlyingState on a gentle touchdown (see Touchdown). The ship settles on
## the ground and then locks to the planet, riding its orbit; engines are off, so no fuel
## burns. `action` harvests the seam with the same hold-and-release sweep that works a
## scrap node: the seam owns the timing and its hits (OreDeposit.tick_harvest), this state
## feeds it the key and throws the gems each hit knocks loose into the hold's magnet.
## Thrust lifts off, keeping whatever has already come loose. Nothing is thrown and
## nothing is charged: the ship is released where it stands, at rest relative to the
## planet, and climbs out of the gravity well on its own engines for as long as the player
## holds thrust. A heavy planet or a full hold makes that climb longer, so it burns more
## thruster fuel - and running dry on the way up strands the ship where it sits.
## Owns the landed camera zoom and the landed action prompt. (The sonar rings that play
## under the beam are the ship's own, driven by Ship.wants_sonar.)

const CAMERA_ZOOM := Vector2(1.5, 1.5)
const LANDED_HEIGHT := 13.0  # ship centre above the surface (tail length)
const SETTLE_TIME := 0.35

var ore: OreDeposit = null

var _offset := Vector2.ZERO  # locked position relative to the planet centre
var _start_offset := Vector2.ZERO
var _start_rotation := 0.0
var _settle := 0.0
var _launching := false
var _prompt := ""

func enter() -> void:
	super.enter()
	ore = ship.get_meta("pending_ore", null) as OreDeposit
	ship.remove_meta("pending_ore")
	if not is_instance_valid(ore) or not is_instance_valid(ore.planet):
		ore = null
		_exit_to_flying.call_deferred()
		return

	var planet := ore.planet
	_start_offset = ship.global_position - planet.global_position
	_start_rotation = ship.rotation
	_offset = ground_offset(ore, ship.global_position)
	_settle = 0.0
	_launching = false

	ship.want_thrust = false
	ship.want_reverse_thrust = false
	ship.want_boost = false
	ship.want_turn_left = false
	ship.want_turn_right = false
	_flying()._update_particles()
	ship.camera.zoom_camera_in(CAMERA_ZOOM)
	ship.damage_shake_time = ship.harvest_lockon_shake_duration
	ship.damage_shake_current_intensity = ship.harvest_lockon_shake_intensity

	# Arrived: the tracker goes back to home base
	if NavSystem.get_target() == ore.tracking_target():
		NavSystem.track_home()
	ore.harvest_hit.connect(_on_harvest_hit)
	_prompt = ""
	_update_prompt()

func exit() -> void:
	super.exit()
	if is_instance_valid(ore):
		ore.abort_harvest()
		if ore.harvest_hit.is_connected(_on_harvest_hit):
			ore.harvest_hit.disconnect(_on_harvest_hit)
	ore = null
	_launching = false
	_prompt = ""
	EventBus.action_message_changed.emit("")
	ship.camera.zoom_camera_out()

## Where the ship sits relative to the planet centre: straight out from the surface at
## its touchdown bearing, held within reach of the seam.
static func ground_offset(deposit: OreDeposit, ship_position: Vector2) -> Vector2:
	var planet := deposit.planet
	var bearing := (ship_position - planet.global_position).angle()
	var reach := deposit.reach_angle()
	var clamped := deposit.global_rotation + clampf(angle_difference(deposit.global_rotation, bearing), -reach, reach)
	return Vector2.from_angle(clamped) * (deposit.surface_radius() + LANDED_HEIGHT)

func physics_process(delta: float) -> void:
	if not is_ship_valid() or not ore:
		return
	_settle += delta
	_flying()._update_camera_shake(delta)
	if _launching or _flying()._is_ui_blocking_input():
		return
	if Input.is_action_pressed("thrust"):
		lift_off()
		return
	# A sweep starts on a fresh press, not a key still held from flying or from the hit
	# that just landed; once it is running, holding keeps it going.
	var holding := Input.is_action_pressed("action") if ore.is_harvesting() \
		else Input.is_action_just_pressed("action")
	ore.tick_harvest(delta, holding)
	_update_prompt()

## Release the ship. Nothing is charged for it: the climb is the player's to fly, on
## ordinary thruster fuel, and running the tank dry on the way up strands them.
func lift_off() -> void:
	ore.abort_harvest()
	_launching = true
	ship.thruster_particles.emitting = true

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not ore or not is_instance_valid(ore.planet):
		return
	var planet := ore.planet
	var up := _offset.normalized()
	if _launching:
		# Released where it stands, matching the planet, with no push of its own: from
		# here the engines do the lifting and gravity fights them.
		state.linear_velocity = planet.linear_velocity
		state.angular_velocity = 0.0
		_launching = false
		_flying().ignore_ground_for(FlyingState.LIFTOFF_GRACE)
		_exit_to_flying.call_deferred()
		return
	var t := ease(clampf(_settle / SETTLE_TIME, 0.0, 1.0), 0.5)
	state.transform = Transform2D(
		lerp_angle(_start_rotation, up.angle(), t),
		planet.global_position + _start_offset.lerp(_offset, t))
	state.linear_velocity = planet.linear_velocity
	state.angular_velocity = 0.0

## One hit landed: the gems burst out of the seam into the hold's magnet, the payoff
## effects play, and the last hit spends the seam for good.
func _on_harvest_hit(grade: HarvestTiming.Grade, drops: Array[String], final: bool) -> void:
	if not is_ship_valid() or not ship.is_inside_tree():
		return
	var at := ore.global_position
	# Always the gentle chip burst: the ship is parked right on top of the seam, and a
	# wide scatter would throw half the haul out of the magnet's reach.
	Gem.burst(ship.get_parent(), at, ore.velocity(), drops, false, RNG.rng)
	HarvestJuice.play_at(ship, ship.get_tree(), at, ore.velocity(), grade, GemData.best_of(drops), final)
	EventBus.harvest_hit.emit(ore, grade, drops, final)
	if final:
		_save_spent_ore()

## Keep the spent seam across a quit without saving the landed ship itself.
func _save_spent_ore() -> void:
	var gs := ship.get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		Save.save_ore_regrowth(gs.spent_ore)

func _update_prompt() -> void:
	var prompt := prompt_text()
	if prompt != _prompt:
		_prompt = prompt
		EventBus.action_message_changed.emit(prompt)

## What the prompt under the ship offers next. (Thrust always lifts off; the prompt
## stays about the seam.) The meter takes over while the sweep is running.
func prompt_text() -> String:
	if ore.is_spent():
		return "SEAM SPENT"
	if ore.is_harvesting():
		return ""
	return EventBus.action_prompt("HARVEST")

func _flying() -> FlyingState:
	return ship.state_machine.states.get("FlyingState") as FlyingState

func _exit_to_flying() -> void:
	if ship.state_machine.current_state == self:
		ship.state_machine.change_state("FlyingState")
