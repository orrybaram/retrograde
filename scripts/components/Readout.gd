extends Node2D
class_name Readout

## What a thing tells the player about itself once the ship is close. Put
## one under anything that should: when the ship comes within `reach` of this node's position,
## the thing is read, every row at once. Only what carries one is read - it is deliberate,
## never everything. It draws nothing: it says what it read on EventBus.readout_read, and the
## HUD's ContactLog types it out.
##
## Something `discoverable` (scrap) passes unread until it has been found - the owner's
## `is_found()`, a Sweep's doing - and reads up close like anything else after. Finding is
## not reading: a Sweep from range shows no rows.
##
## One read an approach: it reads as the ship arrives, and again only once the ship has left
## (past `reach` + LEAVE_MARGIN) and come back. Of several in reach, only the one nearest the
## ship reads; the others wait their turn until they are nearest.
##
## Many things can share one `key` (every piece of scrap is `scrap`): the first read files
## the Log's Record, and a kind registered with `register_kind` is what that Record shows.
##
## The rows come from the owner (the parent) when it has `readout_rows()` - live state, like a
## Mount's EMPTY or SEATED - otherwise from `rows`. A read is a fact in the ledger
## (Progress.READ_READOUTS, by `key`), so whatever reading unlocks holds for the rest of the
## save: a Mount marks its Section on the minimap once it has been read.
##
## Something that is part of the Titan is `undecipherable`, for now: it is read like anything
## else, but its heading, title and rows come back as glyph noise in the Titan's purple, the
## same noise every time, shaped like what it holds. The Log keeps none of it - nothing was
## learned.

## How far past `reach` the ship has to go before coming back reads it again, so drifting on
## the edge does not read it over and over.
const LEAVE_MARGIN := 60.0

## The ledger key, unique across the world. Under an owner with `save_key()` (a Gate: one
## scene, many in the world) it is a prefix instead: `gate:<save_key>`.
@export var key := ""
## What kind of thing it is, and which one: `MOUNT` / `FUEL TANK`.
@export var heading := ""
@export var title := ""
## Where it is filed in the Log's Hardware section: the place it belongs to, `SR-7`. Things
## of one place are listed together under it; "" files it under no place.
@export var category := ""
## The rows, for an owner with no `readout_rows()`.
@export var rows: Array[ReadoutRow] = []
## Part of the Titan: read, but not one character of it can be made out.
@export var undecipherable := false
## How close the ship has to come for it to read, in px.
@export var reach := 260.0
## Unreadable until the owner says it has been found (`is_found()`).
@export var discoverable := false

## What the Log shows for a key many things share, by key: {heading, title, category, rows}.
static var _kinds := {}

## The ship has been read to on this approach and has not left since.
var _visited := false


func _ready() -> void:
	add_to_group("readouts")


## The first Readout under `owner_node`, or null.
static func on(owner_node: Node) -> Readout:
	for child in owner_node.get_children():
		if child is Readout:
			return child
	return null


func _physics_process(_dt: float) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null or ship.is_gone():
		return
	if not readable():
		_visited = false
		return
	var distance := global_position.distance_to(ship.global_position)
	if _visited:
		_visited = distance <= reach + LEAVE_MARGIN
	elif distance <= reach and nearest_in_reach(get_tree(), ship.global_position) == self:
		_visited = true
		read()


## The readout in reach of `at` nearest it, or null.
static func nearest_in_reach(tree: SceneTree, at: Vector2) -> Readout:
	var best: Readout = null
	var best_d := INF
	for node in tree.get_nodes_in_group("readouts"):
		var r := node as Readout
		if r == null or not r.readable():
			continue
		var d := at.distance_to(r.global_position)
		if d <= r.reach and d < best_d:
			best = r
			best_d = d
	return best


## Whether it can be read now: always, unless it is discoverable and not yet found.
func readable() -> bool:
	if not discoverable:
		return true
	var source := get_parent()
	return source != null and source.has_method("is_found") and source.is_found()


## Where the thing is, in world space, for whatever marks it on screen (ReadoutLock): the
## owner's `readout_bounds()`, else the polygons drawn under it, else a small square here.
func world_bounds() -> Rect2:
	var source := get_parent()
	if source and source.has_method("readout_bounds"):
		return source.readout_bounds()
	var out := Rect2()
	var any := false
	for node in _polygons(source if source else self):
		for point in node.polygon:
			var at: Vector2 = node.global_transform * (point + node.offset)
			out = out.expand(at) if any else Rect2(at, Vector2.ZERO)
			any = true
	return out if any else Rect2(global_position - Vector2(16, 16), Vector2(32, 32))


static func _polygons(root: Node) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	if root is Polygon2D and (root as Polygon2D).visible:
		out.append(root)
	for child in root.get_children():
		out.append_array(_polygons(child))
	return out


## Say what the Log's Record for `at` shows when many things share it, rather than whichever
## one happens to be in the world.
static func register_kind(at: String, kind_heading: String, kind_title: String, kind_category: String,
		kind_rows: Array[ReadoutRow]) -> void:
	_kinds[at] = {"heading": kind_heading, "title": kind_title, "category": kind_category, "rows": kind_rows}


## The registered kind for `at`, or an empty Dictionary.
static func kind(at: String) -> Dictionary:
	return _kinds.get(at, {})


## Read it: mark it in the ledger and say what was read.
func read() -> void:
	var gs := _game_state()
	var at := ledger_key()
	if gs and at != "":
		gs.progress.mark(Progress.READ_READOUTS, at)
	EventBus.readout_read.emit(self, shown_rows())


## The key it is kept under in the ledger: `key`, or `key:<save_key>` under an owner that
## has one.
func ledger_key() -> String:
	var source := get_parent()
	if source and source.has_method("save_key"):
		var own: String = source.save_key()
		return "%s:%s" % [key, own] if own != "" else ""
	return key


## Whether it has ever been read, in this save.
func is_read() -> bool:
	var gs := _game_state()
	var at := ledger_key()
	return gs != null and at != "" and gs.progress.holds(Progress.READ_READOUTS, at)


## What the player sees of the heading, the title and the rows: the thing itself, or its
## noise when it is undecipherable.
func shown_heading() -> String:
	return garble(heading, ledger_key() + "/h") if undecipherable else heading

func shown_title() -> String:
	return garble(title, ledger_key() + "/t") if undecipherable else title

func shown_rows() -> Array[ReadoutRow]:
	var out := rows_now()
	if not undecipherable:
		return out
	var noise: Array[ReadoutRow] = []
	for i in out.size():
		var row := out[i]
		var salt := "%s/%d" % [ledger_key(), i]
		noise.append(ReadoutRow.make(garble(row.label, salt + "l"), garble(row.value, salt + "v")))
	return noise


## `text` as glyph noise of the same shape (spaces kept), the same every time for `salt`.
## Its own generator: it never draws on RNG.rng.
static func garble(text: String, salt: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(salt)
	var glyphs := RobotFaces.GLITCH_CHARS
	var out := ""
	for c in text:
		out += c if c == " " else glyphs[rng.randi() % glyphs.length()]
	return out


## The rows as the thing stands now: the owner's, or `rows`.
func rows_now() -> Array[ReadoutRow]:
	var source := get_parent()
	if source and source.has_method("readout_rows"):
		return source.readout_rows()
	return rows.duplicate()


func _game_state() -> GameState:
	return get_tree().get_first_node_in_group("game_state") as GameState if is_inside_tree() else null
