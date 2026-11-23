extends RefCounted
class_name ShipLog

## The ship's own log: a short printout of what it has learned, one line an entry, newest
## last. Each entry is a time (mission time, `GameState.mission_time`), the subsystem that
## wrote it, and a field in the manual diagnostic's grammar - name, dots, value - with a
## status, shown only as a coloured dot at the start of the line:
##
##   T+00:00  SYS   SR-7 STATUS ........... CRITICAL   (err)
##   T+01:40  SONR  SOLAR ARRAY ............ LOCATED   (info)
##
## The Log's LOG tab lists it (ShipLogTab); the HUD only says it was updated (LogCue).
## GameState owns it, writes it (`write_log`) and Save keeps it. This is the model only.

const INFO := "info"
const WARN := "warn"
const ERR := "err"
## Who wrote an entry: the ship's systems, its sonar, SR-7's Mounts, the manual diagnostic.
const SYS := "SYS"
const SONAR := "SONR"
const MOUNT := "MNT"
const DIAG := "DIAG"
## Older entries go past this many.
const MAX_ENTRIES := 200

## Oldest first. Each: {at: float seconds, source, name, value, status}.
var entries: Array[Dictionary] = []
## How many entries the player has had the Log open on (ShipLogTab): the rest are NEW.
## Not saved; a load counts everything as seen.
var seen := 0


func add(at: float, source: String, name: String, value: String, status := INFO) -> Dictionary:
	var entry := {"at": at, "source": source, "name": name, "value": value, "status": status}
	entries.append(entry)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
		seen = maxi(seen - 1, 0)
	return entry


func is_new(index: int) -> bool:
	return index >= seen


func mark_seen() -> void:
	seen = entries.size()


func clear() -> void:
	entries.clear()
	seen = 0


## What Save writes: plain dictionaries.
func to_array() -> Array:
	return entries.duplicate(true)


## A log read back from `saved` (to_array), every entry already seen.
static func from_array(saved: Array) -> ShipLog:
	var out := ShipLog.new()
	for e in saved:
		if e is Dictionary:
			out.add(float(e.get("at", 0.0)), str(e.get("source", "")), str(e.get("name", "")),
				str(e.get("value", "")), str(e.get("status", INFO)))
	out.mark_seen()
	return out


## Mission time as the log prints it: T+MM:SS, or T+H:MM:SS past the hour.
static func stamp(at: float) -> String:
	var s := maxi(int(at), 0)
	if s >= 3600:
		return "T+%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "T+%02d:%02d" % [s / 60, s % 60]


static func status_color(status: String) -> Color:
	match status:
		WARN:
			return Colors.PRIMARY
		ERR:
			return Colors.DANGER
	return Colors.TEXT_MUTED
