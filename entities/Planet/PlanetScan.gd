extends RefCounted
class_name PlanetScan

## What there is to know about a Body, as rows of text: the inner-orbit reach that marks
## it Visited, and the survey format its Record in the Log shows. Pure logic. Nothing
## surveys a Body in play now - the planetary scan is gone until `ECHO` is designed
## (docs/IDEAS.md §13) - so the survey rows only show for a Body marked scanned.

## Width of the class column in a one-line summary, so a column of them lines up.
const CLASS_COLUMN := 11
## Width of the label column in a readout row, so the values line up in monospace.
const LABEL_COLUMN := 13

## The Body whose inner orbit `pos` sits deepest in (relative to that Body's scan
## range, so a moon wins inside its parent's field), or null when none holds it.
## Inner orbit is the whole of the reach: flying past the edge of the gravity field is
## not enough. Entering it is what marks a Body Visited (docs/adr/0003).
static func deepest(pos: Vector2, planets: Array) -> Planet:
	var best: Planet = null
	var best_depth := INF
	for node in planets:
		var planet := node as Planet
		if not planet:
			continue
		var depth := pos.distance_to(planet.global_position) / planet.scan_radius()
		if depth <= 1.0 and depth < best_depth:
			best = planet
			best_depth = depth
	return best

## The rows every Record carries whether or not it holds a survey: what the Body is
## called, and for a moon what it orbits. `orbits` is "" for anything but a moon.
static func identity_lines(designation: String, orbits: String) -> PackedStringArray:
	var lines := PackedStringArray([_row("DESIGNATION", designation)])
	if orbits != "":
		lines.append(_row("ORBITS", orbits))
	return lines

## Survey readout rows for a scanned planet, label column padded for monospace. This is
## the one survey format in the game: the Body's Record in the Log holds these rows. The
## sun is surveyed like any other Body and honestly reports no ore (docs/GLOSSARY.md).
static func readout_lines(planet: Planet) -> PackedStringArray:
	var lines := identity_lines(planet.planet_name.to_upper(),
			planet.parent_planet.planet_name.to_upper() if planet.is_moon() else "")
	lines.append(_row("CLASS", type_name(planet.planet_type)))
	lines.append(_row("HABITABLE", "%d%%" % roundi(planet.habitability * 100.0)))
	lines.append(_row("GRAVITY", gravity(planet)))
	var seams := planet.get_ore_deposits().size()
	lines.append(_row("ORE", "%d SEAMS" % seams if seams > 0 else "NONE FOUND"))
	return lines

## The survey in one line, for a list with no room for the full readout: what the Body
## is and how hard it pulls. Same instrument, fewer rows — the class column is padded
## so a column of these lines up.
static func summary_line(planet: Planet) -> String:
	return type_name(planet.planet_type).rpad(CLASS_COLUMN) + gravity(planet)

static func type_name(type: Planet.PlanetType) -> String:
	return str(Planet.PlanetType.keys()[type]).replace("_", " ")

## Surface pull in G. The sun reads through the same instrument as everything else.
static func gravity(planet: Planet) -> String:
	return "%.1f G" % planet.surface_gravity()

static func _row(label: String, value: String) -> String:
	return label.rpad(LABEL_COLUMN) + value
