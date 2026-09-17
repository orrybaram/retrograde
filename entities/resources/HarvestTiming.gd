extends RefCounted
class_name HarvestTiming

## Hold-and-release timing for one scrap hit. The sweet zone lands somewhere new in
## the right half of the bar every time (unseeded, so it differs between sessions).
## Holding `action` sweeps progress 0 -> 1 over `duration`. Releasing inside the
## sweet zone completes the harvest (its centre slice is PERFECT). Releasing before
## the zone keeps progress, which decays while idle. Releasing after the zone, or
## holding all the way to 1.0, botches the harvest into Slag.

enum Grade { NONE, EARLY, GOOD, PERFECT, LATE, OVERLOAD }

const NORMAL_DURATION := 1.6
const TROPHY_DURATION := 2.0
const NORMAL_ZONE_WIDTH := 0.2
const TROPHY_ZONE_WIDTH := 0.13
const PERFECT_FRACTION := 0.34  # centre slice of the zone that grades PERFECT
const ZONE_MIN_START := 0.5
const ZONE_MAX_END := 0.92
const DECAY_PER_SEC := 0.35

var duration: float
var zone_start: float
var zone_end: float
var progress := 0.0

static var _session_rng: RandomNumberGenerator = null

func _init(rng: RandomNumberGenerator = null, trophy := false) -> void:
	duration = TROPHY_DURATION if trophy else NORMAL_DURATION
	var width := TROPHY_ZONE_WIDTH if trophy else NORMAL_ZONE_WIDTH
	var max_start := ZONE_MAX_END - width
	if not rng:
		if not _session_rng:
			_session_rng = RandomNumberGenerator.new()
			_session_rng.randomize()
		rng = _session_rng
	zone_start = rng.randf_range(ZONE_MIN_START, max_start)
	zone_end = zone_start + width

## Advance while held. Returns OVERLOAD once the bar is full, NONE otherwise.
func hold(delta: float) -> Grade:
	progress = minf(progress + delta / duration, 1.0)
	return Grade.OVERLOAD if progress >= 1.0 else Grade.NONE

## Grade for letting go right now.
func release() -> Grade:
	if progress >= 1.0:
		return Grade.OVERLOAD
	if progress < zone_start:
		return Grade.EARLY
	if progress > zone_end:
		return Grade.LATE
	return Grade.PERFECT if in_perfect() else Grade.GOOD

func decay(delta: float) -> void:
	progress = maxf(progress - DECAY_PER_SEC * delta, 0.0)

func perfect_start() -> float:
	return _zone_center() - _perfect_half()

func perfect_end() -> float:
	return _zone_center() + _perfect_half()

func in_zone() -> bool:
	return progress >= zone_start and progress <= zone_end

func in_perfect() -> bool:
	return progress >= perfect_start() and progress <= perfect_end()

func _zone_center() -> float:
	return (zone_start + zone_end) / 2.0

func _perfect_half() -> float:
	return (zone_end - zone_start) * PERFECT_FRACTION / 2.0
