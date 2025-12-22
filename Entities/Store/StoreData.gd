extends Resource
class_name StoreData

## Configuration resource for a store instance.
## Defines what upgrades are available and whether resources can be sold.

@export var store_name: String = ""
## Optional display name for the store (e.g., "Orbital Supply Depot")

@export var upgrades: Array[UpgradeItem] = []
## Array of UpgradeItem resources available in this store

@export var can_sell_resources: bool = true
## Whether players can sell their resources at this store

