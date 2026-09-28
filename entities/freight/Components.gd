class_name Components

## The Components that turn up as Freight (docs/OPENING.md §9, docs/adr/0007): each one's
## name, shape, Lug and mass, and how it lies in the world until it is found. A Component
## is ordinary Freight with a `component` id; it is delivered to SR-7's Cradle, not to a
## Mount, and fitted there from SHIP.
##
## Like a Section, each outline is laid along its own x axis with the Lug on one end.
##
## Fitted, a Component is part of the ship (docs/adr/0014): drawn on the hull, solid and
## heavy, in its one `place`. Its `fitted` form is cut down from the Freight one and laid
## out in the ship's own space (nose +x); it never reaches aft of the hull's tail (x -13),
## or the docked ship sits in SR-7's port pad.

const CARGO_BAY := "cargo_bay"

const DATA := {
	# The first Component: a hauler's hold, buried Lug-up in the wreck on Veld (HaulerWreck).
	# A squat box, heavier than anything of SR-7's - the ship crawls with it - but the Aux
	# still lifts it off Veld. It holds in the ground harder than the Aux can pull: only the
	# Burn tears it free, and the tear-out (`pull_time` s of Burn, playtests/cargo_bay.play)
	# costs about a fifth of a full tank, so the half SR-7 gives covers it (§9).
	# It is dead to the Sweep until SR-7's cold start, and after that it answers from far
	# past a ring's reach, faint at the edge of `answer_range` and firming up closer
	# (Freight.answer_clarity).
	CARGO_BAY: {
		"label": "CARGO BAY",
		"mass": 4.0,
		"art": "bay",
		"outline": [
			Vector2(-58, -30), Vector2(50, -30), Vector2(58, -22), Vector2(58, 22),
			Vector2(50, 30), Vector2(-58, 30),
		],
		"lug_position": Vector2(-58, 0),
		"lug_facing": Vector2.LEFT,
		"pull_threshold": 1.6,
		"pull_time": 4.25,
		"answer_range": 5000.0,
		"needs_power": true,
		# Fitted, it is the ship's hold: 50 units of gems (Ship.refit).
		"hold": 50.0,
		# A container strapped across the spine behind the cockpit, wider than the hull so
		# it reads from above. UNIT-7 cuts the hold out of the hauler's frame.
		"place": "spine",
		"fitted": {
			"outline": [Vector2(-13, -11), Vector2(-1, -11), Vector2(-1, 11), Vector2(-13, 11)],
			# Added to the ship's own mass (3.0): turning keeps about 93%, and SHIP's
			# handling bar loses one segment of eight (Ship.handling).
			"mass": 0.35,
			# Strap bands across it, drawn lighter.
			"bands": [Rect2(-13, -4, 12, 1), Rect2(-13, 3, 12, 1)],
		},
	},
}

static func exists(id: String) -> bool:
	return DATA.has(id)

## Make `f` into Component `id`. Call before it enters the tree (its shape is built then).
static func apply(f: Freight, id: String) -> void:
	if not DATA.has(id):
		return
	var d: Dictionary = DATA[id]
	f.component = id
	f.label = d["label"]
	f.mass = d["mass"]
	f.outline = PackedVector2Array(d["outline"])
	f.lug_position = d["lug_position"]
	f.lug_facing = d["lug_facing"]
	f.art = d["art"]
	f.pull_time = d.get("pull_time", Freight.PULL_TIME)
	f.answer_range = d.get("answer_range", 0.0)
	f.answers_needs_power = d.get("needs_power", false)

## The hold the Components `ids` give the ship once they are fitted.
static func hold(ids: Array) -> float:
	var total := 0.0
	for id in ids:
		total += float(DATA.get(id, {}).get("hold", 0.0))
	return total

## Where Component `id` goes on the hull; each place takes one Component at a time.
static func place(id: String) -> String:
	return str(DATA.get(id, {}).get("place", ""))

## `id`'s outline once fitted, in the ship's space; empty for one that cannot be fitted.
static func fitted_outline(id: String) -> PackedVector2Array:
	return PackedVector2Array(_fitted(id).get("outline", []))

## What fitting `id` adds to the ship's own mass.
static func fitted_mass(id: String) -> float:
	return float(_fitted(id).get("mass", 0.0))

## The strap bands drawn across `id` once fitted, in the ship's space.
static func fitted_bands(id: String) -> Array:
	return _fitted(id).get("bands", [])

static func _fitted(id: String) -> Dictionary:
	return DATA.get(id, {}).get("fitted", {})

## `id`'s name as the station's menus show it ("CARGO BAY").
static func label(id: String) -> String:
	return str(DATA.get(id, {}).get("label", id.to_upper()))

## How hard Component `id` holds when it is buried (Freight.pull_threshold).
static func pull_threshold(id: String) -> float:
	return DATA.get(id, {}).get("pull_threshold", Freight.DEFAULT_PULL_THRESHOLD)
