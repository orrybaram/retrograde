extends RefCounted
class_name TrackingSolution

## Snapshot of where a target is relative to an observer and how the two are
## moving. Pure math, so it can drive the HUD, autopilots, or AI alike.

## Below this closing speed the ETA is reported as unknown.
const MIN_CLOSING_SPEED := 1.0

var offset := Vector2.ZERO             ## target - observer
var distance := 0.0
var direction := Vector2.RIGHT         ## unit vector toward the target
var relative_velocity := Vector2.ZERO  ## observer velocity minus target velocity
var closing_speed := 0.0               ## > 0 approaching, < 0 moving away
var drift_speed := 0.0                 ## sideways speed; > 0 drifting clockwise of the target line
var eta := INF                         ## seconds to arrival at current closing speed

static func solve(from_pos: Vector2, from_vel: Vector2, to_pos: Vector2, to_vel: Vector2) -> TrackingSolution:
	var s := TrackingSolution.new()
	s.offset = to_pos - from_pos
	s.distance = s.offset.length()
	if s.distance > 0.0:
		s.direction = s.offset / s.distance
	s.relative_velocity = from_vel - to_vel
	s.closing_speed = s.relative_velocity.dot(s.direction)
	s.drift_speed = s.relative_velocity.dot(s.direction.orthogonal())
	if s.closing_speed >= MIN_CLOSING_SPEED:
		s.eta = s.distance / s.closing_speed
	return s

## Angle (radians) between the relative velocity and the line to the target.
## 0 = dead on course, PI = flying straight away.
func course_error() -> float:
	if relative_velocity.is_zero_approx():
		return PI
	return absf(relative_velocity.angle_to(direction))

static func format_distance(d: float) -> String:
	if d < 1000.0:
		return "%d m" % int(round(d))
	return "%.1f km" % (d / 1000.0)

static func format_eta(seconds: float) -> String:
	if is_inf(seconds) or seconds > 5999.0:
		return "--:--"
	var total := int(round(seconds))
	return "%d:%02d" % [total / 60, total % 60]
