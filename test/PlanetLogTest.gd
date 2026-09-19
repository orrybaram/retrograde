extends GdUnitTestSuite

## Visited: a Body whose inner orbit the ship has entered earns its Record in the Log,
## scanner or no scanner (docs/adr/0003). Covers the marking reach, the moon and sun
## keys, the save round trip, and the Records tab that reads it back.

const SAVE_FILE := "user://visit_test_save.cfg"

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


func _planet(pos: Vector2, radius := 100.0, type := Planet.PlanetType.ROCKY, body_name := "") -> Planet:
	var planet := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	planet.radius = radius
	planet.planet_type = type
	if body_name != "":
		planet.name = body_name
		planet.planet_name = body_name
	add_child(planet)
	planet.global_position = pos
	return planet


## A moon is a Planet parented to a Planet, which is what makes its key "Parent/Name".
func _moon(parent: Planet, offset: Vector2, radius := 50.0, body_name := "") -> Planet:
	var moon := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	moon.radius = radius
	moon.planet_type = Planet.PlanetType.BARREN
	moon.enable_orbiting = false
	if body_name != "":
		moon.name = body_name
		moon.planet_name = body_name
	parent.add_child(moon)
	moon.global_position = parent.global_position + offset
	return moon


func _planet_log() -> PlanetLog:
	var planet_log := auto_free(PlanetLog.new()) as PlanetLog
	add_child(planet_log)
	return planet_log


# --- Marking -----------------------------------------------------------------

## Inner orbit is the whole of the reach: the same distance the scanner needs.
func test_a_body_is_visited_at_inner_orbit_and_no_further_out() -> void:
	var planet := _planet(Vector2.ZERO, 100.0, Planet.PlanetType.ROCKY, "Crom")
	var planet_log := _planet_log()
	var inner := planet.scan_radius()
	assert_object(planet_log.mark_at(Vector2(inner + 1.0, 0), SAVE_FILE)).is_null()
	assert_object(planet_log.mark_at(Vector2(planet.field_radius() - 1.0, 0), SAVE_FILE)).is_null()
	assert_bool(_gs.is_planet_visited("Crom")).is_false()
	assert_object(planet_log.mark_at(Vector2(inner - 1.0, 0), SAVE_FILE)).is_same(planet)
	assert_bool(_gs.is_planet_visited("Crom")).is_true()
	assert_bool(planet.is_visited()).is_true()


## The Record is earned once; flying back through does not earn it again.
func test_a_record_is_earned_once() -> void:
	var planet := _planet(Vector2.ZERO, 100.0, Planet.PlanetType.ROCKY, "Crom")
	var planet_log := _planet_log()
	var inside := Vector2(planet.scan_radius() - 1.0, 0)
	assert_object(planet_log.mark_at(inside, SAVE_FILE)).is_same(planet)
	assert_object(planet_log.mark_at(inside, SAVE_FILE)).is_null()
	assert_int(_gs.visited_planets.size()).is_equal(1)


## Visiting has to work from the first minute, before the array is ever bought —
## which is why it cannot live in PlanetScanner (docs/adr/0003).
func test_visiting_does_not_need_the_planet_scanner() -> void:
	var planet := _planet(Vector2.ZERO, 100.0, Planet.PlanetType.ROCKY, "Crom")
	var planet_log := _planet_log()
	assert_bool(_gs.has_planet_scanner).is_false()
	assert_object(planet_log.mark_at(Vector2(planet.scan_radius() - 1.0, 0), SAVE_FILE)).is_same(planet)
	assert_bool(_gs.is_planet_visited("Crom")).is_true()
	assert_bool(_gs.is_planet_scanned("Crom")).is_false()


## The sun and a moon are Bodies like any planet, and a moon's key is "Parent/Name".
func test_the_sun_and_a_moon_earn_records_by_the_same_rule() -> void:
	var sun := _planet(Vector2.ZERO, 5000.0, Planet.PlanetType.SUN, "Sun")
	var veld := _planet(Vector2(100000, 0), 400.0, Planet.PlanetType.ROCKY, "Veld")
	var rook := _moon(veld, Vector2(2000, 0), 50.0, "Rook")
	var planet_log := _planet_log()
	assert_object(planet_log.mark_at(Vector2(sun.scan_radius() - 1.0, 0), SAVE_FILE)).is_same(sun)
	assert_object(planet_log.mark_at(rook.global_position, SAVE_FILE)).is_same(rook)
	assert_bool(_gs.is_planet_visited("Sun")).is_true()
	assert_bool(_gs.is_planet_visited("Veld/Rook")).is_true()
	assert_str(rook.save_key()).is_equal("Veld/Rook")
	assert_bool(_gs.is_planet_visited("Veld")).is_false()


## A moon wins inside its parent's field: the deepest Body takes the Record.
func test_the_deepest_body_earns_the_record() -> void:
	var veld := _planet(Vector2.ZERO, 400.0, Planet.PlanetType.ROCKY, "Veld")
	var rook := _moon(veld, Vector2(300, 0), 50.0, "Rook")
	var planet_log := _planet_log()
	assert_object(planet_log.mark_at(rook.global_position, SAVE_FILE)).is_same(rook)


# --- Save --------------------------------------------------------------------

func test_visited_bodies_round_trip_through_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 12)
	cfg.save(SAVE_FILE)
	Save.save_visited_planets(PackedStringArray(["Veld/Rook", "Sun"]), SAVE_FILE)
	assert_array(Array(Save.load_visited_planets(SAVE_FILE))).contains_exactly(["Veld/Rook", "Sun"])
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits")).is_equal(12)


## Reaching a Body in open flight writes it straight away — there is no dock to hang a
## full save off.
func test_marking_writes_the_save_on_the_spot() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 12)
	cfg.save(SAVE_FILE)
	var planet := _planet(Vector2.ZERO, 100.0, Planet.PlanetType.ROCKY, "Crom")
	_planet_log().mark_at(Vector2(planet.scan_radius() - 1.0, 0), SAVE_FILE)
	assert_array(Array(Save.load_visited_planets(SAVE_FILE))).contains_exactly(["Crom"])


func test_visit_save_needs_an_existing_save() -> void:
	Save.save_visited_planets(PackedStringArray(["Crom"]), SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()
	assert_int(Save.load_visited_planets(SAVE_FILE).size()).is_equal(0)


func test_a_new_game_forgets_every_visit() -> void:
	_gs.mark_planet_visited("Veld/Rook")
	_gs.reset_all_state()
	assert_bool(_gs.is_planet_visited("Veld/Rook")).is_false()


# --- Records tab -------------------------------------------------------------

func _records_tab() -> RecordsTab:
	var tab := auto_free(RecordsTab.new()) as RecordsTab
	add_child(tab)
	tab.refresh()
	return tab


## Every Label's text under `node`, in tree order.
func _text(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_text(child))
	return out


## A player who has stayed home gets the empty state, not a list of somewhere to go.
func test_no_visits_leaves_the_bodies_list_empty() -> void:
	var tab := _records_tab()
	assert_bool(tab._empty.visible).is_true()
	assert_bool(tab._bodies.visible).is_false()
	assert_str("\n".join(_text(tab))).not_contains("? ? ?")
	assert_str(tab.hint()).is_equal(LogTab.SHELL_KEYS)


## A Body reached with no scanner aboard gets a row, and the row says so.
func test_an_unsurveyed_body_reads_no_survey() -> void:
	var veld := _planet(Vector2.ZERO, 400.0, Planet.PlanetType.ROCKY, "Veld")
	var rook := _moon(veld, Vector2(2000, 0), 50.0, "Rook")
	_gs.mark_planet_visited(rook.save_key())
	var tab := _records_tab()
	var text := "\n".join(_text(tab))
	assert_bool(tab._bodies.visible).is_true()
	assert_str(text).contains("B O D I E S")
	assert_str(text).contains("ROOK")
	assert_str(text).contains(RecordsTab.NO_SURVEY)
	# The detail pane names the Body and what it orbits.
	var detail := "\n".join(_text(tab._body_detail))
	assert_str(detail).contains("DESIGNATION")
	assert_str(detail).contains("ROOK")
	assert_str(detail).contains("ORBITS")
	assert_str(detail).contains("VELD")


## Scanning fills the Record in; the row stops reading NO SURVEY.
func test_a_surveyed_body_carries_its_survey() -> void:
	var planet := _planet(Vector2.ZERO, 400.0, Planet.PlanetType.ICE_GIANT, "Sonder")
	_gs.mark_planet_visited(planet.save_key())
	_gs.mark_planet_scanned(planet.save_key())
	var tab := _records_tab()
	var text := "\n".join(_text(tab))
	assert_str(text).contains(RecordsTab.SURVEYED)
	assert_str(text).not_contains(RecordsTab.NO_SURVEY)
	assert_str("\n".join(_text(tab._body_detail))).contains("ICE GIANT")


## No row for a Body the player has not reached, and never `? ? ?`.
func test_only_visited_bodies_get_a_row() -> void:
	var reached := _planet(Vector2.ZERO, 400.0, Planet.PlanetType.ROCKY, "Crom")
	_planet(Vector2(100000, 0), 400.0, Planet.PlanetType.ROCKY, "Sonder")
	_gs.mark_planet_visited(reached.save_key())
	var tab := _records_tab()
	var text := "\n".join(_text(tab))
	assert_str(text).contains("CROM")
	assert_str(text).not_contains("SONDER")
	assert_str(text).not_contains("? ? ?")
	assert_int(tab._body_rows.get_child_count()).is_equal(1)


## UP / DOWN move the one cursor and the detail pane follows it.
func test_up_and_down_move_the_cursor_and_the_detail_follows() -> void:
	var crom := _planet(Vector2.ZERO, 400.0, Planet.PlanetType.ROCKY, "Crom")
	var sonder := _planet(Vector2(100000, 0), 400.0, Planet.PlanetType.ICE_GIANT, "Sonder")
	_gs.mark_planet_visited(crom.save_key())
	_gs.mark_planet_visited(sonder.save_key())
	var tab := _records_tab()
	assert_int(tab._cursor).is_equal(0)
	assert_str("\n".join(_text(tab._body_detail))).contains("CROM")
	assert_bool(tab.handle_key(KEY_DOWN)).is_true()
	assert_int(tab._cursor).is_equal(1)
	assert_str("\n".join(_text(tab._body_detail))).contains("SONDER")
	assert_bool(tab.handle_key(KEY_UP)).is_true()
	assert_int(tab._cursor).is_equal(0)
	assert_str("\n".join(_text(tab._body_detail))).contains("CROM")
	# and the cursor wraps rather than sticking at the ends
	tab.handle_key(KEY_UP)
	assert_int(tab._cursor).is_equal(1)


## The bottom border only offers the cursor keys once there is a list to move through.
func test_the_cursor_keys_appear_with_the_first_record() -> void:
	var crom := _planet(Vector2.ZERO, 400.0, Planet.PlanetType.ROCKY, "Crom")
	_gs.mark_planet_visited(crom.save_key())
	var tab := _records_tab()
	assert_str(tab.hint()).contains(RecordsTab.CURSOR_KEYS)
	assert_str(tab.hint()).contains(LogTab.SHELL_KEYS)


## Nothing to move through, nothing to swallow: LEFT / RIGHT stay unclaimed either way.
func test_unclaimed_keys_pass_through() -> void:
	var crom := _planet(Vector2.ZERO, 400.0, Planet.PlanetType.ROCKY, "Crom")
	_gs.mark_planet_visited(crom.save_key())
	var tab := _records_tab()
	assert_bool(tab.handle_key(KEY_LEFT)).is_false()
	assert_bool(tab.handle_key(KEY_RIGHT)).is_false()
