extends Resource
class_name ReadoutRow

## One row of a SweepReadout: `STATE ...... EMPTY`. A Resource, so a readout's rows can be
## written in the inspector; an owner with live state builds them in `readout_rows(tier)`.

@export var label := ""
@export var value := ""
## The least a Sweep has to read to show this row (SweepReadout.tier_for).
@export_range(1, 3) var tier := 1


static func make(row_label: String, row_value: String, row_tier := 1) -> ReadoutRow:
	var row := ReadoutRow.new()
	row.label = row_label
	row.value = row_value
	row.tier = row_tier
	return row
