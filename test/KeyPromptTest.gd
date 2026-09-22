extends GdUnitTestSuite

## On-screen prompts read the word, then its key on the line below.

func _key(action: String) -> String:
	return InputUtils.get_action_key_name(action).to_upper()

func test_prompt_is_the_word_over_its_key() -> void:
	assert_str(EventBus.action_prompt("DOCK")).is_equal("DOCK\n[%s]" % _key("action"))

func test_inline_prompt_stays_on_one_line() -> void:
	assert_str(EventBus.inline_key_prompt("action", "SKIP")).is_equal("[%s] SKIP" % _key("action"))

func test_prompt_row_centres_each_key_under_its_word() -> void:
	var row := EventBus.prompt_row(["LIFT OFF\n[UP]", "TERMINAL\n[SPACE]"])
	var lines := row.split("\n")
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).is_equal("LIFT OFF   TERMINAL")
	assert_str(lines[1]).is_equal("  [UP]     [SPACE] ")

func test_prompt_row_rows_share_a_width() -> void:
	var lines := EventBus.prompt_row(["A\n[LONGKEY]", "WORD\n[K]"]).split("\n")
	assert_int(lines[0].length()).is_equal(lines[1].length())
