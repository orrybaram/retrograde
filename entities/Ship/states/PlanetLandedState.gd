extends ShipState
class_name PlanetLandedState

## The ship sitting on a LandingSite's pad. (LandedState is docking at a port.)
## Entered from FlyingState on a gentle touchdown (see Touchdown). The ship settles onto
## the pad and then locks to the planet, riding its orbit; engines are off, so no fuel
## burns. `action` drills the site (SiteDrill), reverse thrust banks between layers.
## Thrust lifts off, burning Touchdown.liftoff_cost() in one go: with too little fuel
## the engines burn out and the ship is stranded.
## Owns the landed camera zoom, the drill and the landed action prompt.

const CAMERA_ZOOM := Vector2(1.5, 1.5)
const LANDED_HEIGHT := 13.0  # ship centre above the surface (tail length)
const SETTLE_TIME := 0.35
const LIFTOFF_SPEED := 110.0
const LIFTOFF_CLEARANCE := 3.0

var site: LandingSite = null
var drill: SiteDrill = null

var _offset := Vector2.ZERO  # locked position relative to the planet centre
var _start_offset := Vector2.ZERO
var _start_rotation := 0.0
var _settle := 0.0
var _launching := false
var _prompt := ""

func enter() -> void:
	super.enter()
	site = ship.get_meta("pending_site", null) as LandingSite
	ship.remove_meta("pending_site")
	if not is_instance_valid(site) or not is_instance_valid(site.planet):
		site = null
		_exit_to_flying.call_deferred()
		return

	var planet := site.planet
	_start_offset = ship.global_position - planet.global_position
	_start_rotation = ship.rotation
	_offset = pad_offset(site, ship.global_position)
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
	if NavSystem.get_target() == site.tracking_target():
		NavSystem.track_home()
	drill = SiteDrill.attach(ship, site)
	_prompt = ""
	_update_prompt()

func exit() -> void:
	super.exit()
	if is_instance_valid(drill):
		drill.abort()
		drill.queue_free()
	drill = null
	site = null
	_launching = false
	_prompt = ""
	EventBus.action_message_changed.emit("")
	ship.camera.zoom_camera_out()

## Where the ship sits relative to the planet centre: straight out from the surface at
## its touchdown bearing, clamped onto the pad.
static func pad_offset(landing_site: LandingSite, ship_position: Vector2) -> Vector2:
	var planet := landing_site.planet
	var bearing := (ship_position - planet.global_position).angle()
	var half := landing_site.pad_half_angle()
	var clamped := landing_site.global_rotation + clampf(angle_difference(landing_site.global_rotation, bearing), -half, half)
	return Vector2.from_angle(clamped) * (landing_site.surface_radius() + LANDED_HEIGHT)

func liftoff_cost() -> float:
	return Touchdown.liftoff_cost(site.planet.surface_gravity(), ship.get_cargo_weight())

func physics_process(delta: float) -> void:
	if not is_ship_valid() or not site:
		return
	_settle += delta
	_flying()._update_camera_shake(delta)
	if _launching or _flying()._is_ui_blocking_input():
		return
	if Input.is_action_pressed("thrust"):
		lift_off()
		return
	if drill.phase == SiteDrill.Phase.DONE and not site.is_spent():
		# Regrown while we sat here: a fresh dig
		drill.queue_free()
		drill = SiteDrill.attach(ship, site)
	var was_done := drill.phase == SiteDrill.Phase.DONE
	if Input.is_action_just_pressed("reverse_thrust"):
		drill.bank()
	# A dig starts on a fresh press, not a key still held from flying
	var holding := Input.is_action_pressed("action")
	if drill.phase == SiteDrill.Phase.READY:
		holding = Input.is_action_just_pressed("action")
	drill.tick(delta, holding)
	if drill.phase == SiteDrill.Phase.DONE and not was_done:
		_save_spent_sites()
	_update_prompt()

## Burn the liftoff fuel and launch. Too little fuel burns the tank dry instead.
func lift_off() -> void:
	var cost := liftoff_cost()
	if ship.fuel < cost:
		EventBus.action_message_changed.emit("NOT ENOUGH FUEL TO LIFT OFF - ENGINES BURNED OUT")
		ship.consume_fuel(ship.fuel)
		return
	ship.consume_fuel(cost)
	var was_done := drill.phase == SiteDrill.Phase.DONE
	drill.abort()
	if drill.phase == SiteDrill.Phase.DONE and not was_done:
		_save_spent_sites()
	_launching = true
	ship.thruster_particles.emitting = true

func integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_ship_valid() or not site or not is_instance_valid(site.planet):
		return
	var planet := site.planet
	var up := _offset.normalized()
	if _launching:
		state.transform = Transform2D(up.angle(), planet.global_position + _offset + up * LIFTOFF_CLEARANCE)
		state.linear_velocity = planet.linear_velocity + up * LIFTOFF_SPEED
		state.angular_velocity = 0.0
		_launching = false
		_exit_to_flying.call_deferred()
		return
	var t := ease(clampf(_settle / SETTLE_TIME, 0.0, 1.0), 0.5)
	state.transform = Transform2D(
		lerp_angle(_start_rotation, up.angle(), t),
		planet.global_position + _start_offset.lerp(_offset, t))
	state.linear_velocity = planet.linear_velocity
	state.angular_velocity = 0.0

## Keep the spent site across a quit without saving the landed ship itself.
func _save_spent_sites() -> void:
	var gs := ship.get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		Save.save_site_regrowth(gs.spent_sites)

func _update_prompt() -> void:
	var prompt := prompt_text()
	if prompt != _prompt:
		_prompt = prompt
		EventBus.action_message_changed.emit(prompt)

## What the HUD tells the player to do next.
func prompt_text() -> String:
	var liftoff := '"%s" lift off (%d fuel)' % [InputUtils.get_action_key_name("thrust"), ceili(liftoff_cost())]
	var action_key := InputUtils.get_action_key_name("action")
	match drill.phase:
		SiteDrill.Phase.READY:
			return 'LANDED - hold "%s" to drill - %s' % [action_key, liftoff]
		SiteDrill.Phase.DIGGING:
			if drill.is_holding():
				return ""
			if drill.can_bank():
				return '"%s" drill deeper (%d/%d) - "%s" bank' % [action_key, drill.layer + 1, drill.layer_count(), InputUtils.get_action_key_name("reverse_thrust")]
			return 'hold "%s" to drill - %s' % [action_key, liftoff]
	if drill.end_reason == "spent":
		var left := ceili(site.regrow_left())
		return "SITE SPENT - regrows in %d:%02d - %s" % [left / 60, left % 60, liftoff]
	return "DIG COMPLETE - %s" % liftoff

func _flying() -> FlyingState:
	return ship.state_machine.states.get("FlyingState") as FlyingState

func _exit_to_flying() -> void:
	if ship.state_machine.current_state == self:
		ship.state_machine.change_state("FlyingState")
