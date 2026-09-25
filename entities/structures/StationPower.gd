extends Node
class_name StationPower

## SR-7's power (docs/OPENING.md §3, §5). The station is dead until its core is
## cold-started (CoreHousing) - and the core only listens once every piece is home, so the
## wings are pieces like the others, not a switch. Until then every light is out, the
## dock's lamps are dark, and the comm dish hangs limp on its post. Power coming in while
## the player watches wakes it in order: the lights catch one by one outward from the core,
## then the dock, and only then does the dish swing up, find the Sun and ping - and
## `woken` fires. The emergency alarms at the cuts run on their own (CutAlarm) and stop one
## by one as each piece goes home.

signal woken  ## A live wake has run to the end: the dish is on the Sun and has pinged.

@export var lights: NodePath
@export var dish: NodePath
@export var port: NodePath

var powered := false

func _ready() -> void:
	add_to_group("station_power")
	EventBus.planets_restored.connect(refresh)
	EventBus.core_started.connect(func() -> void: refresh(false))
	refresh.call_deferred()

## Whether `gs` has the core running.
static func is_powered(gs: GameState) -> bool:
	return gs != null and gs.core_started

## Match the game's state. `instant` (a load, a new game) snaps; a live repair wakes.
func refresh(instant := true) -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	_apply(is_powered(gs), instant)

func _apply(on: bool, instant: bool) -> void:
	var changed := on != powered
	powered = on
	var l := get_node_or_null(lights) as StationLights
	var d := get_node_or_null(dish) as CommDish
	var p := get_node_or_null(port) as SpacePort
	if on and changed and not instant and l:
		_wake(l, d, p)
		return
	if l and (changed or instant):
		l.set_lit(on)
	if d:
		d.limp = not on
		if instant:
			d.cancel_wake()
	if p:
		p.set_lit(on)

## The power comes in: lights one by one, then the dock, then the dish comes up.
func _wake(l: StationLights, d: CommDish, p: SpacePort) -> void:
	l.set_lit(true, false)
	await l.woken
	if not powered:
		return
	if p:
		p.set_lit(true)
	if d:
		d.limp = false
		await d.settled
	woken.emit()
