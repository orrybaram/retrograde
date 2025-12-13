extends Resource
class_name UpgradeItem

## A reusable resource defining an upgrade with cost, effect, and tier progression.
## Can be used in stores, inventory displays, tooltips, etc.

## Effect types for upgrades
enum EffectType {
	ADD_STAT,        ## Add a value to a stat (e.g., +5 max_hull)
	MULTIPLY_STAT,   ## Multiply a stat by a value (e.g., 1.25x max_fuel)
	UNLOCK_FEATURE   ## Unlock a boolean feature (e.g., has_drone_bay = true)
}

# === Identity ===

@export var upgrade_id: String = ""
## Unique identifier (e.g., "hull_1", "hull_2")

@export var display_name: String = ""
## Display name shown in UI

@export_multiline var description: String = ""
## Tooltip/details description

@export var icon: Texture2D = null
## Optional icon for UI display

# === Progression ===

@export var upgrade_path: String = ""
## The upgrade category (e.g., "hull", "fuel_tank", "drone_bay")

@export var tier: int = 1
## Tier level (1-5). Tier 0 = no upgrade (base state, not a resource)

# === Economics ===

@export var cost: int = 0
## Price in credits

# === Effect ===

@export var effect_type: EffectType = EffectType.ADD_STAT
## The type of effect this upgrade applies

@export var effect_target: String = ""
## What to affect (e.g., "max_fuel", "max_hull", "has_drone_bay")

@export var effect_value: float = 0.0
## The value to apply (additive, multiplicative, or 1.0 for unlock)


## Check if the player can purchase this upgrade based on tier progression.
## Returns true if player has the previous tier (tier - 1).
func can_purchase(game_state: GameState) -> bool:
	if not game_state:
		return false
	var current_tier = game_state.get_upgrade_level(upgrade_path)
	return current_tier == tier - 1


## Apply this upgrade's effect to the ship and/or game state.
## Also updates the player's upgrade level for this path.
func apply(ship: Ship, game_state: GameState) -> void:
	if not game_state:
		push_error("UpgradeItem.apply: game_state is null")
		return
	
	match effect_type:
		EffectType.ADD_STAT:
			_apply_add_stat(ship)
		EffectType.MULTIPLY_STAT:
			_apply_multiply_stat(ship)
		EffectType.UNLOCK_FEATURE:
			_apply_unlock_feature(game_state)
	
	# Update the player's upgrade level for this path
	game_state.set_upgrade_level(upgrade_path, tier)


func _apply_add_stat(ship: Ship) -> void:
	match effect_target:
		"max_hull":
			if ship:
				ship.max_hull += int(effect_value)
				ship.hull_strength = ship.max_hull  # Heal to new max
		"max_fuel":
			if ship:
				ship.max_fuel += effect_value
				ship.fuel = ship.max_fuel  # Refill to new max
		_:
			push_warning("UpgradeItem: Unknown ADD_STAT target: %s" % effect_target)


func _apply_multiply_stat(ship: Ship) -> void:
	match effect_target:
		"max_hull":
			if ship:
				ship.max_hull = int(ship.max_hull * effect_value)
				ship.hull_strength = ship.max_hull
		"max_fuel":
			if ship:
				ship.max_fuel *= effect_value
				ship.fuel = ship.max_fuel
		_:
			push_warning("UpgradeItem: Unknown MULTIPLY_STAT target: %s" % effect_target)


func _apply_unlock_feature(game_state: GameState) -> void:
	match effect_target:
		"has_drone_bay":
			game_state.has_drone_bay = true
		_:
			push_warning("UpgradeItem: Unknown UNLOCK_FEATURE target: %s" % effect_target)

