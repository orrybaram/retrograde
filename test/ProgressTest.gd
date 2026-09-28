extends GdUnitTestSuite


## Tests for the Progress ledger through its own interface: marking a fact, asking whether
## it holds, listing a kind, and every fact surviving a round trip through the Store. All of
## it in memory, until the FileStore section at the end, which uses a scratch save file.

const KIND := Progress.IDENTIFIED_GATES


func test_a_new_ledger_holds_nothing() -> void:
	var ledger := Progress.new()
	assert_bool(ledger.holds(KIND, "Sun/Veld")).is_false()
	assert_array(Array(ledger.list(KIND))).is_empty()


func test_a_marked_fact_holds() -> void:
	var ledger := Progress.new()
	assert_bool(ledger.mark(KIND, "Sun/Veld")).is_true()
	assert_bool(ledger.holds(KIND, "Sun/Veld")).is_true()
	assert_bool(ledger.holds(KIND, "Sun/Crom")).is_false()


## Marking is once: the second mark is not what marked it, and nothing is listed twice.
func test_a_fact_is_marked_once() -> void:
	var ledger := Progress.new()
	ledger.mark(KIND, "Sun/Veld")
	assert_bool(ledger.mark(KIND, "Sun/Veld")).is_false()
	assert_array(Array(ledger.list(KIND))).contains_exactly(["Sun/Veld"])


## A thing with no key (a Gate with no planet) is never marked.
func test_an_empty_key_is_never_marked() -> void:
	var ledger := Progress.new()
	assert_bool(ledger.mark(KIND, "")).is_false()
	assert_array(Array(ledger.list(KIND))).is_empty()


func test_a_kind_lists_in_the_order_it_was_marked() -> void:
	var ledger := Progress.new()
	for key in ["Sun/Crom", "Sun/Veld", "Sun/Veld/Rook"]:
		ledger.mark(KIND, key)
	assert_array(Array(ledger.list(KIND))).contains_exactly(["Sun/Crom", "Sun/Veld", "Sun/Veld/Rook"])


## Nothing goes backwards: the list handed out is a copy, so emptying it takes nothing away.
func test_a_list_cannot_take_a_fact_away() -> void:
	var ledger := Progress.new()
	ledger.mark(KIND, "Sun/Veld")
	var listed := ledger.list(KIND)
	listed.clear()
	assert_bool(ledger.holds(KIND, "Sun/Veld")).is_true()


## Marking writes through: a continue from the same Store holds every fact, in order.
func test_marks_round_trip_through_the_store() -> void:
	var store := Progress.MemoryStore.new()
	var ledger := Progress.new(store)
	ledger.mark(KIND, "Sun/Crom")
	ledger.mark(KIND, "Sun/Veld")
	var resumed := Progress.new(store).resumed()
	assert_bool(resumed.holds(KIND, "Sun/Crom")).is_true()
	assert_array(Array(resumed.list(KIND))).contains_exactly(["Sun/Crom", "Sun/Veld"])


## A resumed ledger keeps writing to the same Store, adding to what it already held.
func test_a_resumed_ledger_adds_to_the_store() -> void:
	var store := Progress.MemoryStore.new()
	Progress.new(store).mark(KIND, "Sun/Crom")
	Progress.new(store).resumed().mark(KIND, "Sun/Veld")
	assert_array(Array(Progress.new(store).resumed().list(KIND))).contains_exactly(["Sun/Crom", "Sun/Veld"])


## A new game starts from nothing, whatever the last one earned.
func test_a_fresh_ledger_holds_nothing_from_the_last_game() -> void:
	var ledger := Progress.new()
	ledger.mark(KIND, "Sun/Veld")
	assert_array(Array(ledger.fresh().list(KIND))).is_empty()


## An empty Store (no save yet) resumes as an empty ledger.
func test_resuming_from_an_empty_store_holds_nothing() -> void:
	assert_array(Array(Progress.new().resumed().list(KIND))).is_empty()


## A GameState keeps its ledger in memory unless told otherwise, so a GameState made
## outside the game never writes to the player's save.
func test_a_game_state_keeps_its_progress_in_memory() -> void:
	var gs := auto_free(GameState.new()) as GameState
	gs.progress.mark(KIND, "Sun/Veld")
	assert_bool(gs.progress.resumed().holds(KIND, "Sun/Veld")).is_true()
	gs.reset_all_state()
	assert_bool(gs.progress.holds(KIND, "Sun/Veld")).is_false()


## Each kind is its own list: a key marked under one kind holds under no other.
func test_kinds_are_kept_apart() -> void:
	var ledger := Progress.new()
	ledger.mark(Progress.POWERED_GATES, "Sun/Veld")
	assert_bool(ledger.holds(Progress.POWERED_GATES, "Sun/Veld")).is_true()
	assert_bool(ledger.holds(Progress.IDENTIFIED_GATES, "Sun/Veld")).is_false()


## How many a kind holds, which is what the Titan Influence reads.
func test_count_is_how_many_a_kind_holds() -> void:
	var ledger := Progress.new()
	assert_int(ledger.count(Progress.POWERED_GATES)).is_equal(0)
	ledger.mark(Progress.POWERED_GATES, "Sun/Veld")
	ledger.mark(Progress.POWERED_GATES, "Sun/Crom")
	ledger.mark(Progress.POWERED_GATES, "Sun/Crom")
	assert_int(ledger.count(Progress.POWERED_GATES)).is_equal(2)


## A single-key kind (SR-7's cold start) is flagged once, and holds from then on.
func test_a_single_key_kind_is_flagged_once() -> void:
	var ledger := Progress.new()
	assert_bool(ledger.flagged(Progress.CORE_STARTED)).is_false()
	assert_bool(ledger.flag(Progress.CORE_STARTED)).is_true()
	assert_bool(ledger.flag(Progress.CORE_STARTED)).is_false()
	assert_bool(ledger.flagged(Progress.CORE_STARTED)).is_true()
	assert_int(ledger.count(Progress.CORE_STARTED)).is_equal(1)


## Every kind survives a continue from its Store.
func test_every_kind_round_trips_through_the_store() -> void:
	var store := Progress.MemoryStore.new()
	var ledger := Progress.new(store)
	for kind in Progress.KINDS:
		ledger.mark(kind, "key_" + kind)
	var resumed := Progress.new(store).resumed()
	for kind in Progress.KINDS:
		assert_array(Array(resumed.list(kind))).contains_exactly(["key_" + kind])


# --- The save file (FileStore) -----------------------------------------------

const SAVE_FILE := "user://progress_test_save.cfg"


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


## A save written before the ledger, with every kind where it was kept then.
func _legacy_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "stores", 42)
	cfg.set_value("visited", "planets", PackedStringArray(["Veld/Rook", "Sun/Veld"]))
	cfg.set_value("gates", "identified", PackedStringArray(["Sun/Veld", "Sun/Crom"]))
	cfg.set_value("gates", "powered", PackedStringArray(["Sun/Veld"]))
	cfg.set_value("finds", "identified_wrecks", PackedStringArray(["hauler_Veld"]))
	cfg.set_value("automatons", "met", PackedStringArray(["UNIT-7"]))
	cfg.set_value("sections", "seated", PackedStringArray([Sections.FUEL_TANK, Sections.SOLAR_ARRAY_2]))
	cfg.set_value("sections", "fitted", PackedStringArray([Components.CARGO_BAY]))
	cfg.set_value("sections", "core_started", true)
	# Not the ledger's: the Cradle and ore regrowth keep their own places
	cfg.set_value("sections", "cradled", PackedStringArray())
	cfg.set_value("ore", "regrow", {"Veld:0": 30.0})
	cfg.save(SAVE_FILE)


## An existing save loads with every Record intact, each read from where it always was.
func test_a_save_from_before_the_ledger_loads_with_every_record() -> void:
	_legacy_save()
	var ledger := Progress.new(Progress.FileStore.new(SAVE_FILE)).resumed()
	assert_array(Array(ledger.list(Progress.VISITED_BODIES))).is_equal(["Veld/Rook", "Sun/Veld"])
	assert_array(Array(ledger.list(Progress.IDENTIFIED_GATES))).is_equal(["Sun/Veld", "Sun/Crom"])
	assert_array(Array(ledger.list(Progress.POWERED_GATES))).is_equal(["Sun/Veld"])
	assert_array(Array(ledger.list(Progress.IDENTIFIED_WRECKS))).is_equal(["hauler_Veld"])
	assert_array(Array(ledger.list(Progress.MET_AUTOMATONS))).is_equal(["UNIT-7"])
	assert_array(Array(ledger.list(Progress.SEATED_SECTIONS))).is_equal(
		[Sections.FUEL_TANK, Sections.SOLAR_ARRAY_2])
	assert_array(Array(ledger.list(Progress.FITTED_COMPONENTS))).is_equal([Components.CARGO_BAY])
	assert_bool(ledger.flagged(Progress.CORE_STARTED)).is_true()


## Through a GameState, as a continue does it: every Record read back, and a lit station
## saved half-seated comes back whole.
func test_a_save_from_before_the_ledger_continues_with_every_record() -> void:
	_legacy_save()
	var gs := auto_free(GameState.new()) as GameState
	gs.progress = Progress.new(Progress.FileStore.new(SAVE_FILE)).resumed()
	gs.repair_station()
	assert_int(gs.titan_influence()).is_equal(1)
	assert_bool(gs.station_whole()).is_true()
	assert_array(Automatons.met(gs)).contains_exactly([Automatons.GUIDE])


## Marks go back where older saves kept them, in their old shape (the cold start a bool),
## and leave everything else in the file alone.
func test_marks_are_written_where_older_saves_kept_them() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "stores", 42)
	cfg.save(SAVE_FILE)
	var ledger := Progress.new(Progress.FileStore.new(SAVE_FILE))
	ledger.mark(Progress.VISITED_BODIES, "Sun/Veld")
	ledger.mark(Progress.MET_AUTOMATONS, "UNIT-7")
	ledger.mark(Progress.SEATED_SECTIONS, Sections.FUEL_TANK)
	ledger.flag(Progress.CORE_STARTED)
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "stores")).is_equal(42)
	assert_array(Array(cfg.get_value("visited", "planets"))).is_equal(["Sun/Veld"])
	assert_array(Array(cfg.get_value("automatons", "met"))).is_equal(["UNIT-7"])
	assert_array(Array(cfg.get_value("sections", "seated"))).is_equal([Sections.FUEL_TANK])
	assert_bool(cfg.get_value("sections", "core_started")).is_true()


## A full save carries the whole ledger in the same places (Save.save uses `put`), so a
## save written after the ledger reads back the same way.
func test_a_full_save_of_the_ledger_resumes_whole() -> void:
	var ledger := Progress.new()
	for kind in Progress.KINDS:
		if kind != Progress.CORE_STARTED:
			ledger.mark(kind, "key_" + kind)
	var cfg := ConfigFile.new()
	for kind in Progress.KINDS:
		Progress.FileStore.put(cfg, kind, ledger.list(kind))
	cfg.save(SAVE_FILE)
	assert_bool(cfg.get_value("sections", "core_started")).is_false()
	var resumed := Progress.new(Progress.FileStore.new(SAVE_FILE)).resumed()
	for kind in Progress.KINDS:
		assert_array(Array(resumed.list(kind))).is_equal(Array(ledger.list(kind)))


## A save whose core never started, from before any of the rest, holds none of them.
func test_a_save_from_before_the_records_holds_none() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "stores", 7)
	cfg.set_value("sections", "core_started", false)
	cfg.save(SAVE_FILE)
	var ledger := Progress.new(Progress.FileStore.new(SAVE_FILE)).resumed()
	for kind in Progress.KINDS:
		assert_int(ledger.count(kind)).is_equal(0)


## With no save yet, nothing is written: a facts-only file would enable CONTINUE.
func test_no_save_file_is_made_by_a_mark() -> void:
	var ledger := Progress.new(Progress.FileStore.new(SAVE_FILE))
	ledger.flag(Progress.CORE_STARTED)
	ledger.mark(Progress.SEATED_SECTIONS, Sections.FUEL_TANK)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()
