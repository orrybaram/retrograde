extends GdUnitTestSuite

## Tests for how heavy a Body is (docs/adr/0004). Mass is derived from class density and
## radius, so surface pull is density times radius: a wider Body always outweighs a
## narrower one of the same stuff. These guard the ordering the home system is built on -
## the sun an order of magnitude clear of everything, no moon outweighing its planet.


func _planet(radius: float, type := Planet.PlanetType.ROCKY, trim := 1.0) -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	planet.planet_type = type
	planet.density_trim = trim
	add_child(planet)
	return planet


# --- The rule ----------------------------------------------------------------

func test_the_reference_body_reads_the_reference_gravity() -> void:
	var terra := _planet(Planet.REFERENCE_RADIUS, Planet.PlanetType.EARTH_LIKE)
	assert_float(terra.surface_gravity()).is_equal_approx(Planet.REFERENCE_GRAVITY, 0.01)


func test_a_wider_body_of_the_same_stuff_always_pulls_harder() -> void:
	var small := _planet(800.0, Planet.PlanetType.BARREN)
	var large := _planet(3200.0, Planet.PlanetType.BARREN)
	assert_float(large.surface_gravity()).is_greater(small.surface_gravity())
	# Four times as wide, four times the pull: surface gravity is linear in radius
	assert_float(large.surface_gravity()).is_equal_approx(small.surface_gravity() * 4.0, 0.01)


func test_a_denser_class_pulls_harder_at_the_same_width() -> void:
	var ice := _planet(2000.0, Planet.PlanetType.ICE)
	var rock := _planet(2000.0, Planet.PlanetType.EARTH_LIKE)
	assert_float(rock.surface_gravity()).is_greater(ice.surface_gravity())


func test_density_trim_scales_a_body_off_its_class() -> void:
	var plain := _planet(2000.0, Planet.PlanetType.BARREN)
	var dense := _planet(2000.0, Planet.PlanetType.BARREN, 2.0)
	assert_float(dense.surface_gravity()).is_equal_approx(plain.surface_gravity() * 2.0, 0.01)


## The Record and the gravity field read the same mass, so the number the player is shown
## is the pull they actually fly against. Nothing may special-case one without the other.
func test_the_record_reads_the_pull_the_field_applies() -> void:
	var planet := _planet(1500.0, Planet.PlanetType.ROCKY)
	var field_pull_at_surface: float = planet._get_gravity_strength() / (planet.radius * planet.radius)
	assert_float(planet.surface_gravity() * Planet.STANDARD_GRAVITY).is_equal_approx(
		field_pull_at_surface, 0.001)
	assert_float(planet.surface_gravity()).is_equal_approx(planet.target_surface_gravity(), 0.001)


# --- The home system ---------------------------------------------------------

## Every Body in HomeSystem.tscn, rebuilt from the scene's own radius and class, as
## {path, name, planet}. Read off the scene state so the real authored numbers are what
## gets checked.
func _home_bodies() -> Array:
	var state := (load("res://scenes/HomeSystem.tscn") as PackedScene).get_state()
	var bodies: Array = []
	for i in state.get_node_count():
		var path := str(state.get_node_path(i))
		var props: Dictionary = {}
		for p in state.get_node_property_count(i):
			props[str(state.get_node_property_name(i, p))] = state.get_node_property_value(i, p)
		if not props.has("planet_name"):
			continue
		var planet := _planet(
			float(props.get("radius", 160.0)),
			int(props.get("planet_type", Planet.PlanetType.ROCKY)) as Planet.PlanetType,
			float(props.get("density_trim", 1.0)))
		bodies.append({"path": path, "name": str(props["planet_name"]), "planet": planet})
	return bodies


func test_the_home_system_holds_every_body_this_suite_expects() -> void:
	var names: Array = _home_bodies().map(func(b: Dictionary) -> String: return b["name"])
	assert_array(names).contains(["Sun", "TERRA-0", "Sonder", "Crom", "Roke", "Veld", "Rook"])


## The Core sits in the sun and it is meant to be the last and hardest place to reach
## (CONTEXT.md, Sun Station). Before ADR 0004 the sun read 1.6 G and Rook, a moon, read
## 1.7 G.
func test_the_sun_outweighs_every_other_body_by_an_order_of_magnitude() -> void:
	var bodies := _home_bodies()
	var sun: Planet = null
	var heaviest_planet := 0.0
	for b in bodies:
		if b["name"] == "Sun":
			sun = b["planet"]
		else:
			heaviest_planet = maxf(heaviest_planet, (b["planet"] as Planet).surface_gravity())
	assert_object(sun).is_not_null()
	assert_float(sun.surface_gravity()).is_greater(heaviest_planet * 5.0)


func test_no_moon_outweighs_the_body_it_orbits() -> void:
	var by_path: Dictionary = {}
	for b in _home_bodies():
		by_path[b["path"]] = b
	for path in by_path:
		var parent_path := str(path).get_base_dir()
		if not by_path.has(parent_path):
			continue
		var moon: Planet = by_path[path]["planet"]
		var parent: Planet = by_path[parent_path]["planet"]
		assert_float(moon.surface_gravity()).override_failure_message(
			"%s outweighs %s" % [by_path[path]["name"], by_path[parent_path]["name"]]
		).is_less(parent.surface_gravity())
