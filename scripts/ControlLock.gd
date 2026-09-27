extends RefCounted
class_name ControlLock

## Ship controls held off by the manual diagnostic (BootLog): each comes back when the test
## that covers it begins. Flight actions are named by their Controls id; the three uses of
## `action` by what they do, since one key carries all of them. Nothing is locked outside
## the diagnostic, and anything that ends it - finishing, a load, a new game, a quit - clears
## every lock, so a lock can never outlive the log that set it.

## While the system holds control the ship's thrust is held to this speed, measured in
## `frame_velocity`'s frame (SR-7's: the station, the tank and its Mount all move in it).
const SYSTEM_SPEED := 50.0

const SWEEP := &"sweep"
const CLAMP := &"clamp"
const RELEASE := &"release"

static var _locked := {}
## INF when nothing is capped; SYSTEM_SPEED while the diagnostic holds control.
static var speed_cap := INF
static var frame_velocity := Vector2.ZERO


static func lock(ids: Array) -> void:
	for id in ids:
		_locked[id] = true


static func unlock(ids: Array) -> void:
	for id in ids:
		_locked.erase(id)


static func clear() -> void:
	_locked.clear()
	speed_cap = INF
	frame_velocity = Vector2.ZERO


static func is_capped() -> bool:
	return speed_cap < INF


static func any() -> bool:
	return not _locked.is_empty()


static func allows(id: StringName) -> bool:
	return not _locked.has(id)
