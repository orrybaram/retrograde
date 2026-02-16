extends OrbitalNode
class_name DebrisNode

func _ready() -> void:
	_uses_harvest_detection = false
	super._ready()

	add_to_group("debris_nodes")

	# No harvest detection — disable root Area2D monitoring
	monitoring = false
	monitorable = false

func _register_with_minimap() -> void:
	# Debris not shown on minimap
	pass

func on_spawn() -> void:
	super.on_spawn()

	if not is_in_group("debris_nodes"):
		add_to_group("debris_nodes")

	# Ensure harvest detection stays off
	monitoring = false
	monitorable = false

func on_despawn() -> void:
	if is_in_group("debris_nodes"):
		remove_from_group("debris_nodes")

	super.on_despawn()
