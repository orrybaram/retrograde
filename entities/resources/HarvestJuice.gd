extends RefCounted
class_name HarvestJuice

## Payoff effects for a harvest hit, scaled by the best gem dropped, timing grade,
## and whether the hit broke the scrap: hitstop, camera shake, particle burst, and a
## shockwave ring on PERFECT or on the final break.

## hitstop: seconds of near-frozen time. burst: particle intensity. shake: camera multiplier.
const TIER_JUICE := {
	"shard":    {"hitstop": 0.0,  "burst": 0.5, "shake": 0.5},
	"gem":      {"hitstop": 0.03, "burst": 0.8, "shake": 0.9},
	"crystal":  {"hitstop": 0.07, "burst": 1.4, "shake": 1.6},
	"artifact": {"hitstop": 0.14, "burst": 2.4, "shake": 3.0},
}
const PERFECT_HITSTOP_BONUS := 0.05
const FINAL_HITSTOP_BONUS := 0.04
const FINAL_BURST_MULT := 1.6
const HITSTOP_TIME_SCALE := 0.05

static var _hitstop_restore := -1.0

static func play(ship: Ship, scrap: ScrapNode, grade: HarvestTiming.Grade, gem_id: String, final: bool) -> void:
	var juice: Dictionary = TIER_JUICE.get(gem_id, TIER_JUICE["shard"])
	var perfect := grade == HarvestTiming.Grade.PERFECT
	var botched := grade == HarvestTiming.Grade.LATE or grade == HarvestTiming.Grade.OVERLOAD
	var color := GemData.color_of(gem_id)

	var sparkles := scrap.get_node_or_null("SparkleParticles") as SparkleParticles
	if sparkles:
		var intensity: float = juice["burst"] * (1.4 if perfect else 1.0) * (FINAL_BURST_MULT if final else 1.0)
		sparkles.pop(color, intensity)

	if ship and is_instance_valid(ship):
		var mult: float = juice["shake"]
		if botched:
			mult = 0.6
		elif perfect:
			mult *= 1.3
		if final:
			mult *= 1.4
		ship.damage_shake_time = ship.harvest_shake_duration
		ship.damage_shake_current_intensity = ship.harvest_shake_intensity * mult

		var world := ship.get_parent()
		# Scrap keeps orbiting, so the ring drifts with it to stay centred.
		var drift := scrap.get_orbital_velocity()
		if botched:
			ring(world, scrap.global_position, Colors.DANGER, 30.0, drift)
		elif perfect or final:
			ring(world, scrap.global_position, color, 90.0 if final else 70.0, drift)

	var stop: float = juice["hitstop"] + (PERFECT_HITSTOP_BONUS if perfect else 0.0) + (FINAL_HITSTOP_BONUS if final else 0.0)
	if stop > 0.0:
		hitstop(scrap.get_tree(), stop)

## Briefly slow the whole game. Overlapping calls extend rather than stack.
static func hitstop(tree: SceneTree, seconds: float) -> void:
	if _hitstop_restore < 0.0:
		_hitstop_restore = Engine.time_scale
	Engine.time_scale = _hitstop_restore * HITSTOP_TIME_SCALE
	tree.create_timer(seconds, true, false, true).timeout.connect(func():
		if _hitstop_restore >= 0.0:
			Engine.time_scale = _hitstop_restore
			_hitstop_restore = -1.0)

## Expanding shockwave circle at a world position, moving at `velocity` (px/s).
static func ring(parent: Node, world_pos: Vector2, color: Color, radius: float, velocity := Vector2.ZERO) -> void:
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
	tween.tween_method(func(t: float): line.global_position = world_pos + velocity * t, 0.0, 0.45, 0.45)
	tween.chain().tween_callback(line.queue_free)
