extends Cradle
class_name DorsalClaw

## SR-7's Cradle: a drop bay in the container strip, worked by the DORSAL ARM - a knuckle
## boom on a turntable in the middle of the strip, with a claw on a free wrist
## (docs/FREIGHT.md §5; tuned in dev/claw_lab). The ship hands it a Component as it hands
## any Cradle one - CarryingState.home_for -> Cradle.accepting -> fits -> seat:
##
##   1. A laden ship brings its load to the drop point off the right mast. The glide slope
##      lamps on the mast say whether it is too high or too low (`_slope_lamps`). Anywhere
##      within `catch_radius`, at any angle, the arm unfolds and closes on the load's free
##      end - the one away from the ship (ClawReaching).
##   2. The player holds ACTION to let go, as ever. `seat` takes the load and it is the
##      Cradle's at once (GameState.cradled, saved): the arm swings it round over the bay,
##      turning it level, and sets it on the pad (ClawDelivering).
##   3. The arm opens and folds back upright (ClawStowing), and the pad takes the load below
##      deck, where it waits to be fitted. The bay is always open: once the pad is back up
##      it takes the next. While it can take one, a beam of light shines up out of its hatch.
##
## The arm is the DORSAL ARM Section: until it is seated in its Mount (`mount`) there is no
## arm and the turntable shows the cut. Seated, it works once SR-7's core is running. The
## Section is the arm folded the way it stows (Sections.DATA), and the Mount's part is the
## footprint of that pose - drawn by nothing, since the arm draws itself here.
##
## Laid out in the station's own space: the node sits at the station's origin. The static
## parts - the deck with the bay's hatch, the turntable, the stock crates - are station
## polygons (SpaceStation.tscn); this draws only what moves or lights.

## A load has gone below: it is waiting to be fitted.
signal delivered(component: String)

## The DORSAL ARM's Mount: the arm is there once it is seated.
@export var mount: NodePath

@export_group("Arm")
## The shoulder joint, on top of the turntable.
@export var shoulder := Vector2(0, -450)
@export var upper_length := 210.0
@export var fore_length := 190.0
## Where the wrist rests with the arm folded: upright on the strip, the claw by the turntable.
@export var stow_wrist := Vector2(-34, -476)
## How far past the load's free end the wrist sits: the palm's depth.
@export var palm := 14.0
## How far out along the load's axis the claw lines up before sliding on.
@export var standoff := 40.0
## How high the arm lifts a load (wrist height) to swing it over the right mast.
@export var carry_height := -590.0

@export_group("Drop point")
## The middle of where a load is taken: its centre within `catch_radius` of here, at any angle.
@export var drop_point := Vector2(150, -640)
@export var catch_radius := 110.0
## A laden ship this close to the drop point lights the glide slope lamps (`_slope_lamps`).
@export var warn_radius := 450.0
## How far above or below the drop point a load still reads as level on the glide slope lamps.
@export var slope_band := 30.0
## The glide slope lamps, on the right mast facing the approach: top, then bottom.
@export var lamp_points: PackedVector2Array = [Vector2(201, -520), Vector2(201, -500)]
## Draw the catch radius (a tuning aid; the game shows only the lamps).
@export var show_tolerance := false

@export_group("Bay")
@export var deck_y := -422.0
@export var bay_left := 44.0
@export var bay_right := 166.0
## The pad stops short of the bay's inboard edge: that gap is where the bottom jaw goes.
@export var pad_left := 82.0
@export var sink_depth := 150.0

@export_group("Timing")
@export var reach_time := 1.0
@export var swing_time := 1.4
@export var set_time := 0.8
@export var open_time := 0.4
@export var stow_time := 1.1
@export var sink_time := 1.3
## How long the pad takes to come back up, empty, after taking a load below.
@export var reset_time := 1.5

const JAW_OPEN := 76.0
const JAW_SHUT := 62.0
## How the tracker labels the drop point.
const TRACK_LABEL := "CRADLE"

## The wrist, in the claw's space, and how far the jaws are closed (0 open, 1 shut).
var wrist := Vector2.ZERO
var jaw := 0.0
## The claw's angle: 0 is level, pointing right.
var claw_angle := 0.0
## How far the pad has sunk, and how bright the bay's beam is (0 dark, 1 open for a load).
var pad_drop := 0.0
var beam := 0.0
## The load the claw has, from `seat` until it has gone below.
var piece: Freight = null

var state_machine: StateMachine
var _mount: Mount
var _drop: Node2D
var _tracking: NodeTrackingTarget
## Above-deck mask: whatever is under it (the pad, a load in the claw) is cut off at the
## deck, so a load going below disappears into the station rather than drawing over it.
var _well: Polygon2D
var _beam: _Painter
var _pad: _Painter
var _lamps: _Painter
var _arm_view: _Painter
var _bay_busy := false

class _Painter extends Node2D:
	var paint: Callable
	func _draw() -> void:
		paint.call(self)

func _ready() -> void:
	super._ready()
	z_index = 1
	wrist = stow_wrist
	_mount = get_node_or_null(mount) as Mount
	_drop = Node2D.new()
	_drop.name = "DropPoint"
	_drop.position = drop_point
	add_child(_drop)
	_beam = _painter("Beam", _draw_beam, self)
	_well = Polygon2D.new()
	_well.name = "Well"
	_well.polygon = PackedVector2Array([Vector2(-2000, -4000), Vector2(2000, -4000), Vector2(2000, deck_y), Vector2(-2000, deck_y)])
	_well.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_well)
	_pad = _painter("Pad", _draw_pad, _well)
	_lamps = _painter("Lamps", _draw_lamps, self)
	_arm_view = _painter("Arm", _draw_arm, self)
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	state_machine.initial_state_name = "ClawStowed"
	for s: State in [ClawStowed.new(), ClawReaching.new(), ClawDelivering.new(), ClawStowing.new()]:
		s.name = s.get_script().get_global_name()
		state_machine.add_child(s)
	add_child(state_machine)
	EventBus.planets_restored.connect(refresh)

func _painter(n: String, f: Callable, parent: Node) -> _Painter:
	var p := _Painter.new()
	p.name = n
	p.paint = f
	parent.add_child(p)
	return p

func _process(delta: float) -> void:
	var s := state_machine.current_state
	if s:
		s.process(delta)
	if piece and is_instance_valid(piece) and not state_machine.current_state is ClawDelivering:
		piece.position = _slot_pose().origin + Vector2(0, pad_drop)
	beam = move_toward(beam, 1.0 if beam_on() else 0.0, delta / 0.5)
	_beam.queue_redraw()
	_pad.queue_redraw()
	_lamps.queue_redraw()
	_arm_view.queue_redraw()

# --- Cradle's interface ------------------------------------------------------------------

## The arm is there: the DORSAL ARM is seated in its Mount.
func arm_home() -> bool:
	return _mount == null or _mount.seated

## The claw works: the arm home and SR-7's core running.
func is_working() -> bool:
	if not arm_home():
		return false
	var gs := _game_state()
	return gs == null or gs.progress.flagged(Progress.CORE_STARTED)

## A load in the claw, or the pad still coming back up from taking one below.
func is_full() -> bool:
	return (piece != null and is_instance_valid(piece)) or _bay_busy

func drop_pose() -> Transform2D:
	return global_transform * Transform2D(PI, drop_point)

## A Component, the claw working and free, its centre within `catch_radius` of the drop
## point - at any angle - and its free end inside the arm's reach.
func fits(f: Freight) -> bool:
	if not is_working() or is_full() or f == null or f.component == "":
		return false
	var xf := pose_of(f)
	if xf.origin.distance_to(drop_point) > catch_radius:
		return false
	return grip_wrist(f, xf).distance_to(shoulder) <= upper_length + fore_length

## Let go of within `fits`: the Cradle has it now, in GameState and the save, and the claw
## takes it (or takes it where it is, if it had not got there yet).
func seat(f: Freight) -> void:
	if f == null or is_full():
		return
	_hold(f)
	_record(f.component)
	piece = f
	f.reparent(_well, true)
	# Freight draws a layer up (Freight._ready), which would lift it out of the well's clip
	f.z_index = 0
	NavSystem.clear()
	state_machine.change_state("ClawDelivering")

func tracking_target() -> NodeTrackingTarget:
	if _tracking == null:
		_tracking = NodeTrackingTarget.new(_drop, TRACK_LABEL, 60.0)
	return _tracking

## A new game or a load: whatever was mid-delivery is already in GameState.cradled (it was
## recorded when let go of), so the bay is simply ready again, the arm folded.
func refresh() -> void:
	if piece and is_instance_valid(piece):
		piece.queue_free()
	piece = null
	pad_drop = 0.0
	_bay_busy = false
	jaw = 0.0
	wrist = stow_wrist
	claw_angle = 0.0
	if state_machine and state_machine.current_state:
		state_machine.change_state("ClawStowed")

# --- what the states use -----------------------------------------------------------------

## The load a laden ship is holding at the drop point, if the claw could take it: the one
## to reach for.
func reachable_load() -> Freight:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null or not ship.is_carrying():
		return null
	var f := ship.freight
	return f if fits(f) else null

## `f`'s pose in the claw's space.
func pose_of(f: Freight) -> Transform2D:
	return global_transform.affine_inverse() * f.global_transform

## Where the wrist sits to hold a load posed `xf` (claw space) by its free end.
func grip_wrist(f: Freight, xf: Transform2D) -> Vector2:
	var along := xf.x.normalized()
	return xf.origin + along * (half_length(f) + palm)

## The claw's angle to hold a load posed `xf`: pointing back along it, from its free end.
func grip_angle(xf: Transform2D) -> float:
	return wrapf(xf.get_rotation() + PI, -PI, PI)

## Where a load's centre is, held by its free end with the wrist at `w` and turned `r`.
func held_pose(f: Freight, w: Vector2, r: float) -> Transform2D:
	return Transform2D(r, w - Vector2.from_angle(r) * (half_length(f) + palm))

## The pose a load rests in on the pad, Lug outboard.
func _slot_pose() -> Transform2D:
	return Transform2D(PI, Vector2((bay_left + bay_right) * 0.5, deck_y - _half_height()))

## The wrist's point with a load on the pad.
func slot_wrist() -> Vector2:
	var xf := _slot_pose()
	return xf.origin + xf.x.normalized() * (half_length(piece) + palm)

## The load's centre-to-free-end length: the far end of its outline along x.
static func half_length(f: Freight) -> float:
	var m := 0.0
	if f and is_instance_valid(f):
		for p in f.outline:
			m = maxf(m, p.x)
	return m if m > 0.0 else 58.0

func _half_height() -> float:
	var m := 0.0
	if piece and is_instance_valid(piece):
		for p in piece.outline:
			m = maxf(m, absf(p.y))
	return m if m > 0.0 else 30.0

## Two-link IK for the wrist at `w`: the elbow on the upper side for either hand. Right
## over the turntable it blends through straight, the only way a flat arm changes sides.
func elbow_for(w: Vector2) -> Vector2:
	var to := w - shoulder
	var d := clampf(to.length(), absf(upper_length - fore_length) + 1.0, upper_length + fore_length - 0.5)
	var a := to.angle()
	var off := acos(clampf((upper_length * upper_length + d * d - fore_length * fore_length) / (2.0 * upper_length * d), -1.0, 1.0))
	var k := clampf(to.x / 30.0, -1.0, 1.0)
	return shoulder + Vector2.from_angle(a - off * k) * upper_length

## The wrist as the arm can actually put it: `w`, pulled in to the arm's reach.
func reachable(w: Vector2) -> Vector2:
	var to := w - shoulder
	var d := clampf(to.length(), absf(upper_length - fore_length) + 1.0, upper_length + fore_length - 0.5)
	return shoulder + to.normalized() * d

## The glide slope lamps: dark until a laden ship is near. Then both green while the load is
## level with the drop point; the top one goes red when it is too high, the bottom one when
## it is too low - the red lamp is the side it is off to. Top lamp first.
func slope_lamps() -> Array[Color]:
	var dark := Colors.MUSTARD_DARK
	if not is_working() or is_full() or state_machine.current_state is ClawDelivering:
		return [dark, dark]
	var f := laden_near()
	if f == null:
		return [dark, dark]
	var high := drop_point.y - pose_of(f).origin.y  # px above the drop point
	var top := Colors.RUST_RED if high > slope_band else Colors.SAGE
	var bottom := Colors.RUST_RED if high < -slope_band else Colors.SAGE
	return [top, bottom]

## The Component a laden ship is carrying within `warn_radius` of the drop point, or null.
## Nothing on the strip lights up without one.
func laden_near() -> Freight:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null or not ship.is_carrying() or ship.freight == null or ship.freight.component == "":
		return null
	var f := ship.freight
	return f if pose_of(f).origin.distance_to(drop_point) <= warn_radius else null

## What the glide slope lamps say, in words: "HIGH", "LEVEL", "LOW" or "DARK".
func slope_reading() -> String:
	var lamps := slope_lamps()
	if lamps[0] == Colors.MUSTARD_DARK:
		return "DARK"
	if lamps[0] == Colors.RUST_RED:
		return "HIGH"
	return "LOW" if lamps[1] == Colors.RUST_RED else "LEVEL"

## Whether the bay can take a load: the claw working, and not busy with one.
func is_open() -> bool:
	return is_working() and not is_full()

## Whether the bay's beam shines. The bay stays dark and shut-looking until a laden ship is
## near; then it lights, and stays lit through the reach and the swing until the claw sets
## the load down on the pad.
func beam_on() -> bool:
	if not is_working() or _bay_busy:
		return false
	var s := state_machine.current_state
	if s is ClawReaching or s is ClawDelivering:
		return true
	if s is ClawStowing:
		return false
	return laden_near() != null

## Take the load on the pad below, through the deck, then bring the pad back up for the next.
func sink() -> void:
	if piece == null or not is_instance_valid(piece):
		return
	_bay_busy = true
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "pad_drop", sink_depth, sink_time)
	t.tween_callback(func() -> void:
		var id := piece.component
		piece.queue_free()
		piece = null
		Mount.clunk(self, Vector2((bay_left + bay_right) * 0.5, deck_y))
		delivered.emit(id))
	t.tween_interval(reset_time)
	t.tween_callback(func() -> void:
		pad_drop = 0.0
		_bay_busy = false)

# --- drawing -----------------------------------------------------------------------------

func _slab(c: CanvasItem, r: Rect2, tone: Color, ch := 4.0) -> void:
	var a := r.position
	var b := r.end
	ch = minf(ch, minf(r.size.x, r.size.y) * 0.5)
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(a.x + ch, a.y), Vector2(b.x - ch, a.y), Vector2(b.x, a.y + ch), Vector2(b.x, b.y - ch),
		Vector2(b.x - ch, b.y), Vector2(a.x + ch, b.y), Vector2(a.x, b.y - ch), Vector2(a.x, a.y + ch),
	]), tone)
	c.draw_rect(Rect2(a.x + ch, a.y, r.size.x - ch * 2.0, 2.0), Colors.HULL_LIGHT * Color(1, 1, 1, 0.75))

func _draw_pad(c: CanvasItem) -> void:
	var y := deck_y + pad_drop
	_slab(c, Rect2(pad_left, y, bay_right - 2.0 - pad_left, 8.0), Colors.HULL_MID, 2.0)
	c.draw_rect(Rect2((pad_left + bay_right) * 0.5 - 4.0, y + 8.0, 8.0, 200.0), Colors.HULL_DARK)

## The bay's light, shining up out of the hatch while it can take a load.
func _draw_beam(c: CanvasItem) -> void:
	if beam <= 0.01:
		return
	var glow := Colors.PRIMARY
	var base := glow * Color(1, 1, 1, 0.07 * beam)
	var gone := glow * Color(1, 1, 1, 0.0)
	var h := 110.0
	c.draw_polygon(PackedVector2Array([
		Vector2(bay_left + 4.0, deck_y), Vector2(bay_right - 4.0, deck_y),
		Vector2(bay_right + 18.0, deck_y - h), Vector2(bay_left - 18.0, deck_y - h),
	]), PackedColorArray([base, base, gone, gone]))
	var core := glow * Color(1, 1, 1, 0.04 * beam)
	var mid := (bay_left + bay_right) * 0.5
	c.draw_polygon(PackedVector2Array([
		Vector2(mid - 26.0, deck_y), Vector2(mid + 26.0, deck_y),
		Vector2(mid + 34.0, deck_y - h * 0.8), Vector2(mid - 34.0, deck_y - h * 0.8),
	]), PackedColorArray([core, core, gone, gone]))

## The hatch rim, lit from below with the beam; the glide slope lamps on the mast.
func _draw_lamps(c: CanvasItem) -> void:
	c.draw_rect(Rect2(bay_left, deck_y, bay_right - bay_left, 2.0), Colors.HULL_DARK.lerp(Colors.PRIMARY, beam * 0.45))
	var lamps := slope_lamps()
	for i in lamp_points.size():
		var at := lamp_points[i]
		var lit: Color = lamps[mini(i, 1)]
		c.draw_rect(Rect2(at.x - 7.0, at.y - 4.0, 7.0, 8.0), Colors.HULL_DARK)
		if lit != Colors.MUSTARD_DARK:
			c.draw_circle(at, 7.0, lit * Color(1, 1, 1, 0.18))
		c.draw_circle(at, 3.2, lit)
	if show_tolerance:
		for i in 28:
			if i % 2 == 0:
				c.draw_arc(drop_point, catch_radius, TAU * i / 28, TAU * (i + 1) / 28, 3, Colors.PRIMARY_FADED, 1.0)

func _draw_arm(c: CanvasItem) -> void:
	if not arm_home():
		return
	var w := reachable(wrist)
	var e := elbow_for(w)
	var up := e - shoulder
	var side := Vector2(up.y, -up.x).normalized() * 9.0
	c.draw_line(Vector2(16, deck_y - 18.0), shoulder.lerp(e, 0.5), Colors.HULL_LIGHT, 4.0)
	c.draw_line(shoulder, e, Colors.HULL_MID, 18.0)
	c.draw_line(shoulder, e, Colors.HULL_DARK, 3.0)
	c.draw_line(shoulder.lerp(e, 0.7) + side, e.lerp(w, 0.35), Colors.HULL_LIGHT, 3.0)
	c.draw_line(e, w, Colors.HULL_MID, 14.0)
	c.draw_line(e, w, Colors.HULL_DARK, 2.5)
	c.draw_circle(e, 11.0, Colors.HULL_DARK)
	c.draw_circle(e, 4.0, Colors.HULL_LIGHT)
	c.draw_circle(shoulder, 13.0, Colors.HULL_DARK)
	c.draw_circle(shoulder, 5.0, Colors.HULL_LIGHT)
	var busy := not state_machine.current_state is ClawStowed
	var blink := busy and int(Time.get_ticks_msec() / 350) % 2 == 0
	c.draw_circle(Vector2(0, deck_y - 10.0), 2.6, Colors.PRIMARY if blink else Colors.MUSTARD_DARK)
	# The claw: palm and two jaws
	c.draw_set_transform(w, claw_angle)
	_slab(c, Rect2(-10, -14, 18, 28), Colors.HULL_MID, 3.0)
	var s := lerpf(JAW_OPEN, JAW_SHUT, jaw)
	c.draw_rect(Rect2(8, -s * 0.5 - 6.0, 6, s + 12.0), Colors.HULL_DARK)
	for sd in [-1.0, 1.0]:
		var yi: float = sd * s * 0.5
		c.draw_rect(Rect2(8, minf(yi, yi + sd * 7.0), 36, 7), Colors.HULL_MID)
		c.draw_rect(Rect2(36, minf(yi, yi - sd * 2.0), 8, 2), Colors.HULL_LIGHT)
	c.draw_circle(Vector2(-1, 0), 2.2, Colors.PRIMARY if jaw > 0.95 else Colors.MUSTARD_DARK)
	c.draw_set_transform(Vector2.ZERO)
