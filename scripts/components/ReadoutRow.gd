extends Resource
class_name ReadoutRow

## One row of a Readout: `STATE ...... EMPTY`. A Resource, so a readout's rows can be
## written in the inspector; an owner with live state builds them in `readout_rows()`.

@export var label := ""
@export var value := ""


static func make(row_label: String, row_value: String) -> ReadoutRow:
	var row := ReadoutRow.new()
	row.label = row_label
	row.value = row_value
	return row
