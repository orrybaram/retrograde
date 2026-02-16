extends Node
class_name ResourceManager

# Resource gain indicator scene (preloaded at parse time)
var _gain_indicator_scene: PackedScene = preload("res://entities/resources/ResourceGainIndicator.tscn")
var _connected_nodes: Array[ScrapNode] = []
var _node_check_timer: Timer = null

func _ready() -> void:
	add_to_group("resource_manager")

	# Connect to existing resource nodes
	_connect_to_resource_nodes()

	# Set up periodic check for new resource nodes (handles dynamically spawned nodes)
	_check_for_new_nodes()

func spawn_all_resources() -> void:
	# Manually trigger spawning on all ResourceSpawners (useful if auto_spawn is disabled)
	var spawners = get_tree().get_nodes_in_group("resource_spawners")
	for spawner in spawners:
		if spawner.has_method("spawn_cluster"):
			spawner.spawn_cluster()

func _connect_to_resource_nodes() -> void:
	var resource_nodes = get_tree().get_nodes_in_group("resource_nodes")

	# Clean up disconnected nodes
	_connected_nodes = _connected_nodes.filter(func(node): return is_instance_valid(node))

	for node in resource_nodes:
		if node is ScrapNode:
			var scrap_node = node as ScrapNode
			# Skip if already connected
			if scrap_node in _connected_nodes:
				continue

			# Connect signal
			if not scrap_node.resource_harvested.is_connected(show_gain_indicator):
				scrap_node.resource_harvested.connect(show_gain_indicator)
				_connected_nodes.append(scrap_node)

func _check_for_new_nodes() -> void:
	# Check for new resource nodes periodically
	_node_check_timer = Timer.new()
	add_child(_node_check_timer)
	_node_check_timer.wait_time = 1.0  # Check every second
	_node_check_timer.timeout.connect(_connect_to_resource_nodes)
	_node_check_timer.start()  # Explicitly start the timer

func show_gain_indicator(amount: int, kind: String, position: Vector2, tier_name: String = "") -> void:
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

	# Instantiate indicator
	var indicator = _gain_indicator_scene.instantiate() as ResourceGainIndicator
	if not indicator:
		push_error("Failed to instantiate ResourceGainIndicator")
		return

	canvas_layer.add_child(indicator)

	# Wait for next frame to ensure _ready() is called and @onready vars are set
	await get_tree().process_frame
	indicator.show_gain(amount, kind, position, tier_name)
