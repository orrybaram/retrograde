extends OrbitalNode
class_name DebrisNode

## Non-harvestable orbital decoration. Extends OrbitalNode but disables
## harvest detection (Area2D monitoring). Comes back on the minimap as plain debris.

func _ready() -> void:
	_uses_harvest_detection = false
	super._ready()

	add_to_group("debris_nodes")
	# Rock drains a Sweep ring's reach: a tap is lost in it, a long hold gets through
	var outline := get_node_or_null("CollisionArea/CollisionPolygon2D") as CollisionPolygon2D
	if outline and get_node_or_null("SonarSurface") == null:
		SonarSurface.attach(self, outline, SonarSurface.Preset.ROCK)

	# No harvest detection — disable root Area2D monitoring
	monitoring = false
	monitorable = false

func _register_with_minimap() -> void:
	_register_debris_echo()

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
