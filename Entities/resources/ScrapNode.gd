extends OrbitalNode
class_name ScrapNode

signal harvest_started
signal harvest_stopped
signal resource_depleted
signal resource_harvested(amount: int, kind: String, position: Vector2, tier_name: String)
signal can_harvest_changed(can_harvest: bool)

@export var kind: String = "Scrap"
@export var amount: int = 1
@export var max_amount: int = 1
@export var harvest_rate: float = 10.0  # DPS applied to scrap HP during harvesting
@export var base_hp: float = 30.0
@export var trophy_hp_multiplier: float = 2.0

@export var is_trophy: bool = false:
	set(value):
		is_trophy = value
		if is_node_ready() and is_trophy:
			_activate_trophy()

var _harvesting: bool = false
var _accum: float = 0.0
var _ship_in_range: Ship = null
var _is_depleted: bool = false
var _indicator_target = null
var _indicator_manager = null
var _can_harvest: bool = false
var _trophy_sparkles: SparkleParticles = null
var _trophy_pulse_tween: Tween = null
var _harvest_beam: GPUParticles2D = null
var health_component: HealthComponent

func _ready() -> void:
	_uses_harvest_detection = true
	super._ready()

	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_hp = base_hp
	add_child(health_component)
	health_component.died.connect(_complete_harvest)

	add_to_group("resource_nodes")

	# Main Area2D (circle) - for harvesting detection
	body_entered.connect(_on_harvest_area_entered)
	body_exited.connect(_on_harvest_area_exited)

	# Register with EventBus
	EventBus.register_resource_node(self)

	# Find IndicatorManager
	_indicator_manager = get_tree().get_first_node_in_group("indicator_manager")
	if not _indicator_manager:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			_indicator_manager = main.get_node_or_null("CanvasLayer/IndicatorManager")

	# Initialize max_amount if not set
	if max_amount == 0:
		max_amount = amount

	# Trophy roll for pre-placed (non-pooled) nodes. Pooled nodes roll in on_spawn().
	if not has_meta("pool_variant"):
		is_trophy = RNG.rng.randi() % 10 == 0


func _register_with_minimap() -> void:
	if skip_minimap_registration:
		return
	var minimap = Minimap.get_instance(get_tree())
	if minimap:
		# Unregister any existing target first to prevent orphaned targets
		if minimap_target:
			minimap.unregister_target(minimap_target)
		minimap_target = ResourceMinimapTarget.new(self)
		minimap.register_target(minimap_target)

# Harvest area (circle) - for detecting ship in range for harvesting
func _on_harvest_area_entered(body: Node2D) -> void:
	if body is Ship:
		_ship_in_range = body as Ship
		_register_indicator()

func _on_harvest_area_exited(body: Node2D) -> void:
	if body is Ship and _ship_in_range == body:
		_ship_in_range = null
		if _harvesting:
			stop_harvest()
		if _can_harvest:
			_can_harvest = false
			can_harvest_changed.emit(false)
			EventBus.action_message_changed.emit("")
		_unregister_indicator()

func _process(delta: float) -> void:
	if not _ship_in_range:
		return

	var new_can_harvest = false
	if _ship_in_range and amount > 0 and not _is_depleted and not _harvesting:
		var ship_velocity = _ship_in_range.linear_velocity
		var resource_velocity = get_orbital_velocity()
		var relative_velocity = ship_velocity - resource_velocity

		if relative_velocity.length() < 100.0:
			new_can_harvest = true

	if new_can_harvest != _can_harvest:
		_can_harvest = new_can_harvest
		can_harvest_changed.emit(_can_harvest)

	if _ship_in_range and amount > 0 and not _is_depleted:
		if not _harvesting:
			if Input.is_action_just_pressed("action"):
				start_harvest()
		else:
			if Input.is_action_pressed("action"):
				health_component.take_damage(harvest_rate * delta)
				_update_harvest_beam()
				_update_visual()
			else:
				stop_harvest()
	else:
		if _harvesting:
			stop_harvest()

func start_harvest() -> void:
	if _harvesting or amount <= 0 or _is_depleted:
		return

	if _ship_in_range and is_instance_valid(_ship_in_range):
		var state_machine = _ship_in_range.get_node_or_null("StateMachine") as StateMachine
		if state_machine:
			var current_state = state_machine.current_state
			if current_state and current_state is HarvestingState:
				return

	if _ship_in_range and is_instance_valid(_ship_in_range):
		if InventoryManager.get_remaining_capacity(_ship_in_range.max_cargo_weight) <= 0:
			EventBus.action_message_changed.emit("Cargo full!")
			return

	if _ship_in_range and is_instance_valid(_ship_in_range):
		var ship_velocity = _ship_in_range.linear_velocity
		var resource_velocity = get_orbital_velocity()
		var relative_velocity = ship_velocity - resource_velocity

		if relative_velocity.length() >= 100.0:
			return

	_harvesting = true
	harvest_started.emit()

	if _ship_in_range and is_instance_valid(_ship_in_range):
		var state_machine = _ship_in_range.get_node_or_null("StateMachine") as StateMachine
		if state_machine and state_machine.has_state("HarvestingState"):
			state_machine.change_state("HarvestingState")

	_start_harvest_beam()

func stop_harvest() -> void:
	if not _harvesting:
		return

	_stop_harvest_beam()

	_harvesting = false
	_accum = 0.0
	harvest_stopped.emit()

	if _ship_in_range and is_instance_valid(_ship_in_range):
		var state_machine = _ship_in_range.get_node_or_null("StateMachine") as StateMachine
		if state_machine and state_machine.has_state("FlyingState"):
			state_machine.change_state("FlyingState")

func is_harvesting() -> bool:
	return _harvesting

func _update_visual() -> void:
	if _is_depleted:
		return

	var visual = _find_visual_node()
	if not visual:
		return

	var depletion_ratio = health_component.get_hp_ratio() if health_component else 1.0

	if visual is ColorRect:
		var color_rect = visual as ColorRect
		var base_size = color_rect.custom_minimum_size if color_rect.custom_minimum_size != Vector2.ZERO else Vector2(30, 30)
		var new_size = base_size * depletion_ratio
		color_rect.size = new_size
		color_rect.offset_left = -new_size.x / 2.0
		color_rect.offset_top = -new_size.y / 2.0
		color_rect.offset_right = new_size.x / 2.0
		color_rect.offset_bottom = new_size.y / 2.0
		var alpha = lerp(0.3, 1.0, depletion_ratio)
		color_rect.modulate = Color(color.r, color.g, color.b, alpha)
		return

	if visual is Polygon2D:
		var polygon = visual as Polygon2D
		if not polygon.has_meta("original_scale"):
			polygon.set_meta("original_scale", polygon.scale)

		var original_scale = polygon.get_meta("original_scale") as Vector2
		var scale_factor = max(depletion_ratio, min_scale)
		polygon.scale = original_scale * scale_factor

		var original_color = polygon.color
		var alpha = lerp(0.3, 1.0, depletion_ratio)
		polygon.color = Color(original_color.r, original_color.g, original_color.b, alpha)
		return

	if "scale" in visual:
		if not visual.has_meta("original_scale"):
			visual.set_meta("original_scale", visual.scale)

		var original_scale = visual.get_meta("original_scale") as Vector2
		visual.scale = original_scale * depletion_ratio

	if "modulate" in visual:
		var alpha = lerp(0.3, 1.0, depletion_ratio)
		visual.modulate = Color(color.r, color.g, color.b, alpha)

func _deplete_resource() -> void:
	if _is_depleted:
		return

	_is_depleted = true
	resource_depleted.emit()
	_unregister_indicator()

	# Disable all collision so ship can't interact.
	# Also disconnect body_entered — Godot can fire it during reparent even with monitoring=false,
	# which would trigger the bounce code and kick the ship.
	monitoring = false
	monitorable = false
	if _collision_area_cached:
		_collision_area_cached.monitoring = false
		_collision_area_cached.monitorable = false
		if _collision_area_cached.body_entered.is_connected(_on_collision_area_entered):
			_collision_area_cached.body_entered.disconnect(_on_collision_area_entered)

	EventBus.unregister_resource_node(self)

	if minimap_target:
		var minimap = Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

	if _harvesting:
		_harvesting = false
		harvest_stopped.emit()

	# Visual is already hidden by the pop animation — return to pool immediately
	returned_to_pool.emit()


func on_spawn() -> void:
	super.on_spawn()

	monitoring = true
	monitorable = true

	# Reconnect collision handler (disconnected on depletion to prevent reparent physics artifacts)
	if _collision_area_cached and not _collision_area_cached.body_entered.is_connected(_on_collision_area_entered):
		_collision_area_cached.body_entered.connect(_on_collision_area_entered)

	if not is_in_group("resource_nodes"):
		add_to_group("resource_nodes")

	EventBus.register_resource_node(self)

	# Find indicator manager
	_indicator_manager = get_tree().get_first_node_in_group("indicator_manager")
	if not _indicator_manager:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			_indicator_manager = main.get_node_or_null("CanvasLayer/IndicatorManager")

	# Restore harvest rate (zeroed on despawn)
	harvest_rate = 10.0

	# Trophy roll for pooled nodes
	is_trophy = RNG.rng.randi() % 10 == 0

func on_despawn() -> void:
	# Unregister from EventBus
	EventBus.unregister_resource_node(self)

	# Unregister indicator
	_unregister_indicator()

	# Remove from group
	if is_in_group("resource_nodes"):
		remove_from_group("resource_nodes")

	# Stop harvesting
	_stop_harvest_beam()
	_harvesting = false

	# Reset state variables
	_accum = 0.0
	_is_depleted = false
	_ship_in_range = null
	_can_harvest = false
	_indicator_target = null

	# Reset trophy state
	if _trophy_pulse_tween:
		_trophy_pulse_tween.kill()
		_trophy_pulse_tween = null
	if _trophy_sparkles:
		_trophy_sparkles.is_trophy = false
		_trophy_sparkles = null
	is_trophy = false

	# Reset resource amounts and HP
	amount = 0
	max_amount = 0
	harvest_rate = 0.0
	health_component.max_hp = base_hp
	health_component.reset()

	super.on_despawn()

func _register_indicator() -> void:
	if _indicator_manager and not _indicator_target and not _is_depleted:
		var target_class = load("res://ui/indicators/ResourceIndicatorTarget.gd")
		if target_class:
			_indicator_target = target_class.new(self)
			if _indicator_manager.has_method("register_target"):
				_indicator_manager.register_target(_indicator_target)

func _unregister_indicator() -> void:
	if _indicator_manager and _indicator_target:
		_indicator_manager.unregister_target(_indicator_target)
		_indicator_target = null

const TIER_SHAKE_MULT := {
	"slag": 0.3, "scrap": 1.0, "salvage": 1.4,
	"component": 1.8, "mil_spec": 2.5, "artifact": 3.5
}

func _complete_harvest() -> void:
	var max_cargo = 5.0
	if _ship_in_range and is_instance_valid(_ship_in_range):
		max_cargo = _ship_in_range.max_cargo_weight

	var tier: TierData.Tier
	if is_trophy:
		tier = TierData.roll_tier_trophy(RNG.rng)
	else:
		tier = TierData.roll_tier(RNG.rng)

	var tier_item_id = TierData.get_item_id(tier)
	var tier_name = TierData.get_display_name(tier)

	if not InventoryManager.can_add_item(tier_item_id, 1, max_cargo):
		EventBus.action_message_changed.emit("Cargo full!")
		health_component.reset()  # Allow retry once cargo clears
		stop_harvest()
		return

	InventoryManager.add_item(tier_item_id, 1)
	resource_harvested.emit(1, kind, global_position, tier_name)

	# Tier-scaled screen shake
	if _ship_in_range and is_instance_valid(_ship_in_range):
		var mult = TIER_SHAKE_MULT.get(tier_item_id, 1.0)
		_ship_in_range.damage_shake_time = _ship_in_range.harvest_shake_duration
		_ship_in_range.damage_shake_current_intensity = _ship_in_range.harvest_shake_intensity * mult

	_spawn_harvest_particles(tier_item_id)
	amount = 0
	stop_harvest()
	_pop_and_deplete()

func _start_harvest_beam() -> void:
	if _harvest_beam:
		return

	_harvest_beam = GPUParticles2D.new()
	_harvest_beam.amount = 12
	_harvest_beam.lifetime = 0.7
	_harvest_beam.one_shot = false
	_harvest_beam.emitting = true
	_harvest_beam.position = Vector2.ZERO

	var mat = ParticleProcessMaterial.new()
	mat.spread = 15.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 150.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = Colors.PRIMARY
	mat.damping_min = 5.0
	mat.damping_max = 15.0
	_harvest_beam.process_material = mat

	add_child(_harvest_beam)

func _update_harvest_beam() -> void:
	if not _harvest_beam or not _ship_in_range or not is_instance_valid(_ship_in_range):
		return

	var to_ship = (_ship_in_range.global_position - global_position).normalized()
	var mat = _harvest_beam.process_material as ParticleProcessMaterial
	if mat:
		mat.direction = Vector3(to_ship.x, to_ship.y, 0.0)
		var progress = 1.0 - health_component.get_hp_ratio()
		_harvest_beam.amount = int(lerp(8.0, 35.0, progress))

func _stop_harvest_beam() -> void:
	if not _harvest_beam:
		return
	_harvest_beam.emitting = false
	var beam = _harvest_beam
	_harvest_beam = null
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(beam):
			beam.queue_free()
	)

func _pop_and_deplete() -> void:
	var visual = _find_visual_node()
	if visual:
		var pop_tween = create_tween()
		pop_tween.tween_property(visual, "scale", visual.scale * 1.2, 0.1).set_ease(Tween.EASE_OUT)
		pop_tween.tween_property(visual, "scale", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		pop_tween.tween_callback(_finish_depletion)
	else:
		_finish_depletion()

func _finish_depletion() -> void:
	if not _is_depleted:
		_deplete_resource()

func _tier_particle_color(tier_item_id: String) -> Color:
	match tier_item_id:
		"slag":      return Color(0.533, 0.533, 0.533)  # dim grey
		"scrap":     return Colors.PRIMARY               # amber
		"salvage":   return Color(1.0,   0.843, 0.0)    # yellow
		"component": return Color(0.0,   1.0,   0.533)  # teal-green
		"mil_spec":  return Color(0.0,   0.8,   1.0)    # cyan
		"artifact":  return Color(1.0,   1.0,   1.0)    # white-gold
	return Colors.PRIMARY

func _spawn_harvest_particles(tier_item_id: String = "") -> void:
	var particles = GPUParticles2D.new()
	particles.amount = 30
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = false
	particles.position = Vector2.ZERO

	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0, 0)
	material.spread = 360.0
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 60.0
	material.gravity = Vector3.ZERO
	material.scale_min = 1.0
	material.scale_max = 3.0
	material.color = _tier_particle_color(tier_item_id)
	material.damping_min = 20.0
	material.damping_max = 40.0

	particles.process_material = material
	add_child(particles)
	particles.emitting = true

	# Auto-cleanup after particles finish
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _activate_trophy() -> void:
	_trophy_sparkles = get_node_or_null("SparkleParticles") as SparkleParticles
	if not _trophy_sparkles:
		return

	_trophy_sparkles.is_trophy = true

	# Trophies are tougher to harvest
	health_component.max_hp = base_hp * trophy_hp_multiplier
	health_component.reset()

	# Subtle scale pulse to catch the eye
	var visual = _find_visual_node()
	if visual:
		_trophy_pulse_tween = create_tween().set_loops()
		_trophy_pulse_tween.tween_property(visual, "scale", visual.scale * 1.15, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_trophy_pulse_tween.tween_property(visual, "scale", visual.scale, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
