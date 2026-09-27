class_name Components

## The Components that turn up as Freight (docs/OPENING.md §9, docs/adr/0007): each one's
## name, shape, Lug and mass, and how it lies in the world until it is found. A Component
## is ordinary Freight with a `component` id; it is delivered to SR-7's Cradle, not to a
## Mount, and fitted there from the station's menus.
##
## Like a Section, each outline is laid along its own x axis with the Lug on one end.

const CARGO_BAY := "cargo_bay"

const DATA := {
	# The first Component: a hauler's hold, buried Lug-up in the wreck on Veld (HaulerWreck).
	# A squat box, heavier than anything of SR-7's - the ship crawls with it - but the Aux
	# still lifts it off Veld. It holds in the ground harder than the Aux can pull: only the
	# Burn tears it free, and the tear-out (`pull_time` s of Burn, playtests/cargo_bay.play)
	# costs about a fifth of a full tank, so the quarter SR-7 gives is just enough (§9).
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
		"pull_time": 4.5,
		"answer_range": 5000.0,
		"needs_power": true,
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

## How hard Component `id` holds when it is buried (Freight.pull_threshold).
static func pull_threshold(id: String) -> float:
	return DATA.get(id, {}).get("pull_threshold", Freight.DEFAULT_PULL_THRESHOLD)
