extends RefCounted
class_name PlanetScan

## Scan meter for the Planetary Scanner. Fills while the same planet stays in range and
## resets when it drops out (or another planet takes over). Pure logic: PlanetScanner
## feeds it the planet whose inner orbit holds the ship each physics tick.

const SCAN_TIME := 20.0

var target: Planet = null
var progress := 0.0

## Advance with `planet` (null when none is in range). Returns true on the tick the scan
## completes; the meter is then cleared for the next planet.
func update(planet: Planet, delta: float) -> bool:
	if planet != target:
		target = planet
		progress = 0.0
	if target == null:
		return false
	progress = minf(progress + delta / SCAN_TIME, 1.0)
	if progress < 1.0:
		return false
	target = null
	progress = 0.0
	return true

func reset() -> void:
	update(null, 0.0)

## The unscanned planet whose inner orbit `pos` sits deepest in (relative to that
## planet's scan range, so a moon wins inside its parent's field). The scanner only
## reaches inner orbit - flying past the edge of the gravity field is not enough.
## The sun is never scanned.
static func pick(pos: Vector2, planets: Array) -> Planet:
	var best: Planet = null
	var best_depth := INF
	for node in planets:
		var planet := node as Planet
		if not planet or planet.planet_type == Planet.PlanetType.SUN or planet.is_scanned():
			continue
		var depth := pos.distance_to(planet.global_position) / planet.scan_radius()
		if depth <= 1.0 and depth < best_depth:
			best = planet
			best_depth = depth
	return best

## Survey readout rows for a scanned planet, label column padded for monospace.
static func readout_lines(planet: Planet) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append(_row("DESIGNATION", planet.planet_name.to_upper()))
	if planet.is_moon():
		lines.append(_row("ORBITS", planet.parent_planet.planet_name.to_upper()))
	lines.append(_row("CLASS", type_name(planet.planet_type)))
	lines.append(_row("HABITABLE", "%d%%" % roundi(planet.habitability * 100.0)))
	lines.append(_row("GRAVITY", "%.1f G" % planet.surface_gravity()))
	var seams := planet.get_ore_deposits().size()
	lines.append(_row("ORE", "%d SEAMS" % seams if seams > 0 else "NONE FOUND"))
	return lines

static func type_name(type: Planet.PlanetType) -> String:
	return str(Planet.PlanetType.keys()[type]).replace("_", " ")

static func _row(label: String, value: String) -> String:
	return label.rpad(13) + value
