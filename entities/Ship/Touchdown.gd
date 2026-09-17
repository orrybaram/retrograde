extends RefCounted
class_name Touchdown

## Rules for setting the ship down on a planet. A touchdown needs the ship on the ground
## within reach of a revealed ore seam, moving slowly relative to the planet, nose roughly
## pointing away from the planet's centre. Coming in too fast damages the hull and bounces
## the ship off instead. Lifting off again burns fuel scaled by gravity and cargo weight.

enum Result { NONE, LAND, HARD }

const LANDING_SPEED := 40.0  # max speed relative to the planet for a touchdown
const NOSE_TOLERANCE := 0.61  # radians (~35 deg) between the nose and straight up
const REACH_MARGIN := 1.15  # slack on a seam's reach
const HARD_DAMAGE_MIN := 6.0
const BOUNCE := 0.6  # share of the impact speed thrown back out
const MIN_BOUNCE_SPEED := 60.0
const LIFTOFF_FUEL_PER_G := 8.0
const LIFTOFF_CARGO_FACTOR := 1.0 / 80.0  # +100% fuel per 80 units of cargo

## The revealed ore seam `pos` is within reach of, or null.
static func ore_under(planet: Planet, pos: Vector2) -> OreDeposit:
	for ore in planet.get_ore_deposits():
		if ore.is_revealed() and in_reach(ore, pos):
			return ore
	return null

static func in_reach(ore: OreDeposit, pos: Vector2) -> bool:
	var bearing := (pos - ore.planet.global_position).angle()
	return absf(angle_difference(ore.global_rotation, bearing)) <= ore.reach_angle() * REACH_MARGIN

## Outcome of ground contact at `rel_velocity` (relative to the planet) with the nose at
## `rotation`, where `up` points from the planet's centre to the ship.
static func judge(rel_velocity: Vector2, rotation: float, up: Vector2) -> Result:
	if rel_velocity.length() >= LANDING_SPEED:
		return Result.HARD if rel_velocity.dot(up) < 0.0 else Result.NONE
	if absf(angle_difference(rotation, up.angle())) > NOSE_TOLERANCE:
		return Result.NONE
	return Result.LAND

static func hard_damage(speed: float, crash_damage_multiplier: float) -> float:
	return maxf(HARD_DAMAGE_MIN, (speed - LANDING_SPEED) * crash_damage_multiplier)

## World velocity after a bounce: the impact is thrown back out (at least
## MIN_BOUNCE_SPEED) and sideways drift is halved.
static func bounce_velocity(rel_velocity: Vector2, up: Vector2, planet_velocity: Vector2) -> Vector2:
	var into := rel_velocity.dot(up)
	var sideways := rel_velocity - up * into
	return planet_velocity + sideways * 0.5 + up * maxf(-into * BOUNCE, MIN_BOUNCE_SPEED)

## Fuel burned lifting off a planet of `gravity` G with `cargo_weight` in the hold.
static func liftoff_cost(gravity: float, cargo_weight: float) -> float:
	return LIFTOFF_FUEL_PER_G * gravity * (1.0 + cargo_weight * LIFTOFF_CARGO_FACTOR)
