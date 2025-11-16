extends RigidBody2D
class_name Ship

@export var thrust_power: float = 500.0
@export var turn_speed: float = 5
@export var fuel_consumption_rate: float = 1.0  # Fuel consumed per second when thrusting

var want_turn_left := false
var want_turn_right := false
var want_thrust := false
var want_reverse_thrust := false
var gs: GameState = null

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = false  # keep body awake while testing input; turn back on later if you like
	# Try to get GameState, with fallback
	gs = get_tree().get_first_node_in_group("game_state")

func _physics_process(_dt: float) -> void:
	# Sample input here (physics rate, thread-safe for our purposes)
	want_turn_left  = Input.is_action_pressed("turn_left")
	want_turn_right = Input.is_action_pressed("turn_right")
	want_thrust = Input.is_action_pressed("thrust")
	want_reverse_thrust = Input.is_action_pressed("reverse_thrust")
	
	# If any input, ensure the body is awake
	if want_turn_left or want_turn_right or want_thrust or want_reverse_thrust:
		sleeping = false

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Use cached inputs to modify physics state
	if want_turn_left:
		state.angular_velocity = -turn_speed
	elif want_turn_right:
		state.angular_velocity = turn_speed
	else:
		state.angular_velocity = 0.0  # Stop rotation when no input
		pass

	if want_thrust and gs:
		# Try to consume fuel - only thrust if we have fuel
		if gs.consume_fuel(fuel_consumption_rate * state.step):
			var force = Vector2.RIGHT.rotated(rotation) * thrust_power
			state.apply_central_force(force)
	if want_reverse_thrust and gs:
		# Try to consume fuel - only thrust if we have fuel
		if gs.consume_fuel(fuel_consumption_rate * state.step):
			var force = Vector2.LEFT.rotated(rotation) * thrust_power
			state.apply_central_force(force)
	
