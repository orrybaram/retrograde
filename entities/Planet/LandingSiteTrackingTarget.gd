extends NodeTrackingTarget
class_name LandingSiteTrackingTarget

## Tracks a LandingSite. The site is a plain Node2D riding its planet, so its velocity
## is the planet's. Invalid while the site is hidden (its planet isn't scanned).

const LABEL := "SITE"
const ARRIVAL_RADIUS := 60.0

func _init(site: LandingSite) -> void:
	super(site, LABEL, ARRIVAL_RADIUS)

func get_velocity() -> Vector2:
	var site := node as LandingSite
	return site.velocity() if is_valid() else Vector2.ZERO

func is_valid() -> bool:
	return super() and (node as LandingSite).is_revealed()
