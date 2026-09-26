extends GdUnitTestSuite

## An Automaton's Record: meeting UNIT-7 on the first transmission, that meeting
## surviving a save, and the A U T O M A T O N S section of the Log's Records tab
## (ui/log/RecordsTab.gd). The Bodies section has its own tests; what is tested here is
## the one cursor running through both.
##
## The Log lists only what the player reached, so the empty state has to stay
## reachable (docs/adr/0003).

const RADIO_SCRIPT := preload("res://scripts/RobotRadio.gd")
const SAVE_FILE := "user://automaton_test_save.cfg"
const GUIDE := Automatons.GUIDE

var _gs: GameState


func before_test() -> void:
	_gs = auto_free(GameState.new()) as GameState
	_gs.set_process(false)
	add_child(_gs)


func after_test() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))


# --- Meeting an Automaton ----------------------------------------------------

## The radio is a link to UNIT-7 at SR-7, so the first transmission is the meeting.
func test_the_guide_is_met_on_the_first_transmission() -> void:
	var radio := _radio()
	assert_bool(_gs.has_met_automaton("UNIT-7")).is_false()
	radio.request(_conv(&"hello"))
	assert_bool(_gs.has_met_automaton("UNIT-7")).is_true()


func test_the_guide_is_filed_under_the_designation_its_record_uses() -> void:
	var radio := _radio()
	radio.request(_conv(&"hello"))
	assert_array(_gs.met_automatons.keys()).contains_exactly([GUIDE.record_key()])
	assert_str(GUIDE.record_key()).is_equal("UNIT-7")


## The Log only ever gains Records: a second transmission changes nothing.
func test_meeting_the_guide_again_adds_nothing() -> void:
	var radio := _radio()
	radio.request(_conv(&"hello"))
	radio.silence()
	radio.request(_conv(&"again"))
	assert_int(_gs.met_automatons.size()).is_equal(1)


# --- The save ----------------------------------------------------------------

func test_met_automatons_round_trip_through_the_save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 42)
	cfg.save(SAVE_FILE)
	Save.save_met_automatons(PackedStringArray(["UNIT-7"]), SAVE_FILE)
	assert_array(Array(Save.load_met_automatons(SAVE_FILE))).contains_exactly(["UNIT-7"])
	cfg.load(SAVE_FILE)
	assert_int(cfg.get_value("stats", "credits")).is_equal(42)
	# Meeting an Automaton is not powering a Gate: the lists are kept apart
	assert_int(Save.load_powered_gates(SAVE_FILE).size()).is_equal(0)


func test_met_automatons_need_an_existing_save() -> void:
	Save.save_met_automatons(PackedStringArray(["UNIT-7"]), SAVE_FILE)
	assert_bool(FileAccess.file_exists(SAVE_FILE)).is_false()
	assert_int(Save.load_met_automatons(SAVE_FILE).size()).is_equal(0)


func test_a_save_from_before_records_reads_as_nobody_met() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 7)
	cfg.save(SAVE_FILE)
	assert_int(Save.load_met_automatons(SAVE_FILE).size()).is_equal(0)


func test_a_new_game_clears_the_met_automatons() -> void:
	_gs.mark_automaton_met("UNIT-7")
	_gs.reset_all_state()
	assert_bool(_gs.met_automatons.is_empty()).is_true()
	assert_bool(_gs.has_met_automaton("UNIT-7")).is_false()


# --- Notes -------------------------------------------------------------------

## The Record is never empty: the Guide's first Note is keyed to no Modules online.
func test_the_guide_holds_a_note_from_the_first_transmission() -> void:
	assert_array(GUIDE.notes_at(0)).has_size(1)


## Every step of Titan Influence, stubbed in turn. The Guide's Notes are keyed to
## 0, 1, 3 and 5, so steps 2 and 4 add nothing and no step ever takes one back.
func test_every_step_of_influence_reveals_the_guides_notes() -> void:
	var counts: Array[int] = []
	for influence in range(Gate.MODULE_COUNT + 1):
		counts.append(GUIDE.notes_at(influence).size())
	assert_array(counts).contains_exactly([1, 2, 2, 3, 3, 4])


## A Note is the player's own writing, not the Guide talking: terminal uppercase, and
## none of the Guide's radio or greeting register (docs/GLOSSARY.md).
func test_the_guides_notes_are_not_the_guide_talking() -> void:
	for note in GUIDE.notes_at(Gate.MODULE_COUNT):
		assert_str(note).is_equal(note.to_upper())
		assert_str(note).not_contains("Welcome")


func test_a_note_waits_for_the_influence_step_it_is_keyed_to() -> void:
	var npc := NPCData.new()
	npc.record_notes = ["IT NEVER ASKS WHERE I WENT.", "IT KNEW THE NAME BEFORE I SAID IT."]
	npc.note_influence = [0, 3]
	assert_array(npc.notes_at(0)).contains_exactly(["IT NEVER ASKS WHERE I WENT."])
	assert_array(npc.notes_at(2)).contains_exactly(["IT NEVER ASKS WHERE I WENT."])
	assert_array(npc.notes_at(3)).contains_exactly(
			["IT NEVER ASKS WHERE I WENT.", "IT KNEW THE NAME BEFORE I SAID IT."])


# --- The Records tab ---------------------------------------------------------

func test_a_met_automaton_gets_a_row_under_the_heading() -> void:
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	assert_array(_text_of(tab._automatons)).contains(["A U T O M A T O N S", "UNIT-7", "SR-7"])
	assert_bool(tab._automatons.visible).is_true()
	assert_bool(tab._empty.visible).is_false()


## No Record, no row and no heading — and never `? ? ?` (docs/adr/0003).
func test_nothing_met_and_nowhere_visited_leaves_the_empty_state_up() -> void:
	var tab := _records_tab()
	assert_array(tab._met).is_empty()
	assert_bool(tab._empty.visible).is_true()
	assert_bool(tab._automatons.visible).is_false()
	assert_bool(tab._bodies.visible).is_false()
	var text := _text_of(tab)
	assert_array(text).contains(["NOTHING LOGGED YET."])
	assert_array(text).not_contains(["A U T O M A T O N S", "? ? ?"])


## A player who has met the Guide and flown nowhere still holds a Record, so the
## Automatons section stands on its own.
func test_the_automatons_section_stands_without_the_bodies() -> void:
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	assert_bool(tab._bodies.visible).is_false()
	assert_bool(tab._automatons.visible).is_true()


## The Record is the player's written note on an Automaton, not a portrait of it: the
## designation and where it was met, then the Notes. The robot's face belongs to the
## store screen, where the player is actually standing in front of it.
func test_the_record_shows_the_designation_and_station_without_a_portrait() -> void:
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	assert_array(_text_of(tab._detail)).contains(["UNIT-7", "STATION   SR-7"])
	assert_array(_text_of(tab._detail)).not_contains([GUIDE.ascii_art])


## Nothing speaks from inside the Log: the Record is a note, not a greeting.
func test_the_record_says_nothing_the_guide_would_say() -> void:
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	for line in _text_of(tab._detail):
		assert_str(line).not_contains("Welcome")


## The pane lists the unlocked Notes under the designation block, in authored order.
func test_the_pane_lists_the_notes_the_player_has_reached() -> void:
	_gs.mark_automaton_met("UNIT-7")
	_power_modules(3)
	var tab := _records_tab()
	assert_array(_text_of(tab._detail)).contains(GUIDE.notes_at(3))


## A locked Note leaves no placeholder and no count — the pane shows what the player
## reached and nothing standing in for the rest (docs/adr/0003).
func test_a_locked_note_leaves_nothing_behind_in_the_pane() -> void:
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	var text := _text_of(tab._detail)
	assert_array(text).contains(GUIDE.notes_at(0))
	for note in GUIDE.record_notes.slice(1):
		assert_array(text).not_contains([note])
	for line in text:
		assert_str(line).not_contains("? ? ?")


## Stepping Modules online is the dev panel's preview path: each step the Guide has a
## Note keyed to puts one more line in the pane, and no step takes one away.
func test_raising_modules_online_reveals_further_notes() -> void:
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	var seen := _text_of(tab._detail).size()
	for influence in range(1, Gate.MODULE_COUNT + 1):
		_power_modules(influence)
		tab.refresh()
		var lines := _text_of(tab._detail)
		assert_array(lines).contains(GUIDE.notes_at(influence))
		assert_int(lines.size()).is_greater_equal(seen)
		seen = lines.size()


## Notes are not saved: they derive from Titan Influence, which is the powered Gates
## the save already carries. Reloading those gives the same Notes back.
func test_unlocked_notes_come_back_with_the_powered_gates() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "credits", 0)
	cfg.save(SAVE_FILE)
	_power_modules(3)
	Save.save_powered_gates(PackedStringArray(_gs.powered_gates.keys()), SAVE_FILE)

	var loaded := auto_free(GameState.new()) as GameState
	for key in Save.load_powered_gates(SAVE_FILE):
		loaded.mark_gate_powered(key)
	assert_int(loaded.titan_influence()).is_equal(3)
	assert_array(GUIDE.notes_at(loaded.titan_influence())).is_equal(GUIDE.notes_at(3))


## The one cursor carries out of the Bodies section and into the Automatons, rather
## than the Automatons adding a second level of navigation.
func test_down_carries_the_cursor_from_a_body_into_the_automatons() -> void:
	_gs.mark_planet_visited("Sun/Veld")
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	assert_str(tab.selected_key()).is_equal("Sun/Veld")
	assert_int(tab._automaton_index()).is_equal(-1)

	assert_bool(tab.handle_key(KEY_DOWN)).is_true()
	assert_int(tab._automaton_index()).is_equal(0)
	assert_str(tab.selected_key()).is_equal("")
	assert_array(_text_of(tab._automaton_rows)).contains([">"])
	assert_array(_text_of(tab._detail)).contains(["UNIT-7"])
	# Both sections share the one detail column, so opening the Automaton's Record
	# closes the Body's behind it rather than leaving a second pane standing empty.
	assert_str("\n".join(_text_of(tab._detail))).not_contains("VELD")

	assert_bool(tab.handle_key(KEY_UP)).is_true()
	assert_str(tab.selected_key()).is_equal("Sun/Veld")
	assert_str("\n".join(_text_of(tab._detail))).not_contains("UNIT-7")


## With no Records at all the keys go back to the shell rather than being swallowed.
func test_an_empty_list_claims_no_keys() -> void:
	var tab := _records_tab()
	assert_bool(tab.handle_key(KEY_DOWN)).is_false()
	assert_bool(tab.handle_key(KEY_UP)).is_false()


## LEFT / RIGHT stay unclaimed for a future tab's adjustable rows.
func test_left_and_right_stay_unclaimed() -> void:
	_gs.mark_automaton_met("UNIT-7")
	var tab := _records_tab()
	assert_bool(tab.handle_key(KEY_LEFT)).is_false()
	assert_bool(tab.handle_key(KEY_RIGHT)).is_false()


## A Record on its own is enough to earn the cursor keys in the bottom border.
func test_a_met_automaton_earns_the_cursor_keys() -> void:
	var tab := _records_tab()
	assert_str(tab.hint()).is_equal(LogTab.SHELL_KEYS)
	_gs.mark_automaton_met("UNIT-7")
	tab.refresh()
	assert_str(tab.hint()).is_equal("%s   %s" % [RecordsTab.CURSOR_KEYS, LogTab.SHELL_KEYS])


# --- Parts -------------------------------------------------------------------

## A radio in the tree, with its show-once flags kept out of the player's save.
func _radio() -> Node:
	var radio: Node = auto_free(RADIO_SCRIPT.new())
	radio.persist = false
	add_child(radio)
	return radio


func _conv(id: StringName) -> RadioConversation:
	return RadioConversation.make(id, [RadioLine.make("%s line" % id)])


## Titan Influence stubbed at `count`: one powered Gate per Module online, which is
## exactly what GameState.titan_influence() counts and what the dev panel's MODULES
## ONLINE row sets.
func _power_modules(count: int) -> void:
	_gs.powered_gates.clear()
	for i in count:
		_gs.mark_gate_powered("Sun/Module%d/Gate" % i)


func _records_tab() -> RecordsTab:
	var tab := auto_free(RecordsTab.new()) as RecordsTab
	add_child(tab)
	tab.refresh()
	return tab


## Every Label's text under `node`, in tree order — what the player can actually read,
## so a hidden section's heading does not count as being on screen.
func _text_of(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is CanvasItem and not (node as CanvasItem).visible:
		return out
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		out.append_array(_text_of(child))
	return out
