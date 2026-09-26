extends GdUnitTestSuite

## The Controls autoload: defaults in the InputMap, rebinding with swaps, what can't be
## rebound, saving, device-aware labels and the menu actions menus read.

const SAVE_FILE := "user://controls_test.cfg"


func before_test() -> void:
	DirAccess.remove_absolute(SAVE_FILE)
	Controls.use_save_path(SAVE_FILE)
	Controls.using_pad = false


func after_test() -> void:
	DirAccess.remove_absolute(SAVE_FILE)
	Controls.use_save_path(Controls.DEFAULT_SAVE_PATH)
	Controls.using_pad = false


func _key_event(code: Key, physical := true) -> InputEventKey:
	var ev := InputEventKey.new()
	if physical:
		ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	return ev


func _pad_button(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func test_every_action_is_registered_with_its_defaults() -> void:
	for a in Controls.ACTIONS:
		assert_bool(InputMap.has_action(a["id"])).is_true()
	assert_bool(_key_event(KEY_W).is_action("thrust")).is_true()
	assert_bool(_key_event(KEY_UP).is_action("thrust")).is_true()
	assert_bool(_pad_button(JOY_BUTTON_A).is_action("action")).is_true()


func test_labels_follow_the_device_in_use() -> void:
	assert_str(Controls.label(&"action")).is_equal("SPACE")
	assert_str(Controls.label(&"menu_back")).is_equal("ESC")
	Controls.using_pad = true
	assert_str(Controls.label(&"action")).is_equal("A")
	assert_str(Controls.label(&"thrust")).is_equal("RT")
	assert_str(Controls.nav_label()).is_equal("D-PAD")


func test_rebinding_moves_the_input() -> void:
	var result := Controls.rebind(&"boost", Controls.Kind.KEY, 0, Controls.capture(_key_event(KEY_B), Controls.Kind.KEY))
	assert_bool(result["ok"]).is_true()
	assert_bool(_key_event(KEY_B).is_action("boost")).is_true()
	assert_bool(_key_event(KEY_SHIFT).is_action("boost")).is_false()
	assert_str(Controls.label(&"boost")).is_equal("B")


## An input already on another action live at the same time swaps: that action takes
## this slot's old input, so nothing is ever left bound twice.
func test_a_clash_swaps_the_inputs() -> void:
	var result := Controls.rebind(&"boost", Controls.Kind.KEY, 0, Controls.key(KEY_Q))
	assert_bool(result["ok"]).is_true()
	assert_str(String(result["swapped"])).is_equal("strafe_left")
	assert_bool(_key_event(KEY_Q).is_action("boost")).is_true()
	assert_bool(_key_event(KEY_Q).is_action("strafe_left")).is_false()
	assert_bool(_key_event(KEY_SHIFT).is_action("strafe_left")).is_true()


## Flight and the menus are never live together, so W can pan the chart and thrust.
func test_actions_on_different_screens_may_share() -> void:
	var result := Controls.rebind(&"chart_center", Controls.Kind.KEY, 0, Controls.key(KEY_SPACE))
	assert_str(String(result["swapped"])).is_equal("")
	assert_bool(_key_event(KEY_SPACE).is_action("action")).is_true()
	assert_bool(_key_event(KEY_SPACE).is_action("chart_center")).is_true()


func test_fixed_actions_cannot_be_rebound_or_taken() -> void:
	assert_bool(Controls.rebind(&"menu_accept", Controls.Kind.KEY, 0, Controls.key(KEY_P))["ok"]).is_false()
	# CLEAR is fixed in the menus, so the chart can't take DELETE from it.
	var result := Controls.rebind(&"chart_center", Controls.Kind.KEY, 0, Controls.named_key(KEY_DELETE))
	assert_bool(result["ok"]).is_false()
	assert_str(String(result["blocked"])).is_equal("menu_clear")


func test_escape_and_start_are_reserved_for_cancel() -> void:
	assert_object(Controls.capture(_key_event(KEY_ESCAPE, false), Controls.Kind.KEY)).is_null()
	assert_object(Controls.capture(_pad_button(JOY_BUTTON_START), Controls.Kind.PAD)).is_null()
	assert_bool(Controls.cancels_capture(_key_event(KEY_ESCAPE, false))).is_true()
	# The wrong device for the column is ignored rather than bound.
	assert_object(Controls.capture(_pad_button(JOY_BUTTON_A), Controls.Kind.KEY)).is_null()


func test_a_stick_binds_with_its_direction() -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_RIGHT_Y
	ev.axis_value = -0.9
	var binding := Controls.capture(ev, Controls.Kind.PAD)
	assert_str(Controls.event_label(binding)).is_equal("RS UP")
	ev.axis_value = 0.3
	assert_object(Controls.capture(ev, Controls.Kind.PAD)).is_null()


func test_rebinds_survive_a_reload_and_reset_restores_defaults() -> void:
	Controls.rebind(&"thrust", Controls.Kind.PAD, 1, Controls.button(JOY_BUTTON_X))
	Controls.clear_binding(&"thrust", Controls.Kind.KEY, 1)
	Controls.use_save_path(SAVE_FILE)
	assert_str(Controls.event_label(Controls.event_at(&"thrust", Controls.Kind.PAD, 1))).is_equal("X")
	assert_object(Controls.event_at(&"thrust", Controls.Kind.KEY, 1)).is_null()
	assert_bool(_key_event(KEY_W).is_action("thrust")).is_false()

	Controls.reset_to_defaults()
	assert_bool(_key_event(KEY_W).is_action("thrust")).is_true()


func test_menus_read_keys_and_pad_alike() -> void:
	assert_str(String(Controls.menu_action(_key_event(KEY_DOWN, false)))).is_equal("menu_down")
	assert_str(String(Controls.menu_action(_pad_button(JOY_BUTTON_DPAD_DOWN)))).is_equal("menu_down")
	assert_str(String(Controls.menu_action(_pad_button(JOY_BUTTON_B)))).is_equal("menu_back")
	# ESC is PAUSE too, but to a menu it is BACK.
	assert_str(String(Controls.menu_action(_key_event(KEY_ESCAPE, false)))).is_equal("menu_back")
	var tab := _key_event(KEY_TAB, false)
	assert_str(String(Controls.menu_action(tab))).is_equal("menu_tab_next")
	tab.shift_pressed = true
	assert_str(String(Controls.menu_action(tab))).is_equal("menu_tab_prev")


func test_the_screen_rebinds_through_capture() -> void:
	var ui: ControlsUI = auto_free(ControlsUI.new())
	add_child(ui)
	ui.open()
	# First row is THRUST, first column its main key.
	ui._input(_key_event(KEY_ENTER, false))
	assert_bool(ui.is_capturing()).is_true()
	ui._input(_key_event(KEY_K))
	assert_bool(ui.is_capturing()).is_false()
	assert_bool(_key_event(KEY_K).is_action("thrust")).is_true()
	assert_str(ui._status.text).contains("THRUST NOW ON K")
