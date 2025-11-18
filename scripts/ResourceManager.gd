extends Node
class_name ResourceManager

func _ready() -> void:
	add_to_group("resource_manager")
	# ResourceSpawner nodes handle their own spawning via auto_spawn
	# This manager can be used for coordination or manual control if needed

func spawn_all_resources() -> void:
	# Manually trigger spawning on all ResourceSpawners (useful if auto_spawn is disabled)
	var spawners = get_tree().get_nodes_in_group("resource_spawners")
	for spawner in spawners:
		if spawner.has_method("spawn_cluster"):
			spawner.spawn_cluster()
