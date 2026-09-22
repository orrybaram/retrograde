class_name Sections

## The pieces of SR-7 that come back as Freight (docs/OPENING.md §4): each one's name,
## shape, Lug and mass. A Section is ordinary Freight with a `section` id, and it only
## fits the Mount with the same id (entities/structures/Mount.gd).

const MAST_1 := "mast_1"

## A stretch of mast, shaped to slide sideways into the waist of SR-7 where `Tower1`
## was: thinner than the gap, so the last few pixels have room. The Lug is on the end
## that faces out of the gap, so it goes in nose-first from open space.
const DATA := {
	MAST_1: {
		"label": "MAST 1",
		"mass": 3.0,
		"outline": [
			Vector2(-50, -12), Vector2(-46, -15), Vector2(46, -15), Vector2(50, -12),
			Vector2(50, 12), Vector2(46, 15), Vector2(-46, 15), Vector2(-50, 12),
		],
		"lug_position": Vector2(-50, 0),
		"lug_facing": Vector2.LEFT,
	},
}

static func exists(id: String) -> bool:
	return DATA.has(id)

## Make `f` into Section `id`. Call before it enters the tree (its shape is built then).
static func apply(f: Freight, id: String) -> void:
	if not DATA.has(id):
		return
	var d: Dictionary = DATA[id]
	f.section = id
	f.label = d["label"]
	f.mass = d["mass"]
	f.outline = PackedVector2Array(d["outline"])
	f.lug_position = d["lug_position"]
	f.lug_facing = d["lug_facing"]
