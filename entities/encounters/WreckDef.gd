extends EncounterDef
class_name WreckDef

## A wrecked ship adrift between planets, salvaged the way an abandoned ship is: each
## clean cut recovers a share of what is still in its hold, and the hull itself breaks
## for scrap on the last one.
##
## With no `hull` set it is built from the player's own hull instead — the clone
## predecessor wreck from docs/DESIGN.md §4.1, a ship that matches theirs exactly. Those
## want a `budget` so they stay a shock rather than a fixture.

## The silhouette to build the wreck from. Null means the player's own ship.
@export var hull: PackedScene

## Gems still aboard. Rolled from these bounds, drawn from `loot_tiers`.
@export var min_loot: int = 2
@export var max_loot: int = 6
@export var loot_tiers: Array[String] = ["shard", "gem", "crystal"]

@export var max_spin: float = 0.25

## Harvest-detection radius, for hulls bigger than the player's own. 0 keeps
## DerelictShip's default, which is sized for an abandoned scavenger ship.
@export var harvest_radius: float = 0.0

var _hull_instance: Node2D = null

func plan(rng: RandomNumberGenerator, origin: Vector2) -> Array[Dictionary]:
	var loot: Array[String] = []
	for i in rng.randi_range(min_loot, max_loot):
		loot.append(loot_tiers[rng.randi() % loot_tiers.size()] if loot_tiers else "shard")
	return [{
		"pos": origin,
		"rotation": rng.randf() * TAU,
		"spin": rng.randf_range(-max_spin, max_spin),
		"loot": loot,
	}]

func build(field: Node2D, entry: Dictionary) -> Node:
	var silhouette := _silhouette(field)
	if not silhouette:
		return null
	var loot: Array[String] = []
	for id in entry.get("loot", []):
		loot.append(str(id))
	var wreck := DerelictShip.spawn(field, silhouette, loot, entry["pos"], Vector2.ZERO,
		entry["rotation"], entry["spin"], DerelictShip.HITS)
	wreck.transient = true  # the field rebuilds it from the seed; the save must not
	if harvest_radius > 0.0:
		var circle := wreck.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if circle and circle.shape is CircleShape2D:
			(circle.shape as CircleShape2D).radius = harvest_radius
	return wreck

## Not pooled — DerelictShip lives in the world until it is broken.
func release(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.remove_from_group("derelicts")  # gone for saves this frame, not just at free
	node.queue_free()

## The polygons to copy. The player's hull for a clone wreck, otherwise one instance of
## `hull` kept alive under the field and reused by every wreck of this kind.
func _silhouette(field: Node2D) -> Node2D:
	if not hull:
		var ship := field.get_tree().get_first_node_in_group("ship") as Ship
		return ship.ship_polygon if ship else null
	if not is_instance_valid(_hull_instance):
		_hull_instance = hull.instantiate() as Node2D
		if not _hull_instance:
			return null
		_hull_instance.name = "%s_silhouette" % id
		_hull_instance.visible = false
		field.add_child(_hull_instance)
	return _hull_instance
