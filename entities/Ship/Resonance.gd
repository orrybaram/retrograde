extends Node
class_name Resonance

## The ship's side of a Procedure (docs/SWEEP.md §3-4): the Marks laid down so far, read
## off how long each Sweep was held. The Sweep charges for as long as `action` is held;
## the bar across BAR_TIME is split into six Slots, and the Slot the key comes up in is the
## Mark - a tap is Slot 1. Held to the end of the bar, the release is the Commit instead,
## and it carries every Mark out on that ring to whatever hardware it reaches
## (SonarPulse.fire, `on_procedure`).
##
## It only listens where something does: `available()` needs a listening piece of hardware
## (group `procedure_listeners`, with `procedure_point()` and `listens()`) within REACH,
## and the ship flying free. Everywhere else a Sweep is just a Sweep, and no bar shows.
## Marks chain while each press comes within CHAIN_WINDOW of the last release; let it
## lapse, or fly out of reach, and they fall off the bar.

signal marks_changed
signal committed(marks: Array[int])

const SLOTS := 6
## The bar, s: the same length as a harvest's.
const BAR_TIME := HarvestTiming.NORMAL_DURATION
## From a release to the next press, s, before the Marks fall off.
const CHAIN_WINDOW := 1.2
## How close a listening device must be for the bar to show. Inside what a Commit reaches
## (a hold of BAR_TIME, SonarPulse.strength_for), so a Commit laid down here arrives.
const REACH := 520.0

var marks: Array[int] = []
## Seconds since the last release, while the key is up.
var _since := 0.0

## The Slot (1-6) a hold of `held` s lands in; a hold of the whole bar or more is a Commit.
static func slot_for(held: float) -> int:
	return clampi(int(floor(held / (BAR_TIME / SLOTS))) + 1, 1, SLOTS)

static func is_commit(held: float) -> bool:
	return held >= BAR_TIME

## Whether a listening device is in reach of `ship` and the ship is free to address it.
static func available_for(ship: Ship) -> bool:
	if ship == null or ship.state_machine == null:
		return false
	var flying: State = ship.state_machine.states.get("FlyingState")
	if flying == null or ship.state_machine.current_state != flying:
		return false
	return listener_near(ship.get_tree(), ship.global_position) != null

## The nearest device within REACH of `at` that is listening, or null.
static func listener_near(tree: SceneTree, at: Vector2) -> Node:
	var best: Node = null
	var best_d := REACH
	for node in tree.get_nodes_in_group("procedure_listeners"):
		if not node.has_method("procedure_point") or not node.listens():
			continue
		var d: float = at.distance_to(node.procedure_point())
		if d <= best_d:
			best = node
			best_d = d
	return best

## The key came up after `held` s. A Commit hands back the Marks it carries (and clears
## them); a Mark is added and nothing is handed back.
func release(held: float) -> Array[int]:
	_since = 0.0
	if is_commit(held):
		var out := marks.duplicate()
		clear()
		if not out.is_empty():
			committed.emit(out)
		return out
	marks.append(slot_for(held))
	marks_changed.emit()
	return []

## Every physics tick: `charging` is the key being held on a Sweep, `in_reach` whether a
## listener still is. The window only runs while the key is up.
func tick(delta: float, charging: bool, in_reach: bool) -> void:
	if marks.is_empty():
		return
	if not in_reach:
		clear()
		return
	if charging:
		return
	_since += delta
	if _since > CHAIN_WINDOW:
		clear()

func clear() -> void:
	if marks.is_empty():
		return
	marks.clear()
	marks_changed.emit()
