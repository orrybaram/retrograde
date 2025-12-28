extends Node
class_name Store

## Store component that can be attached to any entity.
## Handles buying upgrades and selling resources.

signal purchase_completed(upgrade: UpgradeItem)
signal resources_sold(total_value: int)

@export var store_data: StoreData = null
## The store configuration resource

var _game_state: GameState = null
var _ship: Ship = null
var _inventory_manager: InventoryManager = null


func _ready() -> void:
	add_to_group("stores")
	_cache_references()


func _cache_references() -> void:
	_game_state = get_tree().get_first_node_in_group("game_state") as GameState
	_ship = get_tree().get_first_node_in_group("ship") as Ship
	# InventoryManager is an autoload singleton
	_inventory_manager = get_node_or_null("/root/InventoryManager") as InventoryManager


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
	
	# Deduct credits
	_game_state.credits -= upgrade.cost
	
	# Apply the upgrade
	upgrade.apply(_ship, _game_state)
	
	# Auto-save after purchase
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


## Check if this store allows selling resources.
func can_sell_resources() -> bool:
	if store_data:
		return store_data.can_sell_resources
	return false


## Calculate the total value of all resources the player can sell.
func get_sell_value() -> int:
	if not _inventory_manager:
		_cache_references()
	if not _inventory_manager:
		return 0
	
	var total_value: int = 0
	var all_items = _inventory_manager.get_all_items()
	
	for item_id in all_items.keys():
		var quantity = all_items[item_id] as int
		var price = Economy.get_resource_price(item_id)
		total_value += quantity * price
	
	return total_value


## Sell all resources in the player's inventory.
## Returns the total credits earned.
func sell_all_resources() -> int:
	if not can_sell_resources():
		return 0
	
	if not _inventory_manager:
		_cache_references()
	if not _inventory_manager or not _game_state:
		return 0
	
	var total_value = get_sell_value()
	
	if total_value > 0:
		# Add credits
		_game_state.credits += total_value
		
		# Clear inventory
		_inventory_manager.clear_inventory()
		
		resources_sold.emit(total_value)
	
	return total_value

