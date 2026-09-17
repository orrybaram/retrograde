extends GdUnitTestSuite

## Tests for the resource indicator info box.


func _lines(box: Control) -> Array:
	return box.get_node("Lines").get_children().map(func(l): return l.text)


func test_info_box_shows_spaced_title_and_lines() -> void:
	var box: Control = auto_free(IndicatorRenderer.create_info_box({
		"title": "Scrap",
		"lines": [{"text": "HP    [##########]", "color": Colors.TEXT}],
	}))
	assert_array(_lines(box)).contains_exactly(["S C R A P", "HP    [##########]"])


func test_info_box_grows_to_fit_content() -> void:
	var box: Control = IndicatorRenderer.create_info_box({
		"title": "Scrap",
		"lines": [{"text": "A VERY LONG LINE OF TERMINAL TEXT", "color": Colors.TEXT}],
	})
	add_child(box)
	await await_idle_frame()
	var label: Label = box.get_node("Lines").get_child(1)
	assert_float(box.size.x).is_greater_equal(label.get_minimum_size().x)
	box.queue_free()


func test_update_info_box_updates_text_and_removes_extra_lines() -> void:
	var box: Control = IndicatorRenderer.create_info_box({
		"title": "Scrap",
		"lines": [
			{"text": "HOLD FULL", "color": Colors.DANGER},
			{"text": "TIME  3.0s", "color": Colors.TEXT},
		],
	})
	add_child(box)
	await await_idle_frame()
	var tall := box.size.y
	IndicatorRenderer.update_info_box(box, {
		"title": "Scrap",
		"lines": [{"text": "TIME  1.5s", "color": Colors.TEXT}],
	})
	await await_idle_frame()
	await await_idle_frame()
	assert_array(_lines(box)).contains_exactly(["S C R A P", "TIME  1.5s"])
	assert_float(box.size.y).is_less(tall)
	box.queue_free()


func test_resource_target_without_node_has_no_info() -> void:
	assert_dict(ResourceIndicatorTarget.new(null).get_indicator_info()).is_empty()
