extends Node
class_name Store

## Store component that can be attached to any entity.
## Handles buying upgrades. (The hold is cashed in automatically on docking.)

signal purchase_completed(upgrade: UpgradeItem)

@export var store_data: StoreData = null
## The store configuration resource

var _game_state: GameState = null
var _ship: Ship = null


func _ready() -> void:
	add_to_group("stores")
	_cache_references()


func _cache_references() -> void:
	_game_state = get_tree().get_first_node_in_group("game_state") as GameState
	_ship = get_tree().get_first_node_in_group("ship") as Ship


## Get the store's display name.
## Returns an empty string if no name is set.
func get_store_name() -> String:
	if store_data:
		return store_data.store_name
	return ""


## Get all upgrades available in this store.
func get_all_upgrades() -> Array[UpgradeItem]:
	if store_data:
		return store_data.upgrades
	return []


## Get upgrades that the player can currently purchase (has prerequisites).
func get_available_upgrades() -> Array[UpgradeItem]:
	var available: Array[UpgradeItem] = []
	if not store_data or not _game_state:
		return available
	
	for upgrade in store_data.upgrades:
		if upgrade.can_purchase(_game_state):
			available.append(upgrade)
	
	return available


## Check if a specific upgrade can be purchased.
## Checks both tier requirements and credit balance.
func can_purchase(upgrade: UpgradeItem) -> bool:
	if not upgrade or not _game_state:
		return false
	
	# Check tier requirement
	if not upgrade.can_purchase(_game_state):
		return false
	
	# Check credits
	if _game_state.credits < upgrade.cost:
		return false
	
	return true


## Get the reason why an upgrade cannot be purchased.
## Returns empty string if it can be purchased.
func get_purchase_block_reason(upgrade: UpgradeItem) -> String:
	if not upgrade or not _game_state:
		return "Invalid upgrade"
	
	# Check tier requirement
	if not upgrade.can_purchase(_game_state):
		var required_tier = upgrade.tier - 1
		if required_tier > 0:
			return "Requires %s tier %d" % [upgrade.upgrade_path.capitalize(), required_tier]
		return "Already owned or unavailable"
	
	# Check credits
	if _game_state.credits < upgrade.cost:
		return "Insufficient credits"
	
	return ""


## Purchase an upgrade.
## Returns true if successful, false otherwise.
func purchase_upgrade(upgrade: UpgradeItem) -> bool:
	if not can_purchase(upgrade):
		return false
	
	# Refresh ship reference in case it respawned
	_ship = get_tree().get_first_node_in_group("ship") as Ship
	
	# Deduct credits
	_game_state.credits -= upgrade.cost
	
	# Apply the upgrade
	upgrade.apply(_ship, _game_state)
	
	# Auto-save after purchase (use refreshed ship reference)
	if _game_state and _ship:
		# Show saving indicator
		var hud = get_tree().get_first_node_in_group("hud") as Control
		if hud and hud.has_method("show_saving_indicator"):
			hud.show_saving_indicator()
		
		Save.save(_game_state, _ship)
		
		# Hide saving indicator after a brief delay
		if hud and hud.has_method("hide_saving_indicator"):
			await get_tree().create_timer(0.5).timeout
			hud.hide_saving_indicator()
	
	purchase_completed.emit(upgrade)
	return true
