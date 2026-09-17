extends Resource
class_name StoreData

## Configuration resource for a store instance.
## Defines what upgrades are available and which services are offered.

@export var store_name: String = ""
## Optional display name for the store (e.g., "Orbital Supply Depot")

@export var upgrades: Array[UpgradeItem] = []
## Array of UpgradeItem resources available in this store

@export var can_repair: bool = false
## Whether this store offers hull repair services

@export var npc_data: NPCData = null
## NPC character data for this store
