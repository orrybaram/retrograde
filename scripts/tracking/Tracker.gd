extends Node
class_name Tracker

## Holds the single target an entity is navigating toward.
## Any entity can own one; the player's lives on the NavSystem autoload.

signal target_changed(target: TrackingTarget)

var target: TrackingTarget = null

func track(new_target: TrackingTarget) -> void:
	if new_target == target:
		return
	target = new_target
	target_changed.emit(target)

func clear() -> void:
	track(null)

## True while the current target is still valid. Drops targets that have gone away.
func has_target() -> bool:
	if target and not target.is_valid():
		clear()
	return target != null

## Solution from an observer to the current target, or null when not tracking.
func solve_from(from_pos: Vector2, from_vel: Vector2) -> TrackingSolution:
	if not has_target():
		return null
	return TrackingSolution.solve(from_pos, from_vel, target.get_position(), target.get_velocity())
