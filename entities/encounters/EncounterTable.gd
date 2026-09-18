extends Resource
class_name EncounterTable

## The weighted list of things that can turn up in deep space, and how many of them a
## single cell may hold. Which entries are in play depends only on the cell's distance
## from the sun, so a cell's roll is reproducible. See docs/ENCOUNTERS.md.

@export var entries: Array[EncounterDef] = []

## Encounters per cell. A cell is EncounterField.CELL_SIZE across, so these are small
## numbers — the void is supposed to stay mostly void.
@export var min_per_cell: int = 0
@export var max_per_cell: int = 2

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
