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
@export var harvest_rate: float = 5.0

var _harvesting: bool = false
var _accum: float = 0.0
var _ship_in_range: Ship = null
var _is_depleted: bool = false
var _indicator_target = null
var _indicator_manager = null
var _can_harvest: bool = false

# Mini-game integration
var _mini_game: HarvestMiniGame = null
var _mini_game_ui: HarvestMiniGameUI = null
var _mini_game_ui_scene: PackedScene = preload("res://minigames/harvest/HarvestMiniGameUI.tscn")

func _ready() -> void:
	_uses_harvest_detection = true
	super._ready()

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

func _process(_delta: float) -> void:
	if not _ship_in_range:
		return

	if _mini_game and not _mini_game.is_idle():
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
		if Input.is_action_just_pressed("action"):
			if not _harvesting:
				start_harvest()
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

	_start_mini_game()

func stop_harvest() -> void:
	if not _harvesting:
		return

	if _mini_game:
		_stop_mini_game()

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

	var depletion_ratio = float(amount) / float(max_amount) if max_amount > 0 else 1.0

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

	# Disable collision immediately so ship can't interact during fade-out
	monitoring = false
	monitorable = false

	EventBus.unregister_resource_node(self)

	if minimap_target:
		var minimap = Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

	if _mini_game:
		_stop_mini_game()

	if _harvesting:
		_harvesting = false
		harvest_stopped.emit()

	_start_fade_out()

	await get_tree().create_timer(5.0).timeout
	returned_to_pool.emit()

func _start_fade_out() -> void:
	var fade_duration = 2.0
	var elapsed = 0.0

	var visual = _find_visual_node()
	if not visual:
		return

	var start_alpha: float = 1.0
	if visual is Polygon2D:
		start_alpha = (visual as Polygon2D).color.a
	elif visual is ColorRect:
		start_alpha = (visual as ColorRect).modulate.a
	elif "modulate" in visual:
		start_alpha = visual.modulate.a

	while elapsed < fade_duration:
		elapsed += get_process_delta_time()
		var fade_progress = elapsed / fade_duration
		var current_alpha = lerp(start_alpha, 0.0, fade_progress)
		current_alpha = clamp(current_alpha, 0.0, 1.0)

		if visual:
			if visual is Polygon2D:
				var polygon = visual as Polygon2D
				var original_color = polygon.color
				polygon.color = Color(original_color.r, original_color.g, original_color.b, current_alpha)
			elif visual is ColorRect:
				var color_rect = visual as ColorRect
				color_rect.modulate = Color(color_rect.modulate.r, color_rect.modulate.g, color_rect.modulate.b, current_alpha)
			elif "modulate" in visual:
				var current_modulate = visual.modulate
				visual.modulate = Color(current_modulate.r, current_modulate.g, current_modulate.b, current_alpha)

		await get_tree().process_frame

func on_spawn() -> void:
	super.on_spawn()

	monitoring = true
	monitorable = true

	if not is_in_group("resource_nodes"):
		add_to_group("resource_nodes")

	EventBus.register_resource_node(self)

	# Find indicator manager
	_indicator_manager = get_tree().get_first_node_in_group("indicator_manager")
	if not _indicator_manager:
		var main = get_tree().get_first_node_in_group("main")
		if main:
			_indicator_manager = main.get_node_or_null("CanvasLayer/IndicatorManager")

func on_despawn() -> void:
	# Unregister from EventBus
	EventBus.unregister_resource_node(self)

	# Unregister indicator
	_unregister_indicator()

	# Remove from group
	if is_in_group("resource_nodes"):
		remove_from_group("resource_nodes")

	# Stop mini-game if active
	if _mini_game:
		_stop_mini_game()

	# Stop harvesting
	_harvesting = false

	# Reset state variables
	_accum = 0.0
	_is_depleted = false
	_ship_in_range = null
	_can_harvest = false
	_mini_game = null
	_mini_game_ui = null
	_indicator_target = null

	# Reset resource amounts
	amount = 0
	max_amount = 0
	harvest_rate = 0.0

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

func _start_mini_game() -> void:
	_mini_game = HarvestMiniGame.new()
	add_child(_mini_game)

	_mini_game.harvest_success.connect(_on_mini_game_harvest_success)
	_mini_game.harvest_failed.connect(_on_mini_game_harvest_failed)
	_mini_game.ui_closed.connect(_on_mini_game_ui_closed)

	_setup_mini_game_ui()

	_mini_game.open_ui(kind, amount)

func _setup_mini_game_ui() -> void:
	var main = get_tree().get_first_node_in_group("main")
	var canvas_layer: CanvasLayer = null

	if main:
		canvas_layer = main.get_node_or_null("CanvasLayer")

	if not canvas_layer:
		canvas_layer = get_tree().root.find_child("CanvasLayer", true, false) as CanvasLayer

	if not canvas_layer:
		push_error("Could not find CanvasLayer for mini-game UI")
		return

	if _mini_game_ui_scene:
		_mini_game_ui = _mini_game_ui_scene.instantiate() as HarvestMiniGameUI
		if _mini_game_ui:
			canvas_layer.add_child(_mini_game_ui)
			_mini_game_ui.setup(_mini_game)

func _stop_mini_game() -> void:
	if _mini_game:
		_mini_game.close_ui()

	if _mini_game_ui:
		_mini_game_ui.cleanup()
		_mini_game_ui.queue_free()
		_mini_game_ui = null

	if _mini_game:
		_mini_game.queue_free()
		_mini_game = null

func _on_mini_game_harvest_success(tier_item_id: String, tier_name: String) -> void:
	var max_cargo = 5.0
	if _ship_in_range and is_instance_valid(_ship_in_range):
		max_cargo = _ship_in_range.max_cargo_weight

	if not InventoryManager.can_add_item(tier_item_id, 1, max_cargo):
		EventBus.action_message_changed.emit("Cargo full!")
		_stop_mini_game()
		stop_harvest()
		return

	InventoryManager.add_item(tier_item_id, 1)

	resource_harvested.emit(1, kind, global_position, tier_name)

	# Trigger harvest screen shake on the ship
	if _ship_in_range and is_instance_valid(_ship_in_range):
		_ship_in_range.damage_shake_time = _ship_in_range.harvest_shake_duration
		_ship_in_range.damage_shake_current_intensity = _ship_in_range.harvest_shake_intensity

	# Spawn harvest particle burst
	_spawn_harvest_particles()

	amount = 0

	# Pop effect: scale up then shrink to 0 before depletion
	_pop_and_deplete()

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
	_stop_mini_game()

func _spawn_harvest_particles() -> void:
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
	material.color = Colors.PRIMARY
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

func _on_mini_game_harvest_failed() -> void:
	# Small screen shake on failure
	if _ship_in_range and is_instance_valid(_ship_in_range):
		_ship_in_range.damage_shake_time = 0.2
		_ship_in_range.damage_shake_current_intensity = 0.8
	_stop_mini_game()

func _on_mini_game_ui_closed() -> void:
	stop_harvest()
