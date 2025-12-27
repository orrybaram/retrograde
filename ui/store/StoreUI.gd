extends Control
class_name StoreUI

## Store UI for purchasing upgrades and selling resources.

signal dialogue_closed

@onready var title_label: Label = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var credits_label: Label = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/HeaderContainer/CreditsLabel
@onready var upgrades_container: VBoxContainer = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/ScrollContainer/UpgradesContainer
@onready var sell_button: Button = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/ActionsContainer/SellButton
@onready var close_button: Button = $CenterContainer/StoreWindow/MarginContainer/VBoxContainer/ActionsContainer/CloseButton

var store: Store = null
var gs: GameState = null

var _upgrade_buttons: Dictionary = {}  # UpgradeItem -> Button


func _ready() -> void:
	visible = false
	gs = get_tree().get_first_node_in_group("game_state") as GameState
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
	
	# Connect to credits changed signal for live updates
	if gs and gs.has_signal("credits_changed"):
		gs.credits_changed.connect(_update_display)
	if gs and gs.has_signal("upgrade_level_changed"):
		gs.upgrade_level_changed.connect(_on_upgrade_level_changed)


func open_dialogue(target_store: Store) -> void:
	store = target_store
	visible = true
	_build_upgrade_list()
	_update_display()
	

func close_dialogue() -> void:
	visible = false
	store = null
	_clear_upgrade_buttons()
	
	dialogue_closed.emit()


func _build_upgrade_list() -> void:
	_clear_upgrade_buttons()
	
	if not store:
		return
	
	var upgrades = store.get_all_upgrades()
	for upgrade in upgrades:
		_create_upgrade_button(upgrade)


func _create_upgrade_button(upgrade: UpgradeItem) -> void:
	var button = Button.new()
	button.name = "Upgrade_" + upgrade.upgrade_id
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade))
	
	upgrades_container.add_child(button)
	_upgrade_buttons[upgrade] = button
	
	_update_upgrade_button(upgrade, button)


func _update_upgrade_button(upgrade: UpgradeItem, button: Button) -> void:
	if not store or not gs:
		return
	
	var can_buy = store.can_purchase(upgrade)
	var block_reason = store.get_purchase_block_reason(upgrade)
	
	# Check if already owned (current tier >= this upgrade's tier)
	var current_tier = gs.get_upgrade_level(upgrade.upgrade_path)
	var already_owned = current_tier >= upgrade.tier
	
	if already_owned:
		button.text = "%s [OWNED]" % upgrade.display_name
		button.disabled = true
	elif can_buy:
		button.text = "%s (%d credits)" % [upgrade.display_name, upgrade.cost]
		button.disabled = false
	else:
		button.text = "%s (%d credits) [%s]" % [upgrade.display_name, upgrade.cost, block_reason]
		button.disabled = true


func _clear_upgrade_buttons() -> void:
	for button in _upgrade_buttons.values():
		if is_instance_valid(button):
			button.queue_free()
	_upgrade_buttons.clear()


func _update_display() -> void:
	if not store or not gs:
		return
	
	# Update title
	if title_label:
		var store_name = store.get_store_name()
		title_label.text = store_name if store_name else "STORE"
	
	# Update credits
	if credits_label:
		credits_label.text = "Credits: %d" % gs.credits
	
	# Update all upgrade buttons
	for upgrade in _upgrade_buttons.keys():
		var button = _upgrade_buttons[upgrade] as Button
		if is_instance_valid(button):
			_update_upgrade_button(upgrade, button)
	
	# Update sell button
	if sell_button:
		if store.can_sell_resources():
			var sell_value = store.get_sell_value()
			if sell_value > 0:
				sell_button.text = "Sell All Resources (+%d credits)" % sell_value
				sell_button.disabled = false
				sell_button.visible = true
			else:
				sell_button.text = "No Resources to Sell"
				sell_button.disabled = true
				sell_button.visible = true
		else:
			sell_button.visible = false


func _on_upgrade_pressed(upgrade: UpgradeItem) -> void:
	if store and store.purchase_upgrade(upgrade):
		_update_display()


func _on_sell_pressed() -> void:
	if store:
		store.sell_all_resources()
		_update_display()


func _on_close_pressed() -> void:
	close_dialogue()


func _on_upgrade_level_changed(_path: String, _level: int) -> void:
	_update_display()

