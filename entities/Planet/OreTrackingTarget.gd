extends NodeTrackingTarget
class_name OreTrackingTarget

## Tracks an OreDeposit. The seam is a plain Node2D riding its planet, so its velocity is
## the planet's. Invalid while the seam is hidden: its planet isn't scanned, or it's been
## drilled out and hasn't refilled yet.

const LABEL := "ORE"
const ARRIVAL_RADIUS := 60.0

func _init(ore: OreDeposit) -> void:
	super(ore, LABEL, ARRIVAL_RADIUS)

func get_velocity() -> Vector2:
	var ore := node as OreDeposit
	return ore.velocity() if is_valid() else Vector2.ZERO

func is_valid() -> bool:
	var ore := node as OreDeposit
	return super() and ore.is_revealed() and not ore.is_spent()
