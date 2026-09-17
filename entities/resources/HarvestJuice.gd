extends RefCounted
class_name HarvestJuice

## Payoff effects for a finished extraction, scaled by tier and timing grade:
## hitstop, camera shake, particle burst, a shockwave ring on PERFECT, and the
## loot chip flying into the HUD cargo readout.

## hitstop: seconds of near-frozen time. burst: particle intensity multiplier.
const TIER_JUICE := {
	"slag":      {"hitstop": 0.0,  "burst": 0.5},
	"scrap":     {"hitstop": 0.03, "burst": 0.8},
	"salvage":   {"hitstop": 0.05, "burst": 1.0},
	"component": {"hitstop": 0.07, "burst": 1.4},
	"mil_spec":  {"hitstop": 0.10, "burst": 1.8},
	"artifact":  {"hitstop": 0.16, "burst": 2.6},
}
const PERFECT_HITSTOP_BONUS := 0.05
const HITSTOP_TIME_SCALE := 0.05

static var _hitstop_restore := -1.0

static func play(ship: Ship, scrap: ScrapNode, grade: HarvestTiming.Grade, tier_item_id: String) -> void:
	var juice: Dictionary = TIER_JUICE.get(tier_item_id, TIER_JUICE["scrap"])
	var perfect := grade == HarvestTiming.Grade.PERFECT
	var botched := grade == HarvestTiming.Grade.LATE or grade == HarvestTiming.Grade.OVERLOAD
	var color := SparkleParticles.tier_color(tier_item_id)

	var sparkles := scrap.get_node_or_null("SparkleParticles") as SparkleParticles
	if sparkles:
		sparkles.pop(tier_item_id, juice["burst"] * (1.4 if perfect else 1.0))

	if ship and is_instance_valid(ship):
		var mult: float = ScrapNode.TIER_SHAKE_MULT.get(tier_item_id, 1.0)
		if botched:
			mult = 0.6
		elif perfect:
			mult *= 1.3
		ship.damage_shake_time = ship.harvest_shake_duration
		ship.damage_shake_current_intensity = ship.harvest_shake_intensity * mult

		var world := ship.get_parent()
		if perfect:
			ring(world, scrap.global_position, color, 70.0)
		elif botched:
			ring(world, scrap.global_position, Colors.DANGER, 30.0)

	var stop: float = juice["hitstop"] + (PERFECT_HITSTOP_BONUS if perfect else 0.0)
	if stop > 0.0:
		hitstop(scrap.get_tree(), stop)

	var hud := scrap.get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fly_item_to_cargo"):
		hud.fly_item_to_cargo(scrap.global_position, color, tier_item_id != "slag" and tier_item_id != "scrap")

## Briefly slow the whole game. Overlapping calls extend rather than stack.
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if _hitstop_restore < 0.0:
		_hitstop_restore = Engine.time_scale
	Engine.time_scale = _hitstop_restore * HITSTOP_TIME_SCALE
	tree.create_timer(seconds, true, false, true).timeout.connect(func():
		if _hitstop_restore >= 0.0:
			Engine.time_scale = _hitstop_restore
			_hitstop_restore = -1.0)

## Expanding shockwave circle at a world position.
static func ring(parent: Node, world_pos: Vector2, color: Color, radius: float) -> void:
	if not parent:
		return
	var line := Line2D.new()
	var points := PackedVector2Array()
	for i in 33:
		points.append(Vector2.RIGHT.rotated(TAU * i / 32.0) * 10.0)
	line.points = points
	line.width = 0.6
	line.default_color = color
	line.z_index = 5
	parent.add_child(line)
	line.global_position = world_pos
	var tween := line.create_tween().set_parallel(true)
	var s := radius / 10.0
	tween.tween_property(line, "scale", Vector2(s, s), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(line, "width", 0.15, 0.45)
	tween.tween_property(line, "modulate:a", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(line.queue_free)
