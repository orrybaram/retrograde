extends Resource
class_name ProcedureDef

## A Procedure (docs/SWEEP.md §4): a sequence of Marks that a piece of hardware answers.
## Two to four words, each an Operation and its Argument, then a Commit. The printed form -
## the Notation on a placard (ui/PlacardPanel.gd) - is drawn from `steps` too, so a
## Procedure and its documentation can never drift apart.
##
## A Mark is a Slot, 1 to 6 (Resonance). Odd Marks are Operations, even ones Arguments.

## The six Operations, by Slot. The vocabulary is closed for the whole game.
const OPERATIONS: Array[String] = ["", "SEAT", "CYCLE", "PURGE", "INDEX", "ECHO", "LOCKOUT"]
## The Notation's glyph column for each Operation - the optional channel, decodable only by
## seeing the same glyph beside the same dots again and again. Placeholders until the
## stamped glyphs are designed (docs/SWEEP.md TODOs), and plain ASCII because the game's
## pixel font has nothing else.
const GLYPHS: Array[String] = ["", "<seat>", "<cycle>", "<purge>", "<index>", "<echo>", "<lockout>"]

@export var id: StringName = &""
## The placard's heading, e.g. "SR-7 / CORE, COLD START".
@export var title := ""
## The words, in order: x the Operation's Slot, y the Argument's.
@export var steps: Array[Vector2i] = []

## The Marks that perform it, in order: operation, argument, operation, argument...
func marks() -> Array[int]:
	var out: Array[int] = []
	for step in steps:
		out.append(step.x)
		out.append(step.y)
	return out

## How `entered` compares: `ok` when it is exactly this Procedure; otherwise `right` is how
## many Marks are in their right place - a count, never which ones (docs/SWEEP.md §7) - and
## `incomplete` whether a word is missing its argument.
func check(entered: Array) -> Dictionary:
	var want := marks()
	var right := 0
	for i in mini(entered.size(), want.size()):
		if int(entered[i]) == want[i]:
			right += 1
	return {
		"ok": entered.size() == want.size() and right == want.size(),
		"right": right,
		"incomplete": entered.size() % 2 == 1,
	}

## The Notation's glyph for row `row` of the placard: the Operation's glyph on an
## Operation row, `-n` on an Argument row.
func glyph(row: int) -> String:
	var m := marks()
	if row < 0 or row >= m.size():
		return ""
	return GLYPHS[m[row]] if row % 2 == 0 else "-%d" % m[row]
