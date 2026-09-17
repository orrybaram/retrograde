extends Node
## Singleton for the ship's hold: gem quantities keyed by item_id. An item's weight is
## the hold space it takes (see GemData). The hold is cashed in for credits on docking.

signal inventory_changed(item_id: String, new_quantity: int)
## Emitted when an item's quantity changes in the inventory.

signal cargo_weight_changed(total_weight: float)
## Emitted when the total cargo weight changes.

var _inventory: Dictionary = {}  # Maps item_id to quantity
var _item_weights: Dictionary = {}  # Cache of item_id to weight

func _ready() -> void:
	add_to_group("inventory_manager")
	for tier in GemData.TIERS:
		var id := GemData.item_id(tier)
		register_item_data(id, GemData.space_of(id))

## Register an item type's weight (hold space per unit).
func register_item_data(item_id: String, weight: float) -> void:
	_item_weights[item_id] = weight

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

## Credits the hold is worth right now.
func get_total_value() -> int:
	return GemData.hold_value(_inventory)

## Empty the hold and return its credit value (the caller banks it).
func cash_in() -> int:
	var value := get_total_value()
	clear_inventory()
	return value

## Get the remaining cargo capacity.
func get_remaining_capacity(max_cargo_weight: float) -> float:
	return max_cargo_weight - get_total_weight()
