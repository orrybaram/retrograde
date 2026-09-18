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
	var screen := _screen()
	add_child(screen)
	screen.show_loading()
	screen._add_terminal_line("Synchronizing clone manifest", 75)
	var text: String = screen.terminal_label.text
	assert_str(text).contains("Synchronizing clone manifest")
	assert_str(text).contains("[75%]")
