extends GdUnitTestSuite

## Tests for the boot terminal. The clone manifest line is a story beat, not filler
## (docs/DESIGN.md "The First 10 Minutes"), so it's pinned here against a tidy-up.

const SCENE := preload("res://ui/LoadingScreen.tscn")


func _screen() -> LoadingScreen:
	return auto_free(SCENE.instantiate()) as LoadingScreen


func test_boot_sequence_synchronizes_the_clone_manifest() -> void:
	assert_array(_screen()._boot_messages).contains(["Synchronizing clone manifest"])


func test_clone_manifest_hides_between_two_mundane_lines() -> void:
	var messages: Array[String] = _screen()._boot_messages
	var at := messages.find("Synchronizing clone manifest")
	# Never first and never last: it has to read as one more piece of technobabble.
	assert_int(at).is_greater(0)
	assert_int(at).is_less(messages.size() - 1)


func test_every_boot_line_is_padded_to_the_same_width() -> void:
	# The checklist is a grid: dots carry every check out to the same stamp column, and
	# the bar underneath is cut to match, so nothing ragged shows up on the boot screen.
	var screen := _screen()
	for message in screen._boot_messages:
		var row := LoadingScreen.row_text(message, "[ OK ]")
		assert_str(row).is_equal(row.to_upper())
		assert_int(row.length()).is_equal(LoadingScreen.ROW_WIDTH)
	assert_int(LoadingScreen.meter_text(0.38).length()).is_equal(LoadingScreen.ROW_WIDTH)


func test_the_checklist_runs_from_ghosted_to_stamped() -> void:
	var screen := _screen()
	add_child(screen)
	screen.show_loading()
	var last: String = screen._boot_messages[-1]
	assert_str(screen.terminal_label.text).contains(LoadingScreen.dotted(last))
	assert_str(screen.terminal_label.text).not_contains("[ OK ]")
	# Run the clock out: every check is stamped and the bar reads full.
	screen._elapsed = screen.duration
	screen._render()
	assert_str(screen.terminal_label.text).contains("[ OK ]")
	assert_str(LoadingScreen.meter_text(1.0)).contains("100%")


func test_the_frame_never_changes_size_while_it_animates() -> void:
	# Dots writing out, the cursor blinking and READY arriving must all stay inside the
	# same box: the frame is auto-sized and centred, so any growth walks it around.
	var screen := _screen()
	add_child(screen)
	screen.show_loading()
	var sizes := {}
	for step in 80:
		screen._elapsed = step * screen.duration / 60.0
		screen._render()
		sizes[screen._panel.get_combined_minimum_size()] = true
	assert_int(sizes.size()).is_equal(1)
