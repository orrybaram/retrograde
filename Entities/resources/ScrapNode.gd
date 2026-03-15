extends OrbitalNode
class_name ScrapNode

## Harvestable resource node. Extends OrbitalNode with HP, tier, kind, and amount.
## Four-state machine: ScrapIdleState → ScrapInRangeState → ScrapHarvestingState → ScrapDepletedState.
## Emits resource_harvested(amount, kind, position, tier_name) when fully depleted.
## Returns to pool via ResourceNodePool after the depletion animation completes.

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

var _ship_in_range: Ship = null
var _is_depleted: bool = false
var _indicator_target = null
var _indicator_manager = null
var sparkle_particles: SparkleParticles = null
var _trophy_pulse_tween: Tween = null
var _state_machine: StateMachine
var health_component: HealthComponent
var _shape_instance: Node2D = null

const _SHAPE_SCENES := [
	preload("res://Entities/resources/ScrapShapes/ScrapShape0.tscn"),
	preload("res://Entities/resources/ScrapShapes/ScrapShape1.tscn"),
	preload("res://Entities/resources/ScrapShapes/ScrapShape2.tscn"),
	preload("res://Entities/resources/ScrapShapes/ScrapShape3.tscn"),
	preload("res://Entities/resources/ScrapShapes/ScrapShape4.tscn"),
	preload("res://Entities/resources/ScrapShapes/ScrapShape5.tscn"),
]

func _ready() -> void:
	_uses_harvest_detection = true  # keeps monitorable toggled on sleep/wake for HarvestCone
	monitoring = false  # HarvestCone detects us via area_entered; we don't body-detect the ship
	_load_shape()  # before super so OrbitalNode caches CollisionArea from the shape sub-scene
	super._ready()

	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_hp = base_hp
	add_child(health_component)

	add_to_group("resource_nodes")

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

	# Build state machine programmatically — no scene changes required
	var sm := StateMachine.new()
	sm.name = "StateMachine"
	sm.initial_state_name = "ScrapIdleState"
	var s_idle := ScrapIdleState.new()
	s_idle.name = "ScrapIdleState"
	var s_in_range := ScrapInRangeState.new()
	s_in_range.name = "ScrapInRangeState"
	var s_harvesting := ScrapHarvestingState.new()
	s_harvesting.name = "ScrapHarvestingState"
	var s_depleted := ScrapDepletedState.new()
	s_depleted.name = "ScrapDepletedState"
	sm.add_child(s_idle)
	sm.add_child(s_in_range)
	sm.add_child(s_harvesting)
	sm.add_child(s_depleted)
	add_child(sm)
	_state_machine = sm


func _load_shape() -> void:
	# Remove old inline shape nodes (legacy Scrap1-5 scene structure)
	for node_name: String in ["Polygon2D", "CollisionArea"]:
		var old := get_node_or_null(node_name)
		if old:
			old.free()
	# Also handle Node2D wrapper pattern (some old scenes wrap CollisionArea in a Node2D)
	for child: Node in get_children():
		if child is Node2D and child.get_node_or_null("CollisionArea"):
			child.free()
			break

	var packed: PackedScene = _SHAPE_SCENES[RNG.rng.randi() % _SHAPE_SCENES.size()]
	_shape_instance = packed.instantiate() as Node2D
	if not _shape_instance:
		return
	add_child(_shape_instance)

	var cshape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cshape and cshape.shape is CircleShape2D:
		(cshape.shape as CircleShape2D).radius = _shape_instance.get("collision_radius")


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

func _process(delta: float) -> void:
	if _state_machine and _state_machine.current_state:
		_state_machine.current_state.process(delta)

func is_harvesting() -> bool:
	return _state_machine != null and _state_machine.current_state is ScrapHarvestingState

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

	# Visual is already hidden by the pop animation — return to pool immediately
	returned_to_pool.emit()


func on_spawn() -> void:
	super.on_spawn()  # OrbitalNode.on_spawn() restores monitorable = true

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

	# Reset state machine for new spawn cycle
	if _state_machine:
		_state_machine.change_state("ScrapIdleState")

func on_despawn() -> void:
	# Reset state machine first — triggers state cleanup (beam stop, indicator, ship state, etc.)
	if _state_machine and not (_state_machine.current_state is ScrapIdleState):
		_state_machine.change_state("ScrapIdleState")

	# Unregister from EventBus
	EventBus.unregister_resource_node(self)

	# Unregister indicator
	_unregister_indicator()

	# Remove from group
	if is_in_group("resource_nodes"):
		remove_from_group("resource_nodes")

	# Reset state variables
	_is_depleted = false
	_ship_in_range = null
	_indicator_target = null

	# Reset trophy state
	if _trophy_pulse_tween:
		_trophy_pulse_tween.kill()
		_trophy_pulse_tween = null
	if sparkle_particles:
		sparkle_particles.is_trophy = false
		sparkle_particles = null
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

func _activate_trophy() -> void:
	sparkle_particles = get_node_or_null("SparkleParticles") as SparkleParticles
	if not sparkle_particles:
		return

	sparkle_particles.is_trophy = true

	# Trophies are tougher to harvest
	health_component.max_hp = base_hp * trophy_hp_multiplier
	health_component.reset()

	# Subtle scale pulse to catch the eye
	var visual = _find_visual_node()
	if visual:
		_trophy_pulse_tween = create_tween().set_loops()
		_trophy_pulse_tween.tween_property(visual, "scale", visual.scale * 1.15, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		_trophy_pulse_tween.tween_property(visual, "scale", visual.scale, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
