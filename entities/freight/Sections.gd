class_name Sections

## The pieces of SR-7 that come back as Freight (docs/OPENING.md §4): each one's name,
## shape, Lug and mass. A Section is ordinary Freight with a `section` id, and it only
## fits the Mount with the same id (entities/structures/Mount.gd).
##
## Each outline is laid along its own x axis and a few px smaller than its gap, so the
## last few pixels have room; the Mount's turn stands it up in the station. The Lug is on
## the face that looks out into open space once seated, which fixes the heading it goes in at.

const FUEL_TANK := "fuel_tank"
const SOLAR_ARRAY := "solar_array"
const DORSAL_ARM := "dorsal_arm"
## Not Freight: the right solar wing, still hanging on, nudged home (ArrayNudge.gd). Kept
## here so its seated state has an id beside the others.
const SOLAR_ARRAY_2 := "solar_array_2"

const DATA := {
	# Full - fuel is heavy - so it is the one that halves the ship's acceleration. A long
	# capsule carried by the middle of its flank: it goes in sideways, from the boom side.
	FUEL_TANK: {
		"label": "FUEL TANK",
		"mass": 3.0,
		"art": "tank",
		"outline": [
			Vector2(-45, -23), Vector2(45, -23), Vector2(63, -5), Vector2(63, 5),
			Vector2(45, 23), Vector2(-45, 23), Vector2(-63, 5), Vector2(-63, -5),
		],
		"lug_position": Vector2(0, -23),
		"lug_facing": Vector2.UP,
	},
	# Light but long, held by its outer tip: it swings like a lance.
	SOLAR_ARRAY: {
		"label": "SOLAR ARRAY",
		"mass": 1.0,
		"art": "array",
		"outline": [Vector2(-73, -23), Vector2(73, -23), Vector2(73, 23), Vector2(-73, 23)],
		"lug_position": Vector2(-73, 0),
		"lug_facing": Vector2.LEFT,
	},
	# A pressurised module, held by its top end: it goes in nose-first, down onto its plate.
	DORSAL_ARM: {
		"label": "DORSAL ARM",
		"mass": 2.0,
		"art": "arm",
		"outline": [
			Vector2(-54, -32), Vector2(54, -32), Vector2(58, -28), Vector2(58, 28),
			Vector2(54, 32), Vector2(-54, 32), Vector2(-58, 28), Vector2(-58, -28),
		],
		"lug_position": Vector2(-58, 0),
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
	f.art = d["art"]

## The detail drawn over a Section's body - the same parts the station draws where it is
## seated, so a loose piece reads as SR-7's and not as scrap. Lines only, in the hull tones.
static func detail(art: String, outline: PackedVector2Array) -> Array[Line2D]:
	var box := Freight.bounds(outline)
	var out: Array[Line2D] = []
	match art:
		"tank":
			# Frame bands round the capsule, and a light strip down its length
			for f: float in [0.2, 0.5, 0.8]:
				var x := box.position.x + box.size.x * f
				out.append(_line(Vector2(x, box.position.y + 3), Vector2(x, box.end.y - 3), Colors.HULL_DARK, 2.0))
			out.append(_line(Vector2(box.position.x + 10, -6), Vector2(box.end.x - 10, -6), Color(Colors.HULL_LIGHT, 0.35), 2.0))
		"array":
			# The cell grid and its spine
			var cols := 10
			for i in range(1, cols):
				var x := box.position.x + box.size.x * i / cols
				out.append(_line(Vector2(x, box.position.y), Vector2(x, box.end.y), Colors.HULL_MID, 1.0))
			out.append(_line(Vector2(box.position.x, 0), Vector2(box.end.x, 0), Color(Colors.HULL_LIGHT, 0.5), 1.5))
		"arm":
			for f: float in [0.25, 0.5, 0.75]:
				var x := box.position.x + box.size.x * f
				out.append(_line(Vector2(x, box.position.y + 3), Vector2(x, box.end.y - 3), Colors.HULL_DARK, 1.5))
	return out

static func _line(a: Vector2, b: Vector2, color: Color, width: float) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array([a, b])
	l.width = width
	l.default_color = color
	return l

## The body colour a Section is drawn in: a solar wing is its dark cells, the rest hull.
static func body_color(art: String) -> Color:
	return Colors.NEBULA if art == "array" else Colors.HULL_MID
