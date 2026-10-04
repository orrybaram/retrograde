extends Node
class_name GameState

## Global singleton holding persistent player progression: Stores, death count, dug-out
## ore seams, SR-7's Cradle and the Progress ledger (every Record the player has earned).
## Populated by Save.load() at game start; serialized by Save.save() on dock/game-over.
## Emits stores_changed. There are no upgrades to track: the ship's limits are fixed until
## a found Component is fitted (docs/adr/0007).

signal stores_changed

var stores: int = 0 :
	set(value):
		stores = value
		stores_changed.emit()

## Bodies that have been surveyed, keyed by Planet.save_key(). Nothing surveys a Body
## now: the planetary scan is gone and `ECHO` is not designed yet (docs/IDEAS.md §13), so
## this stays empty in play and is not saved. A survey fills in a Record and surfaces the
## Body's ore seams, which stay dormant until then.
var scanned_planets: Dictionary = {}

## Dug-out ore seams: OreDeposit.ore_id() -> seconds of play left until they refill.
var spent_ore: Dictionary = {}

## The Progress ledger: the facts the player has earned (Visited Bodies, named Gates and
## wrecks, met Automatons, powered Gates, seated Sections, fitted Components, SR-7's cold
## start), written through to its store as they are marked. In memory until Main points it
## at the save file, so a GameState made anywhere else never touches the player's save.
var progress := Progress.new()

## The Components let go of into SR-7's Cradle and waiting there to be fitted (Components
## ids, oldest first). The Cradle is always open, so any number can wait. Each is permanent
## until it is fitted, and one taken off the ship comes back here (docs/adr/0014).
var cradled := PackedStringArray()

## Death counter - tracks total number of deaths (not displayed to player)
var death_count: int = 0

func _ready() -> void:
	add_to_group("game_state")

func _process(delta: float) -> void:
	# Seams refill on play time: the tree is paused in menus
	tick_ore_regrowth(delta)

func is_planet_scanned(key: String) -> bool:
	return scanned_planets.has(key)

func mark_planet_scanned(key: String) -> void:
	scanned_planets[key] = true

## Every piece of SR-7 that has to go home for the station to be whole: the three Sections
## that come back as Freight, and the right solar wing that is nudged back (Sections).
static func station_pieces() -> Array:
	return Sections.DATA.keys() + [Sections.SOLAR_ARRAY_2]

## Whether every piece of SR-7 is home. The core only listens once it is (CoreHousing), so
## a running core means the station is whole - see `repair_station`.
func station_whole() -> bool:
	for id in station_pieces():
		if not progress.holds(Progress.SEATED_SECTIONS, id):
			return false
	return true

## Every piece home at once.
func mark_station_whole() -> void:
	for id in station_pieces():
		progress.mark(Progress.SEATED_SECTIONS, id)

## The core does not listen until the station is whole (CoreHousing.listens), so a save
## that kept the cold start and lost the seated list - one written before a new game owned
## its save file from its first frame - comes back whole and lit, never lit with its
## Sections still floating outside it. Runs on a continue, once the ledger is resumed.
func repair_station() -> void:
	if progress.flagged(Progress.CORE_STARTED) and not station_whole():
		mark_station_whole()

## How awake the Titan is, 0 to 5: one step per Module online. Every "wrongness"
## effect reads from this. (The Core in the sun is a separate final state, not step 6.)
func titan_influence() -> int:
	return progress.count(Progress.POWERED_GATES)

## The Components on the ship now: every one ever fitted, less any taken off again. The
## ledger only gains (FITTED_COMPONENTS is "has been fitted"), so taking one off puts it
## back in `cradled` instead of unmarking it; each Component is one of a kind, so one
## waiting in the Cradle is not on the ship. The save format is unchanged.
func fitted() -> PackedStringArray:
	var on := PackedStringArray()
	for id in progress.list(Progress.FITTED_COMPONENTS):
		if not id in cradled:
			on.append(id)
	return on

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
## This clears Stores, inventory, and all other persistent state.
func reset_all_state() -> void:
	stores = 0
	scanned_planets.clear()
	spent_ore.clear()
	progress = progress.fresh()
	cradled.clear()
	death_count = 0
	InventoryManager.clear_inventory()

	# Emit signals for any listeners
	stores_changed.emit()
