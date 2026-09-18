extends EncounterDef
class_name DebrisClusterDef

## A loose knot of scrap and dead debris adrift between planets — the common transit
## encounter from docs/DESIGN.md §4.1. Fly through, take what's worth taking.
##
## Built entirely from the existing pooled resource variants, so a cluster costs nothing
## the planet rings don't already cost.

const SCRAP_VARIANTS := ["Scrap1", "Scrap2", "Scrap3", "Scrap4", "Scrap5"]
const DEBRIS_VARIANTS := ["Debris1", "Debris2", "Debris3", "Debris4", "Debris5"]

@export var min_nodes: int = 4
@export var max_nodes: int = 10
## Radius of the knot. Well inside a cell so clusters stay recognisable as one thing.
@export var spread: float = 900.0
@export_range(0.0, 1.0) var debris_ratio: float = 0.4

func plan(rng: RandomNumberGenerator, origin: Vector2) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i in rng.randi_range(min_nodes, max_nodes):
		var is_debris := rng.randf() < debris_ratio
		var variants := DEBRIS_VARIANTS if is_debris else SCRAP_VARIANTS
		# sqrt() spreads the picks evenly over the disc instead of bunching them at the centre
		var offset := Vector2.RIGHT.rotated(rng.randf() * TAU) * sqrt(rng.randf()) * spread
		entries.append({
			"variant": variants[rng.randi() % variants.size()],
			"pos": origin + offset,
			"scale": rng.randf_range(0.5, 1.0),
			"rotation": rng.randf() * TAU,
			"spin": rng.randf_range(-0.4, 0.4),
		})
	return entries

func build(field: Node2D, entry: Dictionary) -> Node:
	var node := ResourceNodePool.get_instance(str(entry["variant"]), field)
	if not node:
		return null
	node.global_position = entry["pos"]
	node.rotation = entry["rotation"]
	node.scale = Vector2.ONE * float(entry["scale"])
	node._rotation_speed = entry["spin"]
	if node is ScrapNode:
		var scrap := node as ScrapNode
		scrap.amount = 1
		scrap.max_amount = 1
	node._update_visual()
	return node
