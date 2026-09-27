extends Node
class_name GameState

## Global singleton holding persistent player progression: credits, upgrade levels,
## death count, Visited and scanned Bodies, dug-out ore seams and the Automatons the
## player has met. Populated by Save.load() at game start; serialized by Save.save()
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

## Bodies the ship has flown into the inner orbit of, keyed by Planet.save_key(). A
## Visited Body holds a Record in the Log whether or not it has ever been surveyed;
## scanning fills that Record in (docs/adr/0003). Permanent, and in visit order.
var visited_planets: Dictionary = {}

## Dug-out ore seams: OreDeposit.ore_id() -> seconds of play left until they refill.
var spent_ore: Dictionary = {}

## Gates the player has powered, keyed by the planet's Planet.save_key(). One powered
## Gate is one Module online, and a Module never goes back offline. Permanent.
var powered_gates: Dictionary = {}

## Gates the Guide has named, keyed by the planet's Planet.save_key(). A Gate reads as
## `? ? ?` on the minimap until the player flies close enough to be told what it is
## (docs/GLOSSARY.md, Unidentified). Permanent.
var identified_gates: Dictionary = {}

## Automatons the player has met, keyed by NPCData.record_key() (e.g. "UNIT-7"). Meeting
## one earns its Record in the Log, and the Log only ever gains Records. Permanent.
var met_automatons: Dictionary = {}

## Sections of SR-7 seated back in their Mounts, keyed by Sections id. Permanent.
var seated_sections: Dictionary = {}

## SR-7's core has been cold-started (docs/OPENING.md §5): the station has power, UNIT-7
## is awake, and SR-7's dock is crewed again. The world fact, not the radio's. Permanent -
## a station does not go back to being dead.
var core_started: bool = false

## Death counter - tracks total number of deaths (not displayed to player)
var death_count: int = 0

## Tracks the player's current upgrade level for each upgrade path.
## Keys are path names (e.g., "hull", "fuel_tank"), values are tier levels (0 = base, 1+ = upgraded)
var upgrade_levels: Dictionary = {}

func _ready() -> void:
	add_to_group("game_state")

func _process(delta: float) -> void:
	# Seams refill on play time: the tree is paused in menus
	tick_ore_regrowth(delta)

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

func is_planet_visited(key: String) -> bool:
	return visited_planets.has(key)

func mark_planet_visited(key: String) -> void:
	visited_planets[key] = true

func is_gate_powered(key: String) -> bool:
	return powered_gates.has(key)

func mark_gate_powered(key: String) -> void:
	powered_gates[key] = true

## True once the player has met this Automaton, so they hold its Record.
func has_met_automaton(designation: String) -> bool:
	return met_automatons.has(designation)

func mark_automaton_met(designation: String) -> void:
	met_automatons[designation] = true

func is_section_seated(id: String) -> bool:
	return seated_sections.has(id)

func mark_section_seated(id: String) -> void:
	seated_sections[id] = true

## Every piece of SR-7 that has to go home for the station to be whole: the three Sections
## that come back as Freight, and the right solar wing that is nudged back (Sections).
static func station_pieces() -> Array:
	return Sections.DATA.keys() + [Sections.SOLAR_ARRAY_2]

## Whether every piece of SR-7 is home. The core only listens once it is (CoreHousing), so
## a running core means the station is whole - see `mark_station_whole`.
func station_whole() -> bool:
	for id in station_pieces():
		if not is_section_seated(id):
			return false
	return true

## Every piece home at once.
func mark_station_whole() -> void:
	for id in station_pieces():
		mark_section_seated(id)

## SR-7's restoration as a save holds it: which pieces are home, and whether the core is
## running. The core does not listen until the station is whole (CoreHousing.listens), so a
## save that kept the cold start and lost the seated list - one written before a new game
## owned its save file from its first frame - comes back whole and lit, never lit with its
## Sections still floating outside it.
func restore_station(seated: PackedStringArray, started: bool) -> void:
	seated_sections.clear()
	for id in seated:
		mark_section_seated(id)
	core_started = started
	if core_started and not station_whole():
		mark_station_whole()

func is_gate_identified(key: String) -> bool:
	return identified_gates.has(key)

func mark_gate_identified(key: String) -> void:
	identified_gates[key] = true

## How awake the Titan is, 0 to 5: one step per Module online. Every "wrongness"
## effect reads from this. (The Core in the sun is a separate final state, not step 6.)
func titan_influence() -> int:
	return powered_gates.size()

func spend_ore(ore_id: String, regrow_seconds: float) -> void:
	spent_ore[ore_id] = regrow_seconds

## Seconds until a spent ore seam refills (0 when it can be harvested).
func ore_regrow_left(ore_id: String) -> float:
	return spent_ore.get(ore_id, 0.0)

func tick_ore_regrowth(delta: float) -> void:
	for ore_id in spent_ore.keys():
		var left: float = spent_ore[ore_id] - delta
		if left <= 0.0:
			spent_ore.erase(ore_id)
		else:
			spent_ore[ore_id] = left

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
	visited_planets.clear()
	spent_ore.clear()
	powered_gates.clear()
	identified_gates.clear()
	met_automatons.clear()
	seated_sections.clear()
	core_started = false
	death_count = 0
	upgrade_levels.clear()
	InventoryManager.clear_inventory()

	# Emit signals for any listeners
	credits_changed.emit()
	for path in upgrade_paths:
		upgrade_level_changed.emit(path, 0)
