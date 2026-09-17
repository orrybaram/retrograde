extends Node
class_name GameState

## Global singleton holding persistent player progression: credits, upgrade levels,
## death count, scanned planets and spent landing sites. Populated by Save.load() at game start; serialized by Save.save()
## on dock/game-over. Emits credits_changed and upgrade_level_changed signals.

signal credits_changed
signal upgrade_level_changed(path: String, level: int)

var credits: int = 0 :
	set(value):
		credits = value
		credits_changed.emit()

var has_drone_bay: bool = false
var has_planet_scanner: bool = false

## Planets the Planetary Scanner has mapped, keyed by Planet.save_key(). Permanent.
var scanned_planets: Dictionary = {}

## Dug-out landing sites: LandingSite.site_id() -> seconds of play left until they regrow.
var spent_sites: Dictionary = {}

## Death counter - tracks total number of deaths (not displayed to player)
var death_count: int = 0

## Tracks the player's current upgrade level for each upgrade path.
## Keys are path names (e.g., "hull", "fuel_tank"), values are tier levels (0 = base, 1+ = upgraded)
var upgrade_levels: Dictionary = {}

func _ready() -> void:
	add_to_group("game_state")

func _process(delta: float) -> void:
	# Sites regrow on play time: the tree is paused in menus
	tick_site_regrowth(delta)

## Get the player's current upgrade level for a given path.
## Returns 0 (base state) if no upgrades have been purchased for this path.
func get_upgrade_level(path: String) -> int:
	return upgrade_levels.get(path, 0)

## Set the player's upgrade level for a given path.
## Called when an upgrade is purchased.
func set_upgrade_level(path: String, level: int) -> void:
	upgrade_levels[path] = level
	upgrade_level_changed.emit(path, level)

func is_planet_scanned(key: String) -> bool:
	return scanned_planets.has(key)

func mark_planet_scanned(key: String) -> void:
	scanned_planets[key] = true

func spend_site(site_id: String, regrow_seconds: float) -> void:
	spent_sites[site_id] = regrow_seconds

## Seconds until a spent site regrows (0 when it can be drilled).
func site_regrow_left(site_id: String) -> float:
	return spent_sites.get(site_id, 0.0)

func tick_site_regrowth(delta: float) -> void:
	for site_id in spent_sites.keys():
		var left: float = spent_sites[site_id] - delta
		if left <= 0.0:
			spent_sites.erase(site_id)
		else:
			spent_sites[site_id] = left

## Compatibility wrapper for clearing cargo.
## Now delegates to InventoryManager.clear_inventory()
func clear_cargo() -> void:
	InventoryManager.clear_inventory()

## Reset all game state to initial values for a new game.
## This clears credits, upgrades, inventory, and all other persistent state.
func reset_all_state() -> void:
	# Store upgrade paths before clearing to emit signals
	var upgrade_paths = upgrade_levels.keys()

	# Reset all state variables
	credits = 0
	has_drone_bay = false
	has_planet_scanner = false
	scanned_planets.clear()
	spent_sites.clear()
	death_count = 0
	upgrade_levels.clear()
	InventoryManager.clear_inventory()

	# Emit signals for any listeners
	credits_changed.emit()
	for path in upgrade_paths:
		upgrade_level_changed.emit(path, 0)
