extends ScrapNode
class_name DerelictShip

## A ship abandoned after running out of fuel. It keeps the hold it had and drifts
## where it was left (its momentum bleeds down to a slow tumble). It harvests like
## scrap: each hit releases an even share of what's left aboard, and the timing grade
## decides how much of that share survives, so all-PERFECT salvage recovers 100%.
## The hull itself is always worth something: the final hit adds a normal scrap break
## on top, and a ship abandoned with an empty hold salvages like ordinary scrap. Not pooled: lives in the world until broken, and is saved with the game.
## Abandoned with Freight clamped, it keeps the load on its nose (docs/adr/0012), damps
## to a full stop instead of a slow drift, and is marked on the Chart with what it holds.
## Breaking it frees the Freight, parked beside the wreck.

const HITS := 5
const COLLISION_RADIUS := 12.0
const DRIFT_DAMPING := 0.6      # per second, down toward...
const RESIDUAL_DRIFT := 6.0     # ...a slow drift (px/s)
const MAX_SPIN := 0.35
const HULL_TINT := Color(0.62, 0.6, 0.55, 1.0)  # powered-down hull
## Share of each hit's gems that survive, by timing grade.
const GRADE_KEEP := {
	HarvestTiming.Grade.PERFECT: 1.0,
	HarvestTiming.Grade.GOOD: 0.8,
	HarvestTiming.Grade.LATE: 0.5,
	HarvestTiming.Grade.OVERLOAD: 0.5,
}

const _SPARKLES := preload("res://entities/resources/SparkleParticles.tscn")

var loot: Array[String] = []    # gems still aboard
var drift := Vector2.ZERO
var spin := 0.0
var hull_source: Node2D = null  # polygons to copy for the visual (the player's hull)
var hull_only := false          # abandoned empty: salvages like plain scrap
var _armed := false             # harvestable once the player has respawned
## Belongs to the encounter field, which rebuilds it from the seed. Saving it too would
## leave a copy behind on every load.
var transient := false
## Freight left clamped to this hull, or null.
var freight: Freight = null
var _tracking: NodeTrackingTarget

## Leave `ship` adrift with its hold aboard (a bare hull if the hold is empty).
## A load on the nose stays on it, and the hull becomes the tracked target.
static func abandon(ship: Ship) -> DerelictShip:
	var items := HoldCashIn.launch_order(InventoryManager.get_all_items())
	var hits := HITS if not items.is_empty() else ScrapNode.NORMAL_HITS
	var derelict := spawn(ship.get_parent(), ship.ship_polygon, items, ship.global_position,
		ship.linear_velocity, ship.rotation, randf_range(-MAX_SPIN, MAX_SPIN), hits, false)
	if ship.is_carrying():
		derelict.hold_freight(ship.hand_freight_to(derelict))
	return derelict

## `armed` false keeps it out of harvest range detection until the player respawns.
static func spawn(world: Node, hull: Node2D, gems: Array[String], pos: Vector2, velocity: Vector2,
		rot: float, spin_speed: float, hits: int, armed := true) -> DerelictShip:
	var derelict := DerelictShip.new()
	derelict.hull_only = gems.is_empty()
	derelict._armed = armed
	derelict.monitorable = armed
	derelict.hull_source = hull
	derelict.loot = gems.duplicate()
	derelict.drift = velocity
	derelict.spin = spin_speed
	derelict.kind = "Derelict"
	world.add_child(derelict)
	derelict.hits_left = clampi(hits, 1, HITS)
	derelict.global_position = pos
	derelict.rotation = rot
	return derelict

static func clear_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("derelicts"):
		node.remove_from_group("derelicts")  # gone for saves this frame, not just at free
		node.queue_free()

## Every derelict in the world as plain data (for saving).
static func snapshot_all(tree: SceneTree) -> Array:
	var rows := []
	for d in tree.get_nodes_in_group("derelicts"):
		if d is DerelictShip and not d._is_depleted and not d.transient:
			rows.append({
				"x": d.global_position.x, "y": d.global_position.y,
				"vx": d.drift.x, "vy": d.drift.y,
				"rot": d.rotation, "spin": d.spin,
				"hits": d.hits_left, "loot": Array(d.loot), "hull_only": d.hull_only,
				"freight": d.freight.to_row() if d.is_holding_freight() else {},
			})
	return rows

static func restore_all(world: Node, hull: Node2D, rows: Array) -> void:
	for row in rows:
		if not row is Dictionary:
			continue
		var gems: Array[String] = []
		for id in row.get("loot", []):
			if GemData.is_gem(str(id)):
				gems.append(str(id))
		var d := spawn(world, hull, gems, Vector2(row.get("x", 0.0), row.get("y", 0.0)),
			Vector2(row.get("vx", 0.0), row.get("vy", 0.0)), row.get("rot", 0.0),
			row.get("spin", 0.0), int(row.get("hits", HITS)))
		# A loaded derelict whose hold ran dry mid-salvage still has hits left, not scrap drops
		d.hull_only = bool(row.get("hull_only", false))
		var load_row = row.get("freight", {})
		if load_row is Dictionary and not load_row.is_empty():
			var f := Freight.from_row(world, load_row)
			f.process_mode = Node.PROCESS_MODE_DISABLED
			d.hold_freight(f, false)

## Gems released by one hit: an even share of what's aboard (everything on the last
## hit), thinned by the grade. Removes the whole share from `gems`.
func is_holding_freight() -> bool:
	return freight != null and is_instance_valid(freight) and freight.get_parent() == self

## Keep `f` clamped where it is, out of physics. `track` makes this hull the tracked
## target, as abandoning it does.
func hold_freight(f: Freight, track := true) -> void:
	if f == null:
		return
	freight = f
	f.handled = true
	if f.get_parent() != self:
		f.reparent(self, true)
	if track:
		NavSystem.track(tracking_target())

## What the Chart calls this hull: what it holds.
func chart_label() -> String:
	return "HULL / %s" % freight.label if is_holding_freight() else "HULL"

func tracking_target() -> NodeTrackingTarget:
	if _tracking == null:
		_tracking = NodeTrackingTarget.new(self, chart_label(), 80.0)
	return _tracking

## Broken up: the Freight comes loose, parked beside the wreck, marked and tracked, like
## any piece the ship lets go of.
func free_freight() -> Freight:
	if not is_holding_freight():
		return null
	var f := freight
	freight = null
	f.reparent(get_parent(), true)
	f.process_mode = Node.PROCESS_MODE_INHERIT
	f.linear_velocity = Vector2.ZERO
	f.angular_velocity = 0.0
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship:
		f.part_from(ship, 1.0)
	NavSystem.track(f.tracking_target())
	return f

static func take_share(gems: Array[String], hits_left_after: int, grade: HarvestTiming.Grade, rng: RandomNumberGenerator) -> Array[String]:
	var count := gems.size() if hits_left_after <= 0 else ceili(gems.size() / float(hits_left_after + 1))
	var share: Array[String] = []
	for i in count:
		share.append(gems.pop_at(rng.randi_range(0, gems.size() - 1)))
	var keep := roundi(count * float(GRADE_KEEP.get(grade, 0.5)))
	return share.slice(0, keep)

func _ready() -> void:
	add_to_group("derelicts")
	super._ready()
	amount = 1
	max_amount = 1
	returned_to_pool.connect(queue_free)
	resource_depleted.connect(free_freight)
	if not EventBus.ship_respawned.is_connected(_arm):
		EventBus.ship_respawned.connect(_arm)

func _exit_tree() -> void:
	EventBus.unregister_resource_node(self)
	_unregister_indicator()
	if minimap_target:
		var minimap = Minimap.get_instance(get_tree())
		if minimap:
			minimap.unregister_target(minimap_target)
		minimap_target = null

func _register_with_minimap() -> void:
	var minimap = Minimap.get_instance(get_tree())
	if minimap and not minimap_target:
		minimap_target = DerelictMinimapTarget.new(self)
		minimap.register_target(minimap_target)

func _arm() -> void:
	_armed = true
	monitorable = true

## The player's own lost ship: never hidden among the debris.
func _hides_until_pinged() -> bool:
	return false

func _rolls_trophy() -> bool:
	return false

func max_hits() -> int:
	return ScrapNode.NORMAL_HITS if hull_only else HITS

func drops_for_hit(grade: HarvestTiming.Grade, final: bool) -> Array[String]:
	if hull_only:
		return super.drops_for_hit(grade, final)
	var drops := take_share(loot, 0 if final else hits_left, grade, RNG.rng)
	if final:
		loot.clear()
		drops.append_array(super.drops_for_hit(grade, true))  # the hull's own scrap
	return drops

## Its own momentum plus whatever it is riding. An abandoned ship has no orbit, so this
## is just its drift; a wreck the encounter field put on a ring also moves with the ring,
## and anything matching its velocity to salvage it needs to know that.
func get_orbital_velocity() -> Vector2:
	return drift + super.get_orbital_velocity()

func _physics_process(delta: float) -> void:
	drift = damped_drift(drift, delta, is_holding_freight())
	if is_holding_freight():
		spin *= exp(-DRIFT_DAMPING * delta)
	global_position += drift * delta
	rotation += spin * delta
	# Keep the player's own (pinned) ship from salvaging it before respawning.
	if not _armed:
		monitorable = false
	super._physics_process(delta)

## One step of the drift bleeding off: down to a slow residual drift, or - holding
## Freight, which must never wander off - to a full stop.
static func damped_drift(v: Vector2, delta: float, holding: bool) -> Vector2:
	var slow := v.limit_length(0.0 if holding else RESIDUAL_DRIFT)
	var out := slow + (v - slow) * exp(-DRIFT_DAMPING * delta)
	if holding and out.length() < 0.5:
		return Vector2.ZERO
	return out

func _load_shape() -> void:
	var circle := CircleShape2D.new()
	circle.radius = COLLISION_RADIUS
	var cshape := CollisionShape2D.new()
	cshape.name = "CollisionShape2D"
	cshape.shape = circle
	add_child(cshape)

	var visual := Node2D.new()
	visual.name = "DerelictVisual"
	visual.modulate = HULL_TINT
	add_child(visual)
	var area := Area2D.new()
	area.name = "CollisionArea"
	add_child(area)
	if hull_source:
		var to_local := hull_source.global_transform.affine_inverse()
		for poly in hull_source.find_children("*", "Polygon2D", true, false):
			var copy := Polygon2D.new()
			copy.polygon = poly.polygon
			copy.color = poly.color
			copy.transform = to_local * poly.global_transform
			visual.add_child(copy)
		var body := hull_source.get_node_or_null("Polygon2D") as Polygon2D
		if body:
			var hit := CollisionPolygon2D.new()
			hit.polygon = body.polygon
			hit.transform = body.transform
			area.add_child(hit)
	var sparkles := _SPARKLES.instantiate()
	sparkles.name = "SparkleParticles"
	add_child(sparkles)

## Powered-down hull that shrinks a little as it's stripped (never vanishes before the break).
func _update_visual() -> void:
	if _is_depleted or not health_component:
		return
	var visual := get_node_or_null("DerelictVisual") as Node2D
	if visual:
		visual.scale = Vector2.ONE * lerpf(0.7, 1.0, health_component.get_hp_ratio())
