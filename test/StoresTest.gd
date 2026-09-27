extends GdUnitTestSuite

## Credits are gone: what the hold brings home is SR-7's Stores, filled by the Deposit
## (docs/adr/0007). Stores survive a save under their own name, an old save's credits are
## left behind, and dying costs none of them.

const SAVE_FILE := "user://stores_test_save.cfg"
const GAME_OVER_CALLS := [
	"res://entities/Robot/radio/messages/ship_destroyed.tres",
	"res://entities/Robot/radio/messages/ship_abandoned.tres",
	"res://entities/Robot/radio/messages/void_consumed.tres",
]

var _gs: GameState
var _was_active: bool
var _was_file: String

func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	add_child(_gs)
	# Point Save at a scratch file rather than the player's own save.
	_was_active = Playtest.active
	_was_file = Playtest._save_file
	Playtest.active = true
	Playtest._save_file = SAVE_FILE

func after_test() -> void:
	Playtest.active = _was_active
	Playtest._save_file = _was_file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


func test_game_state_keeps_stores_not_credits() -> void:
	assert_bool("stores" in _gs).is_true()
	assert_bool("credits" in _gs).is_false()
	assert_int(_gs.stores).is_equal(0)


func test_changing_the_stores_tells_listeners() -> void:
	var fired := [0]
	_gs.stores_changed.connect(func(): fired[0] += 1)
	_gs.stores = 120
	assert_int(fired[0]).is_equal(1)


func test_stores_round_trip_through_the_save() -> void:
	_gs.stores = 420
	Save.save(_gs, null)
	var cfg := ConfigFile.new()
	assert_int(cfg.load(SAVE_FILE)).is_equal(OK)
	assert_int(cfg.get_value("stats", "stores")).is_equal(420)
	assert_bool(cfg.has_section_key("stats", "credits")).is_false()
	_gs.stores = 0
	Save.load_into(_gs, null)
	assert_int(_gs.stores).is_equal(420)


func test_an_old_saves_credits_are_left_behind() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 900)
	cfg.save(SAVE_FILE)
	Save.load_into(_gs, null)
	assert_int(_gs.stores).is_equal(0)


func test_relaunching_has_no_fee() -> void:
	var main := load("res://scripts/Main.gd") as GDScript
	assert_bool(main.get_script_constant_map().has("RELAUNCH_PENALTY")).is_false()
	for path: String in GAME_OVER_CALLS:
		var conv := load(path) as RadioConversation
		assert_str(conv.lines[-1].confirm_text()).override_failure_message(path).is_equal("RELAUNCH")
