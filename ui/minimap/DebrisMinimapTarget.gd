extends MinimapTarget
class_name DebrisMinimapTarget

## MinimapTarget for the junk in an orbital ring: DebrisNodes, and scrap no Sweep has found
## yet. Both come back as the same small smudge, so the scope can't tell unfound scrap from
## debris any more than the eye can. Once a Sweep lights scrap up this goes quiet and its
## ResourceMinimapTarget takes over, which rings out as a discovery.

## The same reach as a chunk of scrap (ResourceMinimapTarget.ECHO_RADIUS).
const ECHO_RADIUS := ResourceMinimapTarget.ECHO_RADIUS
const STRENGTH := 0.45

var node: OrbitalNode

func _init(n: OrbitalNode) -> void:
	node = n

func get_minimap_position() -> Vector2:
	if not node or not is_instance_valid(node):
		return Vector2.ZERO
	# Distant/sleeping nodes don't update global_position every frame
	var orbital = node._orbital_motion
	if orbital and orbital.initialized:
		var pos = orbital.get_predicted_global_position()
		if pos != Vector2.ZERO:
			return pos
	return node.global_position

func echo_world_radius() -> float:
	return ECHO_RADIUS

## Faint: the ring's junk is background, so it mustn't drown what is worth flying to.
func echo_strength() -> float:
	return STRENGTH

func is_minimap_visible() -> bool:
	if not node or not is_instance_valid(node):
		return false
	var scrap := node as ScrapNode
	return scrap == null or not (scrap.revealed or scrap._is_depleted)

func get_minimap_node() -> Node2D:
	return node
