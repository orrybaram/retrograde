extends RefCounted
class_name Objectives

## The player's current goal: the one thing to do next, shown on the HUD's top-left line
## (GoalLine). Nothing here is saved or remembered. The goal is worked out from what the
## Progress ledger holds, so a continue, a relaunch or a dev-panel warp always reads the
## right rung.
##
## The ladder, first unfinished rung wins:
##   RETURN SR-7'S SECTIONS  n/3       - the Sections are seated in their Mounts
##   PUSH THE RIGHT WING HOME          - the hanging wing (ArrayNudge) is seated
##   WAKE SR-7'S CORE                  - CORE_STARTED
##   FIND WHAT ANSWERS THE DISH  VELD  - the hauler is identified (or the Cargo Bay is home)
##   BRING THE CARGO BAY HOME  ...     - it is in the Cradle, or fitted
##   FIT THE CARGO BAY  ...            - it is fitted
##   POWER <PLANET>'S GATE  n/cost ST  - the cheapest unpowered Gate is powered, five times
##   ALL FIVE MODULES ONLINE           - the Core's endgame is still to be built

const NONE := {"text": "", "detail": ""}

const RETURN_SECTIONS := "RETURN SR-7'S SECTIONS"
const PUSH_WING := "PUSH THE RIGHT WING HOME"
const WAKE_CORE := "WAKE SR-7'S CORE"
const FIND_DISH := "FIND WHAT ANSWERS THE DISH"
const FIND_DISH_WHERE := "VELD"
const BRING_CARGO_BAY := "BRING THE CARGO BAY HOME"
const BRING_CARGO_BAY_WHERE := "SR-7'S CRADLE"
const FIT_CARGO_BAY := "FIT THE CARGO BAY"
const FIT_CARGO_BAY_WHERE := "DOCK AT SR-7 - SHIP"
const POWER_A_GATE := "POWER A GATE"
const POWER_NAMED_GATE := "POWER %s'S GATE"
const MODULES_ONLINE := "ALL FIVE MODULES ONLINE"
const MODULES_ONLINE_DETAIL := "THE CORE IS WAITING"


## The goal right now, as {"text", "detail"}. `next_gate` is the cheapest Gate not yet
## powered, as {"name": its planet's name once identified, else "", "cost": Stores}, or
## empty when every one is.
static func current(progress: Progress, cradled: PackedStringArray, stores: int,
		next_gate: Dictionary) -> Dictionary:
	var seated := 0
	for id in Sections.DATA:
		if progress.holds(Progress.SEATED_SECTIONS, id):
			seated += 1
	if seated < Sections.DATA.size():
		return _goal(RETURN_SECTIONS, "%d/%d" % [seated, Sections.DATA.size()])
	if not progress.holds(Progress.SEATED_SECTIONS, Sections.SOLAR_ARRAY_2):
		return _goal(PUSH_WING)
	if not progress.flagged(Progress.CORE_STARTED):
		return _goal(WAKE_CORE)
	var bay_home := Components.CARGO_BAY in cradled \
			or progress.holds(Progress.FITTED_COMPONENTS, Components.CARGO_BAY)
	if not bay_home and progress.count(Progress.IDENTIFIED_WRECKS) == 0:
		return _goal(FIND_DISH, FIND_DISH_WHERE)
	if not bay_home:
		return _goal(BRING_CARGO_BAY, BRING_CARGO_BAY_WHERE)
	if Components.CARGO_BAY in cradled:
		return _goal(FIT_CARGO_BAY, FIT_CARGO_BAY_WHERE)
	if not next_gate.is_empty():
		var cost: int = next_gate.get("cost", 0)
		var gate_name: String = next_gate.get("name", "")
		var text := POWER_A_GATE if gate_name == "" else POWER_NAMED_GATE % gate_name.to_upper()
		return _goal(text, "%d/%d ST" % [mini(stores, cost), cost])
	if progress.count(Progress.POWERED_GATES) >= Gate.MODULE_COUNT:
		return _goal(MODULES_ONLINE, MODULES_ONLINE_DETAIL)
	return NONE


## The cheapest planet Gate in `gates` not yet powered, in the shape `current` takes.
static func next_gate(gates: Array) -> Dictionary:
	var best: Gate = null
	for node in gates:
		var g := node as Gate
		if g == null or g.is_core or g.is_powered():
			continue
		if best == null or g.power_cost < best.power_cost:
			best = g
	if best == null:
		return {}
	var gate_name := ""
	if best.is_identified() and best.parent_planet:
		gate_name = best.parent_planet.planet_name
	return {"name": gate_name, "cost": best.power_cost}


static func _goal(text: String, detail := "") -> Dictionary:
	return {"text": text, "detail": detail}
