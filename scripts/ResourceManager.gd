extends Node
class_name ResourceManager

## Floating "+N" text over the ship: every gem pickup, shown as a count in that gem's
## color, and the credits earned when the hold is cashed in at a port. Pickups within
## BATCH_WINDOW merge into one line per tier, and lines still on screen push new ones
## upward so they never overlap.

var _gain_indicator_scene: PackedScene = preload("res://entities/resources/ResourceGainIndicator.tscn")

const BATCH_WINDOW := 0.35
const STACK_BASE := 30.0  # start above the ship, clear of the harvest meter below it
const STACK_SPACING := 16.0
const X_JITTER := 14.0  # popups scatter sideways a little instead of lining up

var _pending: Dictionary = {}  # item_id -> count collected this window
var shown: Array[Dictionary] = []  # every line shown: {amount, color, style} (read by playtests)
var _live: Array[ResourceGainIndicator] = []

func _ready() -> void:
	add_to_group("resource_manager")
	EventBus.gem_collected.connect(_on_gem_collected)
	EventBus.hold_cashed_in.connect(_on_hold_cashed_in)

func spawn_all_resources() -> void:
	# Manually trigger spawning on all ResourceSpawners (useful if auto_spawn is disabled)
	var spawners = get_tree().get_nodes_in_group("resource_spawners")
	for spawner in spawners:
		if spawner.has_method("spawn_cluster"):
			spawner.spawn_cluster()

func _on_gem_collected(item_id: String, _world_position: Vector2) -> void:
	if _pending.is_empty():
		get_tree().create_timer(BATCH_WINDOW).timeout.connect(_flush_pending)
	_pending[item_id] = _pending.get(item_id, 0) + 1

func _flush_pending() -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	# Best tier first so it sits lowest, closest to the ship.
	var tiers := GemData.TIERS.keys()
	tiers.reverse()
	for tier in tiers:
		var id := GemData.item_id(tier)
		if _pending.has(id) and ship:
			show_gain_indicator(_pending[id], ship.global_position, "", GemData.color_of(id), id)
	_pending.clear()

func _on_hold_cashed_in(credits: int) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	if ship:
		show_gain_indicator(credits, ship.global_position, "CR", Colors.PRIMARY, "CR")

## `label` is the unit shown after the amount ("" for just the number); `style` picks the pop.
func show_gain_indicator(amount: int, position: Vector2, label: String, color: Color, style: String = "") -> void:
	# Find CanvasLayer to add indicator to
	var main = get_tree().get_first_node_in_group("main")
	var canvas_layer: CanvasLayer = null

	if main:
		canvas_layer = main.get_node_or_null("CanvasLayer")

	if not canvas_layer:
		# Fallback: try to find CanvasLayer in scene tree
		canvas_layer = get_tree().root.find_child("CanvasLayer", true, false) as CanvasLayer

	if not canvas_layer:
		push_error("Could not find CanvasLayer for resource gain indicator")
		return

	var indicator = _gain_indicator_scene.instantiate() as ResourceGainIndicator
	if not indicator:
		push_error("Failed to instantiate ResourceGainIndicator")
		return

	# Pickups and cash-ins happen at the ship, which keeps flying: pin the text to it.
	indicator.follow = get_tree().get_first_node_in_group("ship") as Node2D
	shown.append({"amount": amount, "color": color, "style": style})
	_live = _live.filter(func(i): return is_instance_valid(i))
	indicator.stack_offset = STACK_BASE + STACK_SPACING * _live.size()
	indicator.x_offset = randf_range(-X_JITTER, X_JITTER)
	_live.append(indicator)
	canvas_layer.add_child(indicator)

	# Wait for next frame to ensure _ready() is called and @onready vars are set
	await get_tree().process_frame
	indicator.show_gain(amount, "", position, label, color, style)
