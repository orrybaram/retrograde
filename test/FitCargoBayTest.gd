extends GdUnitTestSuite

## Fitting the Cargo Bay (docs/OPENING.md §9, docs/adr/0014): SR-7's dock offers SHIP, with
## a count of what waits in the Cradle, and SHIP has one FIT row for each Component waiting
## and a STOW row for each one on the hull. Fitted, it is the ship's 50-unit hold - kept through a save and a load,
## and gone again on a new game - and the wreck on Veld never puts another one back.

const SAVE_FILE := "user://fit_cargo_bay_test_save.cfg"

var _gs: GameState
var _station: SpaceStation
var _was_active: bool
var _was_file: String

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	_station = auto_free(load("res://entities/structures/SpaceStation.tscn").instantiate()) as SpaceStation
	add_child(_station)
	InventoryManager.clear_inventory()
	# Point Save at a scratch file rather than the player's own save.
	_was_active = Playtest.active
	_was_file = Playtest._save_file
	Playtest.active = true
	Playtest._save_file = SAVE_FILE
	await get_tree().process_frame

func after_test() -> void:
	Playtest.active = _was_active
	Playtest._save_file = _was_file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	InventoryManager.clear_inventory()

func _ship() -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	add_child(ship)
	return ship

func _port() -> SpacePort:
	return _station.get_node("DockArm/Slide/SpacePort") as SpacePort

func _cradle() -> Cradle:
	return Cradle.find(get_tree())

func _dialogue(port: SpacePort) -> SpacePortDialogue:
	var dialogue := auto_free(load("res://ui/SpacePortDialogue.tscn").instantiate()) as SpacePortDialogue
	add_child(dialogue)
	dialogue.open_dialogue(port)
	return dialogue

func _labels(dialogue: SpacePortDialogue) -> Array:
	return dialogue._menu_items.map(func(item: Dictionary) -> String: return item["label"])

# --- the dock menu ---

func _open_ship(dialogue: SpacePortDialogue) -> void:
	assert_str(dialogue._menu_items[0]["label"]).is_equal("SHIP")
	dialogue._activate_selection()
	assert_str(dialogue._page).is_equal("ship")

func test_sr7s_dock_always_offers_ship() -> void:
	var dialogue := _dialogue(_port())
	assert_array(_labels(dialogue)).contains_exactly(["SHIP", "DEPART"])
	assert_str(dialogue._menu_items[0].get("aside", "")).override_failure_message("no count with nothing waiting").is_empty()

func test_ship_counts_what_is_waiting() -> void:
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	var dialogue := _dialogue(_port())
	assert_str(dialogue._menu_items[0]["aside"]).is_equal("1")
	assert_int(dialogue._selected_index).is_equal(0)

func test_ship_offers_a_fit_row_for_each_component_waiting() -> void:
	_gs.cradled = PackedStringArray([Components.CARGO_BAY, Components.CARGO_BAY])
	var dialogue := _dialogue(_port())
	_open_ship(dialogue)
	assert_array(_labels(dialogue)).contains_exactly(["FIT CARGO BAY", "FIT CARGO BAY", "BACK"])

func test_back_returns_to_the_hub() -> void:
	var dialogue := _dialogue(_port())
	_open_ship(dialogue)
	assert_array(_labels(dialogue)).contains_exactly(["BACK"])
	dialogue._activate_selection()
	assert_str(dialogue._page).is_equal("hub")
	assert_array(_labels(dialogue)).contains_exactly(["SHIP", "DEPART"])

func test_only_sr7s_dock_offers_it() -> void:
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	var elsewhere := auto_free(load("res://entities/structures/SpacePort.tscn").instantiate()) as SpacePort
	add_child(elsewhere)
	assert_array(_labels(_dialogue(elsewhere))).contains_exactly(["DEPART"])
	assert_array(_labels(_dialogue(null))).contains_exactly(["DEPART"])

func test_fitting_from_ship_gives_the_ship_its_hold() -> void:
	var ship := _ship()
	assert_bool(ship.has_hold()).is_false()
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	_cradle().refresh()
	var dialogue := _dialogue(_port())
	_open_ship(dialogue)
	var hold := [-1.0]
	ship.cargo_changed.connect(func(_w: float, m: float) -> void: hold[0] = m)
	dialogue._activate_selection()
	assert_float(ship.max_cargo_weight).is_equal(50.0)
	assert_bool(ship.has_hold()).is_true()
	assert_float(hold[0]).override_failure_message("the readout hears of it").is_equal(50.0)
	assert_bool(_gs.progress.holds(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)).is_true()
	assert_array(_gs.cradled).is_empty()
	assert_bool(_cradle().is_full()).override_failure_message("the Cradle is empty again").is_false()
	# The FIT row becomes a STOW row, and the page stays up
	assert_array(_labels(dialogue)).contains_exactly(["STOW CARGO BAY", "BACK"])
	assert_bool(dialogue.visible).is_true()
	assert_str(dialogue._page).is_equal("ship")

func test_stowing_from_ship_puts_it_back_in_the_cradle() -> void:
	var ship := _ship()
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	_cradle().fit()
	var dialogue := _dialogue(_port())
	_open_ship(dialogue)
	assert_array(_labels(dialogue)).contains_exactly(["STOW CARGO BAY", "BACK"])
	dialogue._activate_selection()
	assert_array(_gs.cradled).contains_exactly([Components.CARGO_BAY])
	assert_array(_gs.fitted()).is_empty()
	assert_float(ship.max_cargo_weight).is_equal(0.0)
	assert_array(_labels(dialogue)).contains_exactly(["FIT CARGO BAY", "BACK"])

func test_closing_from_ship_leaves_the_hub_for_next_time() -> void:
	var dialogue := _dialogue(_port())
	_open_ship(dialogue)
	dialogue.close_dialogue()
	assert_str(dialogue._page).is_equal("hub")

# --- keeping it ---

func test_fitting_is_written_to_the_save_at_once() -> void:
	_gs.progress = Progress.new(Progress.FileStore.new(SAVE_FILE))
	_gs.cradled = PackedStringArray([Components.CARGO_BAY])
	Save.save(_gs, null)
	_cradle().fit()
	var held := Progress.new(Progress.FileStore.new(SAVE_FILE)).resumed()
	assert_array(Array(held.list(Progress.FITTED_COMPONENTS))).contains_exactly([Components.CARGO_BAY])
	assert_array(Save.load_cradled(SAVE_FILE)).is_empty()

func test_a_load_keeps_the_hold() -> void:
	_gs.progress.mark(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)
	Save.save(_gs, null)
	var gs := auto_free(GameState.new()) as GameState
	gs.progress = Progress.new(Progress.FileStore.new(SAVE_FILE))
	var ship := _ship()
	Save.load_into(gs, ship)
	assert_bool(gs.progress.holds(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)).is_true()
	assert_float(ship.max_cargo_weight).is_equal(50.0)

func test_a_save_from_before_fitting_has_no_hold() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "max_cargo_weight", 50.0)
	cfg.save(SAVE_FILE)
	var ship := _ship()
	Save.load_into(_gs, ship)
	assert_int(_gs.progress.count(Progress.FITTED_COMPONENTS)).is_equal(0)
	assert_float(ship.max_cargo_weight).is_equal(0.0)

func test_a_new_game_has_nothing_fitted() -> void:
	var ship := _ship()
	_gs.progress.mark(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)
	ship.refit(_gs)
	_gs.reset_all_state()
	ship.reset_to_initial_state()
	assert_int(_gs.progress.count(Progress.FITTED_COMPONENTS)).is_equal(0)
	assert_float(ship.max_cargo_weight).is_equal(0.0)

func test_once_fitted_the_wreck_leaves_no_copy() -> void:
	var veld := auto_free(load("res://entities/Planet/Planet.tscn").instantiate()) as Planet
	veld.radius = 2400.0
	veld.enable_orbiting = false
	add_child(veld)
	var wreck: HaulerWreck = auto_free(HaulerWreck.new())
	veld.add_child(wreck)
	_gs.progress.mark(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)
	wreck.ensure_cargo_bay()
	assert_object(wreck.find_piece()).is_null()
