extends GdUnitTestSuite


## Tests for the Progress ledger through its own interface: marking a fact, asking whether
## it holds, listing a kind, and every fact surviving a round trip through the Store. All of
## it in memory: no save file is read or written.

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
