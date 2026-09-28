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

## Gates the Guide has named, keyed by Gate.save_key(). A Gate reads as `? ? ?` on the
## minimap until then (docs/GLOSSARY.md, Unidentified).
const IDENTIFIED_GATES := "identified_gates"

## Every kind the ledger keeps, in the order a Store reads and writes them.
const KINDS: Array[String] = [IDENTIFIED_GATES]

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
		IDENTIFIED_GATES: ["gates", "identified"],
	}

	## Writes `keys` for `kind` into `cfg`, for Save.save() to carry the ledger over.
	static func put(cfg: ConfigFile, kind: String, keys: PackedStringArray) -> void:
		var at := _where(kind)
		cfg.set_value(at[0], at[1], keys)

	static func _where(kind: String) -> Array:
		return WHERE.get(kind, ["progress", kind])

	var _path: String

	## `path` is the save file: Playtest.save_path() in the game.
	func _init(path: String) -> void:
		_path = path

	func read() -> Dictionary:
		var cfg := ConfigFile.new()
		if cfg.load(_path) != OK:
			return {}
		var held := {}
		for kind in KINDS:
			var at := _where(kind)
			held[kind] = PackedStringArray(cfg.get_value(at[0], at[1], PackedStringArray()))
		return held

	func write(kind: String, keys: PackedStringArray) -> void:
		var cfg := ConfigFile.new()
		if cfg.load(_path) != OK:
			return
		put(cfg, kind, keys)
		cfg.save(_path)
