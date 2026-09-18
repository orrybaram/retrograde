extends Resource
class_name EncounterTable

## The weighted list of things that can turn up in deep space, and how many of them a
## single cell may hold. Which entries are in play depends only on the cell's distance
## from the sun, so a cell's roll is reproducible. See docs/ENCOUNTERS.md.

@export var entries: Array[EncounterDef] = []

## Odds that a cell holds anything at all. This is the dial for how empty the void
## feels: most cells should come up empty, so that finding something is an event rather
## than scenery.
@export_range(0.0, 1.0) var chance_per_cell: float = 1.0

## How many encounters a cell that does hold something gets. A cell is one
## EncounterField.BAND_WIDTH across, so these stay small.
@export var min_per_cell: int = 0
@export var max_per_cell: int = 2

## How many encounters this cell holds. Always draws exactly one number whatever the
## outcome, so an empty cell doesn't shift what a populated one would have rolled.
func roll_count(rng: RandomNumberGenerator) -> int:
	if rng.randf() >= chance_per_cell:
		return 0
	return rng.randi_range(min_per_cell, max_per_cell)

func eligible(radius: float) -> Array[EncounterDef]:
	var out: Array[EncounterDef] = []
	for def in entries:
		if def and def.weight > 0.0 and def.fits(radius):
			out.append(def)
	return out

## Weighted pick among the defs eligible at `radius`. Always draws exactly one number
## from `rng`, whatever the outcome, so skipping a pick never shifts the rest of the cell.
func pick(rng: RandomNumberGenerator, radius: float) -> EncounterDef:
	var choices := eligible(radius)
	var total := 0.0
	for def in choices:
		total += def.weight
	var roll := rng.randf() * total
	for def in choices:
		roll -= def.weight
		if roll <= 0.0:
			return def
	return null
