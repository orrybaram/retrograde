extends Node2D
class_name ScanSweep

## Amber radar sweep around a planet being scanned. A beam turns around the planet from
## the surface out to the edge of the gravity field, starting at the ship's bearing and
## passing back over it REVOLUTIONS times during the scan, trailing a fading wake.
## A ring just off the surface fills in step with the scan, growing both ways from the
## ship's side so the part the player can see fills first. On completion the ring
## flashes, then everything fades; an abandoned scan just fades.

const REVOLUTIONS := 2.0
const WAKE := 1.4  # radians of fading wake behind the beam
const WAKE_SLICES := 16
const WAKE_ALPHA := 0.2
const BEAM_ALPHA := 0.85
const RIM_GAP := 40.0  # progress ring distance off the surface
const RIM_WIDTH := 10.0
const BEAM_WIDTH := 5.0
const FADE_IN := 0.25
const FADE_OUT := 0.6
const FLASH_TIME := 0.9

var planet: Planet = null
var progress := 0.0
var start_angle := -PI / 2.0  # the ship's bearing from the planet when the scan began

var _alpha := 0.0
var _finishing := false
var _completed := false
var _flash := 0.0

static func attach(target: Planet, ship_position: Vector2) -> ScanSweep:
	var sweep := ScanSweep.new()
	sweep.name = "ScanSweep"
	sweep.planet = target
	sweep.start_angle = (ship_position - target.global_position).angle()
	target.add_child(sweep)
	return sweep

## Stop sweeping: flash the full ring when `completed`, otherwise just fade.
func finish(completed: bool) -> void:
	_finishing = true
	_completed = completed
	if completed:
		progress = 1.0
		_flash = FLASH_TIME

func beam_angle() -> float:
	return start_angle + TAU * REVOLUTIONS * progress

func _process(delta: float) -> void:
	if not _finishing:
		_alpha = move_toward(_alpha, 1.0, delta / FADE_IN)
	elif _flash > 0.0:
		_flash -= delta
		_alpha = 1.0
	else:
		_alpha -= delta / FADE_OUT
		if _alpha <= 0.0:
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(planet):
		return
	var inner := planet.radius + RIM_GAP
	var outer := planet.field_radius()
	var a := clampf(_alpha, 0.0, 1.0)
	var beam := beam_angle()

	if not _completed:
		var wake := minf(WAKE, TAU * REVOLUTIONS * progress)
		for i in WAKE_SLICES:
			var a0 := beam - wake * (i + 1) / WAKE_SLICES
			var a1 := beam - wake * i / WAKE_SLICES
			var fade := 1.0 - float(i) / WAKE_SLICES
			draw_colored_polygon(PackedVector2Array([
				Vector2.from_angle(a0) * inner, Vector2.from_angle(a0) * outer,
				Vector2.from_angle(a1) * outer, Vector2.from_angle(a1) * inner,
			]), Color(Colors.PRIMARY, WAKE_ALPHA * fade * fade * a))
		draw_line(Vector2.from_angle(beam) * inner, Vector2.from_angle(beam) * outer,
				Color(Colors.PRIMARY, BEAM_ALPHA * a), BEAM_WIDTH)

	draw_arc(Vector2.ZERO, inner, 0.0, TAU, 160, Color(Colors.PRIMARY_DIM, 0.6 * a), RIM_WIDTH * 0.4)
	if progress > 0.0:
		var pulse := 0.5 + 0.5 * sin(_flash * 20.0) if _flash > 0.0 else 1.0
		var half := PI * progress
		draw_arc(Vector2.ZERO, inner, start_angle - half, start_angle + half, maxi(8, int(160 * progress)),
				Color(Colors.PRIMARY, a * pulse), RIM_WIDTH)
