extends Node

## Object pool manager for ResourceNode variants.
## Maintains separate pools for each scene variant (Scrap, Scrap1-5).
## Add to Project Settings > Autoload as "ResourceNodePool"

# Scene paths for all resource variants
const RESOURCE_SCENES: Dictionary = {
	"Scrap": preload("res://entities/resources/Scrap.tscn"),
	"Scrap1": preload("res://entities/resources/Scrap1.tscn"),
	"Scrap2": preload("res://entities/resources/Scrap2.tscn"),
	"Scrap3": preload("res://entities/resources/Scrap3.tscn"),
	"Scrap4": preload("res://entities/resources/Scrap4.tscn"),
	"Scrap5": preload("res://entities/resources/Scrap5.tscn"),
}

@export var initial_pool_size: int = 5  # Per variant (pool grows as needed)
@export var can_grow: bool = true

# Pools keyed by variant name: { "Scrap": { available: [], in_use: [], scene: PackedScene }, ... }
var _pools: Dictionary = {}

func _ready() -> void:
	# Initialize pools for all variants
	for variant_name in RESOURCE_SCENES.keys():
		_pools[variant_name] = {
			"available": [] as Array[ResourceNode],
			"in_use": [] as Array[ResourceNode],
			"scene": RESOURCE_SCENES[variant_name]
		}
		_initialize_pool(variant_name)

func _initialize_pool(variant_name: String) -> void:
	for i in initial_pool_size:
		_create_instance(variant_name)

func _create_instance(variant_name: String) -> ResourceNode:
	var pool_data = _pools[variant_name]
	var scene: PackedScene = pool_data["scene"]

	var instance := scene.instantiate() as ResourceNode
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.visible = false

	# Store variant name for return-to-pool lookup
	instance.set_meta("pool_variant", variant_name)

	# Add to pool node (keeps hierarchy clean)
	add_child(instance)

	# Connect return signal
	instance.returned_to_pool.connect(_return_to_pool.bind(instance, variant_name))

	pool_data["available"].append(instance)
	return instance

## Get an instance from the pool for the specified variant
## @param variant_name: "Scrap", "Scrap1", "Scrap2", etc.
## @param parent: The node to reparent the instance to (typically scene_root)
func get_instance(variant_name: String, parent: Node) -> ResourceNode:
	if not _pools.has(variant_name):
		push_error("ResourceNodePool: Unknown resource variant: %s" % variant_name)
		return null

	var pool_data = _pools[variant_name]
	var instance: ResourceNode

	if pool_data["available"].is_empty():
		if can_grow:
			instance = _create_instance(variant_name)
			pool_data["available"].erase(instance)
		else:
			push_warning("ResourceNodePool: Pool exhausted for variant: %s" % variant_name)
			return null
	else:
		instance = pool_data["available"].pop_back()

	# Reparent to the specified parent
	instance.reparent(parent)

	# Enable processing
	instance.process_mode = Node.PROCESS_MODE_INHERIT
	instance.visible = true

	pool_data["in_use"].append(instance)

	# Call spawn lifecycle method
	instance.on_spawn()

	return instance

## Get a random instance from scrap variants (Scrap1-5)
func get_random_scrap_instance(parent: Node) -> ResourceNode:
	var variants = ["Scrap1", "Scrap2", "Scrap3", "Scrap4", "Scrap5"]
	var selected = variants[RNG.rng.randi() % variants.size()]
	return get_instance(selected, parent)

func _return_to_pool(instance: ResourceNode, variant_name: String) -> void:
	if not _pools.has(variant_name):
		return

	var pool_data = _pools[variant_name]

	if not instance in pool_data["in_use"]:
		return

	pool_data["in_use"].erase(instance)

	# Call despawn lifecycle method (handles state reset)
	instance.on_despawn()

	# Reparent back to pool
	instance.reparent(self)

	# Disable processing
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	instance.visible = false

	pool_data["available"].append(instance)

## Return all active instances to the pool (useful for scene reset)
func return_all() -> void:
	for variant_name in _pools.keys():
		var pool_data = _pools[variant_name]
		for instance in pool_data["in_use"].duplicate():
			instance.returned_to_pool.emit()

## Get pool statistics for debugging
func get_stats() -> Dictionary:
	var stats = {}
	for variant_name in _pools.keys():
		var pool_data = _pools[variant_name]
		stats[variant_name] = {
			"available": pool_data["available"].size(),
			"in_use": pool_data["in_use"].size()
		}
	return stats
