extends RefCounted
class_name Progress

## The Progress ledger: every fact the player has earned, by kind, each one written through
## to a Store the moment it is marked. Nothing goes backwards (CONTEXT.md): a fact, once
## marked, holds for the rest of the save, so there is no way to unmark one. A new game is
## a `fresh` ledger; a continue is `resumed` from the Store.
##
## GameState owns the ledger (`GameState.progress`). A bare ledger keeps its facts in
## memory; Main points the game's at the save file (`FileStore`).
##
## Adding a kind is one constant here, listed in KINDS.
##
## Ore regrowth and the Cradle are not kept here: a seam refills and a Component leaves the
## Cradle when it is fitted, and the ledger never takes anything back.

## Bodies the ship has flown into the inner orbit of, keyed by Planet.save_key(), in visit
## order. Each one holds a Record in the Log (docs/adr/0003).
const VISITED_BODIES := "visited_bodies"
## Gates the Guide has named, keyed by Gate.save_key(). A Gate reads as `? ? ?` on the
## minimap until then (docs/GLOSSARY.md, Unidentified).
const IDENTIFIED_GATES := "identified_gates"
## Wrecks UNIT-7 has named, keyed by HaulerWreck.save_key(). Unidentified until then, like
## a Gate.
const IDENTIFIED_WRECKS := "identified_wrecks"
## Automatons the player has met, keyed by NPCData.record_key() (e.g. "UNIT-7"). Meeting
## one earns its Record in the Log.
const MET_AUTOMATONS := "met_automatons"
## Gates the player has powered, keyed by Gate.save_key(). One powered Gate is one Module
## online, and a Module never goes back offline. Its `count` is the Titan Influence.
const POWERED_GATES := "powered_gates"
## Pieces of SR-7 seated back in their Mounts, keyed by Sections id.
const SEATED_SECTIONS := "seated_sections"
## Components fitted to the ship from the Cradle, keyed by Components id.
const FITTED_COMPONENTS := "fitted_components"
## SR-7's core has been cold-started (docs/OPENING.md §6): the station has power and
## UNIT-7 is awake. A single-key kind: `flag` it, and read it with `flagged`.
const CORE_STARTED := "core_started"

## Every kind the ledger keeps, in the order a Store reads and writes them.
const KINDS: Array[String] = [
	VISITED_BODIES, IDENTIFIED_GATES, IDENTIFIED_WRECKS, MET_AUTOMATONS, POWERED_GATES,
	SEATED_SECTIONS, FITTED_COMPONENTS, CORE_STARTED,
]

var _store: Store
## kind -> {key: true}, each in the order it was marked.
var _facts := {}


## An empty ledger, as a new game starts, writing through to `store` (memory if none).
func _init(store: Store = null) -> void:
	_store = store if store else MemoryStore.new()
	for kind in KINDS:
		_facts[kind] = {}


## A new game's ledger: empty, writing to the same Store as this one.
func fresh() -> Progress:
	return Progress.new(_store)


## A continue's ledger: everything this one's Store holds, writing back to it.
func resumed() -> Progress:
	var ledger := Progress.new(_store)
	var held := _store.read()
	for kind in KINDS:
		for key in held.get(kind, PackedStringArray()):
			ledger._facts[kind][key] = true
	return ledger


## Marks `key` as holding for `kind` and writes the kind through to the Store. Returns
## true when this call is what marked it; a fact already held is left as it is.
func mark(kind: String, key: String) -> bool:
	var facts: Dictionary = _facts[kind]
	if key == "" or facts.has(key):
		return false
	facts[key] = true
	_store.write(kind, list(kind))
	return true


func holds(kind: String, key: String) -> bool:
	return _facts[kind].has(key)


## Every key marked for `kind`, oldest first. A copy: changing it changes nothing here.
func list(kind: String) -> PackedStringArray:
	return PackedStringArray(_facts[kind].keys())


## How many keys `kind` holds, without copying them: the Titan Influence reads it often.
func count(kind: String) -> int:
	return _facts[kind].size()


## Marks a single-key kind (a fact with nothing to key it by, like CORE_STARTED): its one
## key is the kind's own name. Returns true when this call is what marked it.
func flag(kind: String) -> bool:
	return mark(kind, kind)


## Whether a single-key kind has been marked (`flag`).
func flagged(kind: String) -> bool:
	return holds(kind, kind)


## Where a ledger's facts are kept between sessions. `read` gives kind -> keys for every
## kind it holds; `write` replaces one kind's keys.
class Store extends RefCounted:
	func read() -> Dictionary:
		return {}

	func write(_kind: String, _keys: PackedStringArray) -> void:
		pass


## Keeps the facts in memory: a ledger for tests, and for anything that must never touch
## the player's save.
class MemoryStore extends Store:
	var _held := {}

	func read() -> Dictionary:
		return _held.duplicate(true)

	func write(kind: String, keys: PackedStringArray) -> void:
		_held[kind] = keys.duplicate()


## Keeps the facts in the save file at `path`, each kind where saves before the ledger
## already kept it, so an old save loads with its facts intact. Like the old
## per-kind writes, a write with no save yet does nothing: a facts-only file would enable
## CONTINUE, and the next full Save.save() writes the ledger (`put`).
class FileStore extends Store:
	## kind -> [section, key] in the save file, for the kinds saves kept before the ledger.
	## Any other kind is kept under [progress] by its own name.
	const WHERE := {
		VISITED_BODIES: ["visited", "planets"],
		IDENTIFIED_GATES: ["gates", "identified"],
		IDENTIFIED_WRECKS: ["finds", "identified_wrecks"],
		MET_AUTOMATONS: ["automatons", "met"],
		POWERED_GATES: ["gates", "powered"],
		SEATED_SECTIONS: ["sections", "seated"],
		FITTED_COMPONENTS: ["sections", "fitted"],
		CORE_STARTED: ["sections", "core_started"],
	}
	## Single-key kinds that saves before the ledger kept as a bool rather than a list.
	const BOOLS: Array[String] = [CORE_STARTED]

	## Writes `keys` for `kind` into `cfg`, for Save.save() to carry the ledger over.
	static func put(cfg: ConfigFile, kind: String, keys: PackedStringArray) -> void:
		var at := _where(kind)
		if kind in BOOLS:
			cfg.set_value(at[0], at[1], not keys.is_empty())
		else:
			cfg.set_value(at[0], at[1], keys)

	## The keys `cfg` holds for `kind`: none when it keeps nothing there (an older save).
	static func take(cfg: ConfigFile, kind: String) -> PackedStringArray:
		var at := _where(kind)
		var v: Variant = cfg.get_value(at[0], at[1], PackedStringArray())
		if kind in BOOLS:
			return PackedStringArray([kind]) if v is bool and v else PackedStringArray()
		if v is PackedStringArray or v is Array:
			return PackedStringArray(v)
		return PackedStringArray()

	static func _where(kind: String) -> Array:
		return WHERE.get(kind, ["progress", kind])

	var _path: String

	## `path` is the save file: Main hands it Playtest.save_path().
	func _init(path: String) -> void:
		_path = path

	func read() -> Dictionary:
		var cfg := ConfigFile.new()
		if cfg.load(_path) != OK:
			return {}
		var held := {}
		for kind in KINDS:
			held[kind] = take(cfg, kind)
		return held

	func write(kind: String, keys: PackedStringArray) -> void:
		var cfg := ConfigFile.new()
		if cfg.load(_path) != OK:
			return
		put(cfg, kind, keys)
		cfg.save(_path)
