extends Node2D
class_name SweepReadout

## What a Sweep reads off a thing (docs/SWEEP.md §10). Put one under anything that should tell
## the player about itself: when a ring of the ship's own reaches this node's position, the
## thing is read. Only what carries one can be read - it is deliberate, never everything.
## It draws nothing: it says what it read on EventBus.readout_swept, and the HUD's
## ContactLog types it out.
##
## How much it reads is the ring's strength: a tap reads tier 1, and every CHARGE_TIME held
## reads a tier more (tier_for). Tier 1 is what the player needs; the deeper tiers are detail
## and clues, so a player who never charges a Sweep misses nothing they need.
##
## The rows come from the owner (the parent) when it has `readout_rows(tier)` - live state,
## like a Mount's EMPTY or SEATED - otherwise from `rows`. A read is a fact in the ledger
## (Progress.SWEPT_READOUTS, by `key`), so whatever reading unlocks holds for the rest of the
## save: a Mount marks its Section on the minimap once it has been read.
##
## Only the ship's Sweep reads (`on_swept`); SR-7's dish pings through the same rings and
## reads nothing.
##
## Something that is part of the Titan is `undecipherable`, for now: it is read like anything
## else, but its heading, title and rows come back as glyph noise in the Titan's purple, the
## same noise every time, shaped like what it holds. The Log keeps none of it - nothing was
## learned.

const MAX_TIER := 3

## The ledger key, unique across the world. Under an owner with `save_key()` (a Gate: one
## scene, many in the world) it is a prefix instead: `gate:<save_key>`.
@export var key := ""
## What kind of thing it is, and which one: `MOUNT` / `FUEL TANK`.
@export var heading := ""
@export var title := ""
## The rows, for an owner with no `readout_rows(tier)`.
@export var rows: Array[ReadoutRow] = []
## Part of the Titan: read, but not one character of it can be made out.
@export var undecipherable := false

## The strength of the ring that last reached it: on_sonar_touched comes just before
## on_swept, from the same ring.
var _strength := 1.0


func _ready() -> void:
	add_to_group("sonar_listeners")
	add_to_group("sweep_readouts")


## The first SweepReadout under `owner_node`, or null.
static func on(owner_node: Node) -> SweepReadout:
	for child in owner_node.get_children():
		if child is SweepReadout:
			return child
	return null


## How deep a ring of `strength` reads: one tier per ordinary ring's worth, up to MAX_TIER.
static func tier_for(strength: float) -> int:
	return clampi(floori(strength), 1, MAX_TIER)


func sonar_point() -> Vector2:
	return global_position


func on_sonar_touched(strength: float) -> void:
	_strength = strength


func on_swept() -> void:
	read(_strength)


## Read it with a ring of `strength`: mark it in the ledger and say what was read. A read
## deeper than tier 1 is marked too, as `<key>#<tier>`, so the Log knows how far it got.
func read(strength: float) -> void:
	var tier := tier_for(strength)
	var gs := _game_state()
	var at := ledger_key()
	if gs and at != "":
		gs.progress.mark(Progress.SWEPT_READOUTS, at)
		for deeper in range(2, tier + 1):
			gs.progress.mark(Progress.SWEPT_READOUTS, depth_key(at, deeper))
	EventBus.readout_swept.emit(self, tier, shown_rows(tier))


## The key it is kept under in the ledger: `key`, or `key:<save_key>` under an owner that
## has one.
func ledger_key() -> String:
	var source := get_parent()
	if source and source.has_method("save_key"):
		var own: String = source.save_key()
		return "%s:%s" % [key, own] if own != "" else ""
	return key


## How a read `tier` deep is kept: `mount_fuel_tank#2`. Tier 1 is the key alone.
static func depth_key(at: String, tier: int) -> String:
	return at if tier <= 1 else "%s#%d" % [at, tier]


## Whether a Sweep has ever read it, in this save.
func is_read() -> bool:
	return depth_read() > 0


## The deepest tier a Sweep has read it to in this save, 0 if never.
func depth_read() -> int:
	var gs := _game_state()
	var at := ledger_key()
	if gs == null or at == "":
		return 0
	for tier in range(MAX_TIER, 0, -1):
		if gs.progress.holds(Progress.SWEPT_READOUTS, depth_key(at, tier)):
			return tier
	return 0


## What the player sees of the heading, the title and the rows: the thing itself, or its
## noise when it is undecipherable.
func shown_heading() -> String:
	return garble(heading, ledger_key() + "/h") if undecipherable else heading

func shown_title() -> String:
	return garble(title, ledger_key() + "/t") if undecipherable else title

func shown_rows(tier: int) -> Array[ReadoutRow]:
	var out := rows_for(tier)
	if not undecipherable:
		return out
	var noise: Array[ReadoutRow] = []
	for i in out.size():
		var row := out[i]
		var salt := "%s/%d" % [ledger_key(), i]
		noise.append(ReadoutRow.make(garble(row.label, salt + "l"), garble(row.value, salt + "v"), row.tier))
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


## The rows a read of `tier` shows: the owner's, or those of `rows` at that tier or under.
func rows_for(tier: int) -> Array[ReadoutRow]:
	var source := get_parent()
	if source and source.has_method("readout_rows"):
		return source.readout_rows(tier)
	var out: Array[ReadoutRow] = []
	for row in rows:
		if row.tier <= tier:
			out.append(row)
	return out


func _game_state() -> GameState:
	return get_tree().get_first_node_in_group("game_state") as GameState if is_inside_tree() else null
