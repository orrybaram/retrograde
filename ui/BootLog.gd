extends Control
class_name BootLog

## The ship's manual diagnostic on the HUD (docs/OPENING.md §6): a `BootChecklist` typed out in
## bare terminal text in the bottom-right corner, growing upward - on top of UNIT-7's
## panel while that is up, which shares the corner. It runs once,
## on a new game, from a beat after control is handed over until every row is OK - then
## DIAGNOSTIC COMPLETE holds, and it fades for good. Not saved: a continue never shows it.
##
## While it runs the ship's controls are locked (ControlLock) and come back a section at a
## time, as each section's heading types: FLIGHT's stick, SONAR's Sweep, MAGNET's clamp,
## LATERAL's strafe, RELEASE's let-go. Boost is never locked. Anything that stops the log
## clears every lock.
##
## Everything it knows it reads, never asks for: the ship's stick flags for the flight
## rows, the Sweep and the seating off the EventBus, the magnet and the release holds off
## the ship's state, and where Freight and Mounts are, and how long a load has been carried,
## for when to open the later sections.

const TEXT_SIZE := 11
const OUTLINE := 4
## The corner it sits in: RadioPanel's margins (clear of the action prompt and the save
## indicator), and the gap it keeps above that panel while it is up.
const SCREEN_MARGIN := RadioPanel.SCREEN_MARGIN
const GAP := 10.0
## A beat of flight before the first line types, so it reads as the ship waking up.
const START_DELAY := 1.2
const FADE_TIME := 1.2
## A loose piece's Lug this close to the ship opens SONAR: just past a tapped Sweep's reach,
## so the row has typed by the time a ring would get there.
const SWEEP_NEAR := SonarPulse.END_RADIUS + 80.0
## The nose this close to a loose piece's Lug opens MAGNET (the magnet itself takes at 25).
const MAGNET_NEAR := 50.0
## Seconds carrying before LATERAL opens: a beat after the pickup, once MAGNET has cleared.
const LATERAL_BEAT := 1.6
## A carried Section this close to one of its Mount's seats opens RELEASE (it seats at 40).
const RELEASE_NEAR := 150.0

## What each section gives back.
const UNLOCKS := {
	BootChecklist.FLIGHT: [&"thrust", &"reverse_thrust", &"turn_left", &"turn_right"],
	BootChecklist.SONAR: [ControlLock.SWEEP],
	BootChecklist.MAGNET: [ControlLock.CLAMP],
	BootChecklist.LATERAL: [&"strafe_left", &"strafe_right"],
	BootChecklist.LET_GO: [ControlLock.RELEASE],
}

var checklist: BootChecklist = null
var radio: Control = null
var _label: RichTextLabel
var _delay := 0.0
var _fade: Tween = null
var _carried := 0.0


func _ready() -> void:
	add_to_group("boot_log")
	# Main.clear_screen_effects: a new game, a load or a quit to the menu clears it
	add_to_group("screen_effects")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	_label.add_theme_color_override("default_color", Colors.PRIMARY)
	_label.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	_label.add_theme_constant_override("outline_size", OUTLINE)
	add_child(_label)
	var font := _label.get_theme_font("normal_font")
	if font:
		var width := BootChecklist.LABEL_COL + BootChecklist.KEY_COL + BootChecklist.STAMP_OK.length() + 1
		_label.custom_minimum_size.x = font.get_string_size("0".repeat(width), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	EventBus.sonar_pulsed.connect(func(_origin: Vector2) -> void: _use(BootChecklist.SWEEP))
	EventBus.freight_answered.connect(func() -> void:
		if checklist:
			checklist.contact())
	EventBus.section_seated.connect(func(_id: String) -> void: _use(BootChecklist.SEATED))
	visible = false


## Start the check over: a new game.
func begin() -> void:
	checklist = BootChecklist.new()
	_delay = START_DELAY
	_carried = 0.0
	_label.text = ""
	for section in UNLOCKS:
		ControlLock.lock(UNLOCKS[section])
	if _fade:
		_fade.kill()
	modulate.a = 1.0
	visible = true


## Gone, not finished: a load, a quit, or a scenario that skips the opening.
func stop() -> void:
	checklist = null
	ControlLock.clear()
	if _fade:
		_fade.kill()
	visible = false


## Whether anything is still locked (ControlLock), for scenarios.
func has_locks() -> bool:
	return ControlLock.any()


func clear_now() -> void:
	stop()


func is_running() -> bool:
	return checklist != null


## What the log reads right now, as plain text.
func text() -> String:
	return checklist.plain() if checklist else ""


func _use(mark: StringName) -> void:
	if checklist:
		checklist.use(mark)


func _process(dt: float) -> void:
	if checklist == null:
		return
	_place()
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship:
		_read_ship(ship)
	if _delay > 0.0:
		_delay -= dt
		if _delay > 0.0:
			return
		checklist.open(BootChecklist.FLIGHT)
	if ship:
		_open_sections(ship, dt)
	checklist.tick(dt)
	for section in UNLOCKS:
		if checklist.is_live(section):
			ControlLock.unlock(UNLOCKS[section])
	if checklist.is_complete():
		ControlLock.clear()
	_label.text = checklist.render()
	if checklist.is_finished() and (_fade == null or not _fade.is_valid()):
		_fade = create_tween()
		_fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		_fade.tween_callback(stop)


## Bottom right, growing upward: its bottom edge on the corner's margin, or a gap above
## UNIT-7's panel while that is up.
func _place() -> void:
	var box := _label.get_combined_minimum_size()
	var bottom := get_parent_area_size().y - SCREEN_MARGIN.y
	if radio and radio.visible:
		bottom = radio.position.y - GAP
	position = Vector2(get_parent_area_size().x - SCREEN_MARGIN.x - box.x, bottom - box.y)


func _read_ship(ship: Ship) -> void:
	if ship.want_thrust:
		checklist.use(BootChecklist.THRUST)
	if ship.want_reverse_thrust:
		checklist.use(BootChecklist.REVERSE)
	if ship.want_turn_left:
		checklist.use(BootChecklist.TURN_LEFT)
	if ship.want_turn_right:
		checklist.use(BootChecklist.TURN_RIGHT)
	if ship.want_strafe_left:
		checklist.use(BootChecklist.STRAFE_LEFT)
	if ship.want_strafe_right:
		checklist.use(BootChecklist.STRAFE_RIGHT)
	if ship.is_carrying():
		checklist.use(BootChecklist.CLAMP)
	elif checklist.is_used(BootChecklist.CLAMP):
		checklist.use(BootChecklist.RELEASE)  # carried, and now not
	var state := ship.state_machine.current_state if ship.state_machine else null
	if state is CarryingState:
		checklist.hold_progress = state.release_progress()
	elif state is FlyingState:
		checklist.hold_progress = state.magnet_progress()
	else:
		checklist.hold_progress = 0.0


func _open_sections(ship: Ship, dt: float) -> void:
	var nose := ship.to_global(Ship.NOSE)
	for node in get_tree().get_nodes_in_group("freight"):
		var f := node as Freight
		if f == null or not f.is_loose() or f.is_buried():
			continue
		if ship.global_position.distance_to(f.lug_global()) < SWEEP_NEAR:
			checklist.open(BootChecklist.SONAR)
		if nose.distance_to(f.lug_global()) < MAGNET_NEAR:
			checklist.open(BootChecklist.MAGNET)
	if not ship.is_carrying():
		_carried = 0.0
		return
	checklist.open(BootChecklist.MAGNET)
	_carried += dt
	if _carried >= LATERAL_BEAT:
		checklist.open(BootChecklist.LATERAL)
	var f := ship.freight
	if f == null or f.section == "":
		return
	var mount := Mount.for_section(get_tree(), f.section)
	if mount == null or mount.seated:
		return
	for seat in mount.seats():
		if seat.origin.distance_to(f.global_position) < RELEASE_NEAR:
			checklist.open(BootChecklist.LET_GO)
			return
