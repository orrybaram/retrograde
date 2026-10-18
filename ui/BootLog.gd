extends Control
class_name BootLog

## The ship's manual diagnostic on the HUD (docs/OPENING.md §4): a `BootChecklist` typed out in
## bare terminal text in the dashboard's bottom-left corner, growing upward. It stands in for
## the dashboard while the game owes it (holds_corner): the HUD keeps the dashboard dark
## until the log is done, and powers its pieces back on once the pilot has the controls. It
## runs once, on a new game, from a beat after control is handed over until every row is
## OK - then DIAGNOSTIC COMPLETE holds, and it fades for good. Only whether it is still owed
## is saved: a continue from a game quit mid-diagnostic runs it again from the top.
##
## While it runs the ship's controls are locked (ControlLock) and come back a section at a
## time, as each section's heading types: FLIGHT's stick, SONAR's Sweep, MAGNET's clamp,
## LATERAL's strafe, RELEASE's let-go. Until it completes, thrust is held to
## ControlLock.SYSTEM_SPEED in SR-7's frame and the boost is held off. A new game locks from
## its first frame (prepare); a ship lost mid-diagnostic relaunches locked where it left
## off, its passes on file (arm, begin). Anything else that stops the log clears every lock.
##
## Everything it knows it reads, never asks for: the ship's stick flags for the flight
## rows, the Sweep and the seating off the EventBus, the magnet and the release holds off
## the ship's state, and where Freight and Mounts are, and how long a load has been carried,
## for when to open the later sections.

const TEXT_SIZE := 11
## The log's own size, bigger than the corner's other text; the dev panel tunes `text_size`.
const DEFAULT_SIZE := 16
const SIZE_LIMIT := Vector2i(8, 32)
const OUTLINE := 4
## Its inset from the screen's left edge; its bottom edge is the dashboard's.
const LEFT_MARGIN := 16.0
## A beat of flight before the first line types, so it reads as the ship waking up.
const START_DELAY := 1.2
const FADE_TIME := 1.2
## A loose piece's Lug this close to the ship opens SONAR: just past a tapped Sweep's reach,
## so the row has typed by the time a ring would get there.
const SWEEP_NEAR := SonarPulse.END_RADIUS + 80.0
## The nose this close to a loose piece's Lug opens MAGNET (the magnet itself takes at 25).
const MAGNET_NEAR := 50.0
## Seconds carrying before LATERAL opens: a beat after the pickup, once MAGNET has cleared.
const LATERAL_BEAT := 2.4
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
## The dashboard it stands in for: its bottom edge is where the log sits.
var dashboard: Control = null
var _label: RichTextLabel
var _delay := 0.0
var _fade: Tween = null
var _carried := 0.0
## This game still owes the diagnostic (a new game, until it completes), and the sections
## it has passed so far, which survive the ship being lost.
var _owed := false
var _passed: Array[String] = []
## The last diagnostic ran to PASS, so the pilot was handed the controls (HUD powers the
## dashboard up for this, and simply shows it for anything else that ends the log).
var handed_over := false
## Font size of the log; its small aside scales with it.
var text_size := DEFAULT_SIZE:
	set(value):
		text_size = clampi(value, SIZE_LIMIT.x, SIZE_LIMIT.y)
		if _label:
			_apply_size()


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
	_label.add_theme_color_override("default_color", Colors.PRIMARY)
	_label.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	_label.add_theme_constant_override("outline_size", OUTLINE)
	add_child(_label)
	_apply_size()
	EventBus.sonar_pulsed.connect(func(_origin: Vector2) -> void: _use(BootChecklist.SWEEP))
	EventBus.freight_answered.connect(func() -> void:
		if checklist:
			checklist.contact())
	EventBus.section_seated.connect(func(_id: String) -> void: _use(BootChecklist.SEATED))
	visible = false


## A new game owes a diagnostic from its first frame: nothing passed yet, and every
## control locked through the wake, before the log starts typing (begin).
func prepare() -> void:
	_passed.clear()
	_owed = true
	handed_over = false
	arm()


## Lock every control a section still owed would hand back. A relaunch arms again from its
## first frame, so a clone lost mid-diagnostic comes up locked where it left off.
func arm() -> void:
	if not _owed:
		return
	for section in UNLOCKS:
		if not section in _passed:
			ControlLock.lock(UNLOCKS[section])
	# CTRL AUTH is the system's: thrust is held slow until it hands over
	ControlLock.speed_cap = ControlLock.SYSTEM_SPEED
	_track_frame()


## Start the log, if the game still owes one: the sections already passed (by a clone lost
## since) come up passed and unlocked, and the rest run again from their triggers.
func begin() -> void:
	if not _owed:
		return
	checklist = BootChecklist.new()
	checklist.small_size = _small_size()
	checklist.restore(_passed)
	_delay = START_DELAY
	_carried = 0.0
	_label.text = ""
	arm()
	if _fade:
		_fade.kill()
	modulate.a = 1.0
	visible = true


## Gone for now - the ship was lost, or a scenario skipped the opening - with every lock
## off. What had passed is kept for a relaunch; a finished diagnostic is owed no more.
func stop() -> void:
	if checklist:
		_passed = checklist.cleared_sections()
		if checklist.is_complete():
			_owed = false
			handed_over = true
			Save.save_diagnostic_owed(false)
	checklist = null
	ControlLock.clear()
	if _fade:
		_fade.kill()
	visible = false


## Not this game's any more: a load, or a scenario past the opening. A relaunch after
## this brings nothing back.
func forget() -> void:
	stop()
	_owed = false
	handed_over = false
	_passed.clear()


## Whether anything is still locked (ControlLock), for scenarios.
func has_locks() -> bool:
	return ControlLock.any()


func clear_now() -> void:
	stop()


## This game hasn't passed the diagnostic yet (Save keeps it).
func is_owed() -> bool:
	return _owed


func is_running() -> bool:
	return checklist != null

## Whether the log has the dashboard's corner: from a new game's first frame until it fades
## for good, through a relaunch mid-diagnostic.
func holds_corner() -> bool:
	return _owed or checklist != null


## What the log reads right now, as plain text.
func text() -> String:
	return checklist.plain() if checklist else ""


func _use(mark: StringName) -> void:
	if checklist:
		checklist.use(mark)


func _process(dt: float) -> void:
	if ControlLock.is_capped():
		_track_frame()  # through the wake too, before the log starts
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


func _small_size() -> int:
	return maxi(1, roundi(text_size * float(BootChecklist.SMALL_SIZE) / TEXT_SIZE))


func _apply_size() -> void:
	_label.add_theme_font_size_override("normal_font_size", text_size)
	if checklist:
		checklist.small_size = _small_size()
		_label.text = checklist.render()
	var font := _label.get_theme_font("normal_font")
	if font:
		var width := BootChecklist.LABEL_COL + BootChecklist.KEY_COL + BootChecklist.STAMP_OK.length() + 1
		_label.custom_minimum_size.x = font.get_string_size("0".repeat(width), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	_label.reset_size()


## The speed cap counts in SR-7's frame: keep its velocity current.
func _track_frame() -> void:
	var station := get_tree().get_first_node_in_group("space_stations") as RigidBody2D
	ControlLock.frame_velocity = station.linear_velocity if station else Vector2.ZERO


## Bottom left, growing upward from the dashboard's bottom edge. Read off its offsets, not
## its position, which HudGlitch shakes.
func _place() -> void:
	var box := _label.get_combined_minimum_size()
	var bottom := get_parent_area_size().y + (dashboard.offset_bottom if dashboard else 0.0)
	position = Vector2(LEFT_MARGIN, bottom - box.y)


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
