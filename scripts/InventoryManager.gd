extends Node
## Singleton responsible for managing player inventory.
## Replaces the cargo dictionary in GameState with a more advanced inventory system.

signal inventory_changed(item_id: String, new_quantity: int)
## Emitted when an item's quantity changes in the inventory.

signal cargo_weight_changed(total_weight: float)
## Emitted when the total cargo weight changes.

var _inventory: Dictionary = {}  # Maps item_id to quantity
var _item_registry: Dictionary = {}  # Maps item_id to Item scene path
var _item_weights: Dictionary = {}  # Cache of item_id to weight

func _ready() -> void:
	add_to_group("inventory_manager")
	# Register default items
	register_item("scrap", "res://entities/resources/items/ScrapItem.tscn")
	# Register all tier items (lightweight — no scene file needed)
	for tier in TierData.TIERS.keys():
		var tier_data = TierData.TIERS[tier]
		register_item_data(tier_data["item_id"], tier_data["weight"])

## Register an item type with the inventory system.
## item_id: Unique identifier for the item (e.g., "scrap")
## item_scene_path: Path to the Item scene file
func register_item(item_id: String, item_scene_path: String) -> void:
	_item_registry[item_id] = item_scene_path
	# Cache the item weight from the scene
	var scene = load(item_scene_path) as PackedScene
	if scene:
		var instance = scene.instantiate() as Item
		if instance:
			_item_weights[item_id] = instance.weight
			instance.queue_free()

## Register an item type with just weight data (no scene file required).
## Useful for items that don't need a visual representation (e.g., tiered resources).
func register_item_data(item_id: String, weight: float) -> void:
	_item_weights[item_id] = weight

## Get the PackedScene for an item by its item_id.
## Returns null if the item is not registered.
func get_item_scene(item_id: String) -> PackedScene:
	if not _item_registry.has(item_id):
		return null
	return load(_item_registry[item_id]) as PackedScene

## Add items to inventory.
## item_id: The unique identifier of the item
## amount: The quantity to add
func add_item(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	
	var current_quantity = _inventory.get(item_id, 0) as int
	var new_quantity = current_quantity + amount
	_inventory[item_id] = new_quantity
	inventory_changed.emit(item_id, new_quantity)
	cargo_weight_changed.emit(get_total_weight())

## Remove items from inventory.
## item_id: The unique identifier of the item
## amount: The quantity to remove
## Returns true if successful, false if insufficient quantity
func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	
	var current_quantity = _inventory.get(item_id, 0) as int
	if current_quantity < amount:
		return false
	
	var new_quantity = current_quantity - amount
	if new_quantity == 0:
		_inventory.erase(item_id)
	else:
		_inventory[item_id] = new_quantity
	
	inventory_changed.emit(item_id, new_quantity)
	cargo_weight_changed.emit(get_total_weight())
	return true

## Get the current quantity of an item in inventory.
## Returns 0 if the item is not in inventory.
func get_quantity(item_id: String) -> int:
	return _inventory.get(item_id, 0) as int

## Check if the player has a certain amount of an item.
## item_id: The unique identifier of the item
## amount: The minimum quantity required (default: 1)
## Returns true if the player has at least the required amount
func has_item(item_id: String, amount: int = 1) -> bool:
	return get_quantity(item_id) >= amount

## Clear all items from inventory.
func clear_inventory() -> void:
	var item_ids = _inventory.keys()
	_inventory.clear()
	# Emit signals for all cleared items
	for item_id in item_ids:
		inventory_changed.emit(item_id, 0)
	cargo_weight_changed.emit(0.0)

## Get all items in inventory as a dictionary.
## Returns a copy of the inventory dictionary.
func get_all_items() -> Dictionary:
	return _inventory.duplicate()

## Get the inventory dictionary directly (for save/load purposes).
## This returns the internal dictionary - use with caution.
func get_inventory_dict() -> Dictionary:
	return _inventory

## Set the inventory dictionary directly (for save/load purposes).
## This replaces the entire inventory - use with caution.
func set_inventory_dict(inventory: Dictionary) -> void:
	_inventory = inventory.duplicate()
	# Emit signals for all items
	for item_id in _inventory.keys():
		inventory_changed.emit(item_id, _inventory[item_id])
	cargo_weight_changed.emit(get_total_weight())

## Get the weight of a single item by its item_id.
## Returns the weight from cache, or 1.0 as default if not found.
func get_item_weight(item_id: String) -> float:
	return _item_weights.get(item_id, 1.0)

## Get the total weight of all items in inventory.
func get_total_weight() -> float:
	var total: float = 0.0
	for item_id in _inventory.keys():
		var quantity = _inventory[item_id] as int
		var weight = get_item_weight(item_id)
		total += quantity * weight
	return total

## Check if adding a certain amount of an item would exceed cargo capacity.
## Returns true if the items can be added, false if it would exceed capacity.
func can_add_item(item_id: String, amount: int, max_cargo_weight: float) -> bool:
	if amount <= 0:
		return true
	var item_weight = get_item_weight(item_id)
	var additional_weight = amount * item_weight
	var new_total = get_total_weight() + additional_weight
	return new_total <= max_cargo_weight

## Get the remaining cargo capacity.
func get_remaining_capacity(max_cargo_weight: float) -> float:
	return max_cargo_weight - get_total_weight()
