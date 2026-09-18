extends EncounterDef
class_name ContainerDef

## A sealed container adrift on its own — the design doc's "worth the detour?" encounter.
## One node, trophy grade: five clean cuts instead of three, and a much better class of
## gem out of each one. Nothing else is nearby, so taking it costs fuel and time.

const VARIANT := "Container"

@export var min_drift_spin: float = 0.05
@export var max_drift_spin: float = 0.25

func plan(rng: RandomNumberGenerator, origin: Vector2) -> Array[Dictionary]:
	return [{
		"pos": origin,
		"rotation": rng.randf() * TAU,
		"spin": rng.randf_range(min_drift_spin, max_drift_spin) * (1.0 if rng.randf() < 0.5 else -1.0),
	}]

func build(field: Node2D, entry: Dictionary) -> Node:
	var node := ResourceNodePool.get_instance(VARIANT, field) as ScrapNode
	if not node:
		return null
	node.global_position = entry["pos"]
	node.rotation = entry["rotation"]
	node.scale = Vector2.ONE
	node._rotation_speed = entry["spin"]
	node.amount = 1
	node.max_amount = 1
	node.is_trophy = true  # also sets hits_left to TROPHY_HITS
	node._update_visual()
	return node
