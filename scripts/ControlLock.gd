extends RefCounted
class_name ControlLock

## Ship controls held off by the manual diagnostic (BootLog): each comes back when the test
## that covers it begins. Flight actions are named by their Controls id; the three uses of
## `action` by what they do, since one key carries all of them. Nothing is locked outside
## the diagnostic, and anything that ends it - finishing, a load, a new game, a quit - clears
## every lock, so a lock can never outlive the log that set it.

const SWEEP := &"sweep"
const CLAMP := &"clamp"
const RELEASE := &"release"

static var _locked := {}


static func lock(ids: Array) -> void:
	for id in ids:
		_locked[id] = true


static func unlock(ids: Array) -> void:
	for id in ids:
		_locked.erase(id)


static func clear() -> void:
	_locked.clear()


static func any() -> bool:
	return not _locked.is_empty()


static func allows(id: StringName) -> bool:
	return not _locked.has(id)
