extends Control
class_name StoreUI

## Port store run by UNIT-7. The robot card sits on the left and does the talking;
## the right column lists services, talk topics or upgrades.
## Modes: Character (BUY/TALK/EXIT), Talk (topics), Buy (repair + next tier per upgrade path).
## UP/DOWN select, ENTER/SPACE confirm, ESC backs out. Built in code; the .tscn is just the root.

enum Mode { CHARACTER, TALK, BUY }

signal dialogue_closed

const WINDOW_SIZE := Vector2(880, 440)
const TEXT_SIZE := TerminalWindow.TEXT_SIZE
const SMALL_SIZE := TerminalWindow.SMALL_SIZE
const ROW_HEIGHT := 26.0
const PIPS_WIDTH := 48.0
const COST_WIDTH := 80.0
## Ship stat each upgrade target changes, and how to label it.
const STAT_LABELS := {
	"max_hull": "HULL",
	"max_fuel": "FUEL",
	"max_cargo_weight": "HOLD",
}

var store: Store = null
var gs: GameState = null
var _ship: Ship = null

var _mode: Mode = Mode.CHARACTER
var _menu_items: Array[Dictionary] = []
var _selected_index: int = 0

var _frame: TerminalWindow
var _card: RobotCard
var _section: Label
var _rows: VBoxContainer
var _detail: VBoxContainer
var _detail_effect: Label
var _detail_note: Label


func _ready() -> void:
	visible = false
	add_to_group("store_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	_ship = get_tree().get_first_node_in_group("ship") as Ship
	_build_ui()

	if gs:
		gs.credits_changed.connect(_on_credits_changed)
		gs.upgrade_level_changed.connect(_on_upgrade_level_changed)


# --- Layout ------------------------------------------------------------------

func _build_ui() -> void:
	_frame = TerminalWindow.new(WINDOW_SIZE, "/ S T O R E /", "")
	add_child(_frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_frame.body.add_child(row)
	_card = RobotCard.new("S H O P", "PORT QUARTERMASTER")
	row.add_child(_card)
	row.add_child(TerminalWindow.rule(true))

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)

	_section = TerminalWindow.header("")
	col.add_child(_section)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	col.add_child(_rows)
	col.add_child(TerminalWindow.filler())

	# Selected upgrade: what it changes and why it can't be bought
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	_detail.add_child(TerminalWindow.rule())
	_detail_effect = TerminalWindow.label("", TEXT_SIZE, Colors.TEXT)
	_detail.add_child(_detail_effect)
	_detail_note = TerminalWindow.label("", SMALL_SIZE, Colors.PRIMARY_DIM)
	_detail.add_child(_detail_note)
	col.add_child(_detail)


## One selectable row: `> LABEL ..... [pips] right-text`, highlighted when selected.
func _make_row(item: Dictionary, selected: bool) -> Control:
	var enabled: bool = item["enabled"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = ROW_HEIGHT
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TerminalWindow.box(Colors.PRIMARY_GHOST if selected else Color.TRANSPARENT, Colors.PRIMARY_DIM, 0)
	if selected:
		bg.border_width_left = 2
		bg.border_color = Colors.PRIMARY
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var text_color := Colors.PRIMARY if enabled else Colors.PRIMARY_DIM
	var caret := TerminalWindow.label(">" if selected else " ", TEXT_SIZE, Colors.PRIMARY)
	caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caret)
	var name_label := TerminalWindow.label(item["label"], TEXT_SIZE, text_color)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)
	row.add_child(TerminalWindow.spacer())

	if item.has("tier"):
		var pips := SegmentGauge.new()
		pips.custom_minimum_size.x = PIPS_WIDTH
		var max_tier: int = item["max_tier"]
		pips.set_fill(float(item["tier"]) / max_tier, Colors.PRIMARY, max_tier)
		row.add_child(pips)

	var right: String = item.get("right", "")
	if right != "":
		var right_label := TerminalWindow.label(right, TEXT_SIZE, item.get("right_color", text_color))
		right_label.custom_minimum_size.x = COST_WIDTH
		right_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right_label)
	return panel


# --- Input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return

	match Controls.menu_action(event):
		&"menu_up":
			_move_selection(-1)
			get_viewport().set_input_as_handled()
		&"menu_down":
			_move_selection(1)
			get_viewport().set_input_as_handled()
		&"menu_accept":
			_activate_selection()
			get_viewport().set_input_as_handled()
		&"menu_back":
			_on_escape()
			get_viewport().set_input_as_handled()
		_:
			if event.is_action_pressed(&"action"):
				_activate_selection()
				get_viewport().set_input_as_handled()


func _move_selection(direction: int) -> void:
	if _menu_items.is_empty():
		return
	# In BUY, disabled rows stay selectable so their descriptions can be read.
	var n := _menu_items.size()
	var index := _selected_index
	for attempt in n:
		index = (index + direction + n) % n
		if _mode == Mode.BUY or _menu_items[index]["enabled"]:
			_selected_index = index
			break
	_refresh_rows()


func _activate_selection() -> void:
	if _selected_index >= 0 and _selected_index < _menu_items.size():
		var item = _menu_items[_selected_index]
		if item["enabled"] and item["action"]:
			item["action"].call()
		elif _mode == Mode.BUY:
			_card.say(item.get("blocked", "Can't do that one yet, pilot."), &"worried")


func _on_escape() -> void:
	if _mode == Mode.CHARACTER:
		close_dialogue()
	else:
		_switch_to_character()


# --- Open / close ------------------------------------------------------------

func open_dialogue(target_store: Store) -> void:
	store = target_store
	_ship = get_tree().get_first_node_in_group("ship") as Ship
	_selected_index = 0
	visible = true
	if store and store.store_data:
		_frame.set_title(TerminalWindow.spaced_title(store.store_data.store_name))
	_card.set_status("OPEN", Colors.SUCCESS)
	_update_credits()
	_frame.animate_in()
	_card.robot.glitch_burst(0.3)
	_switch_to_character()


func close_dialogue() -> void:
	visible = false
	_card.hush()
	store = null
	dialogue_closed.emit()


func _get_npc() -> NPCData:
	if store and store.store_data and store.store_data.npc_data:
		return store.store_data.npc_data
	return null


## NPC text is written as "* line" bullets; the card wants a paragraph.
static func _as_speech(text: String) -> String:
	var lines := PackedStringArray()
	for line in text.split("\n", false):
		lines.append(line.strip_edges().trim_prefix("* ").trim_prefix("*"))
	return " ".join(lines)


func _update_credits() -> void:
	if gs:
		_card.set_credits(gs.credits)


# --- Modes -------------------------------------------------------------------

func _switch_to_character() -> void:
	_mode = Mode.CHARACTER
	_selected_index = 0
	_section.text = "S E R V I C E S"
	_frame.set_hint(Controls.menu_hint("CONFIRM", "LEAVE"))
	var npc := _get_npc()
	_card.say(_as_speech(npc.greeting) if npc else "Welcome aboard, pilot.", &"happy")

	_menu_items.clear()
	_menu_items.append({"enabled": true, "action": _switch_to_buy, "label": "BUY", "right": "UPGRADES"})
	_menu_items.append({
		"enabled": npc != null and npc.talk_topics.size() > 0,
		"action": _switch_to_talk,
		"label": "TALK",
		"right": "CHAT",
	})
	_menu_items.append({"enabled": true, "action": close_dialogue, "label": "EXIT", "right": "UNDOCK MENU"})
	_refresh_rows()


func _switch_to_talk() -> void:
	var npc := _get_npc()
	if not npc:
		_switch_to_character()
		return
	_mode = Mode.TALK
	_selected_index = 0
	_section.text = "T A L K"
	_frame.set_hint(Controls.menu_hint("ASK", "BACK"))
	_card.say("What's on your mind?", &"neutral")

	_menu_items.clear()
	for topic in npc.talk_topics:
		_menu_items.append({"enabled": true, "action": _on_topic_selected.bind(topic), "label": topic.to_upper()})
	_menu_items.append({"enabled": true, "action": _switch_to_character, "label": "BACK"})
	_refresh_rows()


func _switch_to_buy() -> void:
	_mode = Mode.BUY
	_selected_index = 0
	_section.text = "U P G R A D E S"
	_frame.set_hint(Controls.menu_hint("BUY", "BACK"))
	_rebuild_buy_items()


func _rebuild_buy_items() -> void:
	if not store:
		return
	_menu_items.clear()
	if store.store_data and store.store_data.can_repair:
		_menu_items.append(_repair_item())
	for entry in _get_next_upgrades():
		_menu_items.append(_upgrade_item(entry["upgrade"], entry["current"], entry["max_tier"]))
	_menu_items.append({"enabled": true, "action": _switch_to_character, "label": "BACK", "description": "Anything else, pilot?"})
	_selected_index = clampi(_selected_index, 0, _menu_items.size() - 1)
	_refresh_rows()


func _refresh_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for i in _menu_items.size():
		_rows.add_child(_make_row(_menu_items[i], i == _selected_index))

	var item: Dictionary = _menu_items[_selected_index] if not _menu_items.is_empty() else {}
	_detail.visible = _mode == Mode.BUY and (item.has("effect") or item.has("blocked"))
	_detail_effect.text = item.get("effect", "")
	_detail_effect.visible = _detail_effect.text != ""
	_detail_note.text = item.get("blocked", "")
	_detail_note.add_theme_color_override("font_color", item.get("blocked_color", Colors.PRIMARY_DIM))
	_detail_note.visible = _detail_note.text != ""
	if _mode == Mode.BUY and item.has("description"):
		_card.say(item["description"], &"neutral")


# --- Buy items ---------------------------------------------------------------

## Next tier per upgrade path (or the top tier if maxed), in store order.
func _get_next_upgrades() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var paths_seen: Dictionary = {}
	var upgrades := store.get_all_upgrades()
	for upgrade in upgrades:
		var path := upgrade.upgrade_path
		if path in paths_seen:
			continue
		paths_seen[path] = true
		var current := gs.get_upgrade_level(path) if gs else 0
		var max_tier := 0
		var next: UpgradeItem = null
		var top: UpgradeItem = null
		for u in upgrades:
			if u.upgrade_path != path:
				continue
			if u.tier > max_tier:
				max_tier = u.tier
				top = u
			if u.tier == current + 1:
				next = u
		var shown := next if current < max_tier else top
		if shown:
			result.append({"upgrade": shown, "current": current, "max_tier": max_tier})
	return result


func _repair_item() -> Dictionary:
	var cost := 0
	if _ship and is_instance_valid(_ship):
		cost = int((_ship.max_hull - _ship.hull_strength) * Economy.REPAIR_COST_PER_POINT)
	var item := {
		"action": _on_repair_pressed,
		"label": "REPAIR HULL",
		"description": "Patch the holes, seal the cracks. Good as new... mostly.",
	}
	if cost <= 0:
		item["enabled"] = false
		item["right"] = "FULL"
		item["blocked"] = "Hull is already at full strength."
		return item
	var affordable := gs != null and gs.credits >= cost
	item["enabled"] = affordable
	item["right"] = "%d CR" % cost
	item["effect"] = "HULL  %d -> %d" % [ceili(_ship.hull_strength), int(_ship.max_hull)]
	if not affordable:
		item["right_color"] = Colors.DANGER
		item["blocked"] = "Need %d more CR." % (cost - gs.credits)
		item["blocked_color"] = Colors.DANGER
	return item


func _upgrade_item(upgrade: UpgradeItem, current: int, max_tier: int) -> Dictionary:
	var maxed := current >= max_tier
	var item := {
		"enabled": not maxed and store.can_purchase(upgrade),
		"action": _on_upgrade_pressed.bind(upgrade),
		"label": _track_name(upgrade),
		"tier": current,
		"max_tier": max_tier,
		"description": upgrade.description,
	}
	if maxed:
		item["right"] = "MAX"
		item["blocked"] = "Fully upgraded."
		return item
	item["right"] = "%d CR" % upgrade.cost
	item["effect"] = "%s  %s" % [upgrade.display_name.to_upper(), _effect_text(upgrade)]
	var reason := store.get_purchase_block_reason(upgrade)
	if reason == "Insufficient credits" and gs:
		item["right_color"] = Colors.DANGER
		item["blocked"] = "Need %d more CR." % (upgrade.cost - gs.credits)
		item["blocked_color"] = Colors.DANGER
	elif reason != "":
		item["blocked"] = reason
	return item


## "Cargo Hold II" -> "CARGO HOLD"
func _track_name(upgrade: UpgradeItem) -> String:
	var words := upgrade.display_name.to_upper().split(" ")
	if words.size() > 1 and words[-1].lstrip("IVX") == "":
		words.remove_at(words.size() - 1)
	return " ".join(words)


## "+80  HOLD 80 -> 160" for stat upgrades on the current ship.
func _effect_text(upgrade: UpgradeItem) -> String:
	var stat: String = STAT_LABELS.get(upgrade.effect_target, "")
	if stat == "" or upgrade.effect_type != UpgradeItem.EffectType.ADD_STAT:
		return ""
	var text := "+%d" % int(upgrade.effect_value)
	if _ship and is_instance_valid(_ship) and upgrade.effect_target in _ship:
		var now := float(_ship.get(upgrade.effect_target))
		text += "   %s %d -> %d" % [stat, int(now), int(now + upgrade.effect_value)]
	else:
		text += " " + stat
	return text


# --- Actions -----------------------------------------------------------------

func _on_topic_selected(topic: String) -> void:
	_card.say("%s Hmm, good question. Ask me again another time." % topic, &"neutral")


func _on_repair_pressed() -> void:
	if not _ship or not is_instance_valid(_ship) or not gs:
		return
	var cost := int((_ship.max_hull - _ship.hull_strength) * Economy.REPAIR_COST_PER_POINT)
	if cost > 0 and gs.credits >= cost:
		gs.credits -= cost
		_ship.hull_strength = _ship.max_hull
		_rebuild_buy_items()
		_card.say("All patched up. Try not to hit anything.", &"happy")
		_card.robot.glitch_burst(0.2)


func _on_upgrade_pressed(upgrade: UpgradeItem) -> void:
	if not store:
		return
	var success := await store.purchase_upgrade(upgrade)
	if success and visible:
		_rebuild_buy_items()
		var line := upgrade.purchase_line
		if line == "":
			line = "%s installed. Good as new." % upgrade.display_name
		_card.say(line, &"happy")
		_card.robot.glitch_burst(0.2)


func _on_credits_changed() -> void:
	if visible:
		_update_credits()
		if _mode == Mode.BUY:
			_rebuild_buy_items()


func _on_upgrade_level_changed(_path: String, _level: int) -> void:
	if visible and _mode == Mode.BUY:
		_rebuild_buy_items()
