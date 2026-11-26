extends Resource
class_name SonarMaterial

## What a Sweep ring does inside something (SonarSurface): how much of its reach it loses
## there, how fast it goes, and how the surface answers. A ring is a set of rays
## (SonarPulse); each pays for every px it crosses in "effective distance", and dies when
## that runs out. Open space costs 1 per px.

## Extra reach lost per px crossed, on top of the 1/speed it costs to cross it. INF is a
## solid: the ray's amplitude drops to 0 inside, though the ray keeps going (so the shadow
## behind can fill back in from its open neighbours).
@export var density := 0.0
## How fast the ring moves inside, as a share of open space (finite materials only).
@export var speed := 1.0
## Whether a hard hit throws a faint reflected arc back.
@export var echo := false
## Whether the outline wants to know where rings touched it (SonarSurface.touched).
@export var reactive := false
## Whether a touch is answered with the found trace.
@export var discoverable := false

## Solid hull plate: the station, wrecks.
static var PLATE := make(INF, 1.0, true)
## Rock: drains reach, so only a strong ring gets through. (Nothing in the world carries
## it yet: debris is too small to shape a ring.)
static var ROCK := make(3.0, 0.8, true)
## A Body's ground: solid.
static var PLANET := make(INF, 1.0, true)

static func make(density_value: float, speed_value: float, echoes: bool) -> SonarMaterial:
	var m := SonarMaterial.new()
	m.density = density_value
	m.speed = speed_value
	m.echo = echoes
	return m

func is_solid() -> bool:
	return is_inf(density)

## Effective distance a ray pays per px crossed inside.
func cost() -> float:
	if is_solid():
		return 1.0
	return 1.0 / maxf(speed, 0.01) + density
