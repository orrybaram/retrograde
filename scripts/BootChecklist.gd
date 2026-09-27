extends RefCounted
class_name BootChecklist

## The ship's manual diagnostic, run once on a new game (docs/OPENING.md §6, the boot text
## channel): a short terminal log that says the controls are locked for testing, releases
## them a system at a time, and stamps each [ OK ] the first time the pilot uses it. It is the model only - what is listed, what is done, how far
## each row has typed - so it can be tested without a scene. `BootLog` feeds it from the
## ship and draws it on the HUD.
##
## Sections unfold: FLIGHT from the start, the rest typed in under it when their moment
## comes (SONAR just outside a Sweep's reach of Freight, MAGNET at the Lug, LATERAL a beat
## after a pickup, RELEASE carrying a Section close to its Mount). A check already done by then types in and stamps straight away. A
## section whose rows are all OK clears a moment later, so the log only ever holds what is
## still to do; its system name joins the running list of passes under the header. Once
## every section has cleared it prints DIAGNOSTIC ... PASS, holds, and
## is done. A section's controls come back (ControlLock, via BootLog) once its heading has
## typed: `is_live`.

## Marks `use()` understands. Each is set once and never cleared.
const THRUST := &"thrust"
const REVERSE := &"reverse_thrust"
const TURN_LEFT := &"turn_left"
const TURN_RIGHT := &"turn_right"
const SWEEP := &"sweep"
const CLAMP := &"clamp"
const STRAFE_LEFT := &"strafe_left"
const STRAFE_RIGHT := &"strafe_right"
## The load was let go of.
const RELEASE := &"release"
## A Section went home: that passes RELEASE.
const SEATED := &"seated"

const FLIGHT := "flight"
const SONAR := "sonar"
const MAGNET := "magnet"
const LATERAL := "lateral"
const LET_GO := "let_go"
const ORDER: Array[String] = [FLIGHT, SONAR, MAGNET, LATERAL, LET_GO]

## Each check lists the actions whose keys it shows; `needs` is what stamps it: every mark
## in `all`, or any one in `any`.
const SECTIONS := {
## Headings name the hardware under test, rows the control that exercises it.
	FLIGHT: {"head": "PROPULSION", "checks": [
		{"id": "thrust", "label": "THRUST", "keys": [&"thrust"], "all": [THRUST]},
		{"id": "reverse", "label": "REVERSE", "keys": [&"reverse_thrust"], "all": [REVERSE]},
		{"id": "turn", "label": "YAW", "keys": [&"turn_left", &"turn_right"], "all": [TURN_LEFT, TURN_RIGHT]},
	]},
	SONAR: {"head": "SONAR", "checks": [
		{"id": "sweep", "label": "SWEEP", "keys": [&"action"], "all": [SWEEP]},
	]},
	MAGNET: {"head": "CLAMP", "checks": [
		{"id": "clamp", "label": "ENGAGE", "keys": [&"action"], "all": [CLAMP], "hold": true},
	]},
	LATERAL: {"head": "RCS", "checks": [
		{"id": "strafe", "label": "STRAFE", "keys": [&"strafe_left", &"strafe_right"], "all": [STRAFE_LEFT, STRAFE_RIGHT]},
	]},
	LET_GO: {"head": "CLAMP RELEASE", "checks": [
		{"id": "release", "label": "RELEASE", "keys": [&"action"], "any": [RELEASE, SEATED], "hold": true},
	]},
}

## Status lines are fields - a name, dots, and a value right-aligned under the stamps.
const CONTACT := ["CONTACT", "FREIGHT"]
## Heads the log until the diagnostic is done: what this is, and who has the controls.
const TITLE := "MANUAL DIAGNOSTIC"
const AUTHORITY := "CTRL AUTH"
const HELD_BY := "SYSTEM"
const HANDED_TO := "PILOT"
const RESULT := ["DIAGNOSTIC", "PASS"]
const INTRO := "intro"
## Where a cleared section's system name is listed, under the header, for good.
const PASSED := "passed"
## Who holds the controls is an aside: smaller than the log, and dim.
const SMALL_SIZE := 9

## Label and its dots fill this many columns, then the keys, then the stamp.
const LABEL_COL := 14
const KEY_COL := 14
const STAMP_WAIT := "[ -- ]"
const STAMP_OK := "[ OK ]"
const HOLD_CELLS := 4
const CURSOR := "█"
const CURSOR_HZ := 2.0

## Characters typed per second; one row types at a time, in order.
const TYPE_RATE := 55.0
## A finished row waits this long after it has typed before it stamps, so the tick is seen.
const STAMP_DELAY := 0.25
## A row still waiting after this long flickers once every NUDGE_EVERY seconds.
const NUDGE_AFTER := 7.0
const NUDGE_EVERY := 6.0
const NUDGE_FOR := 1.4
## A finished section stays up this long after its last stamp (or SONAR's contact), then clears.
const CLEAR_DELAY := 1.2
## How long the result holds before the log is finished.
const COMPLETE_HOLD := 3.5

enum Kind { BLANK, HEAD, CHECK, FIELD, TITLE }

var time := 0.0
## How far the hold in progress has got (0-1): the magnet's pull, or the release. A hold
## row's stamp fills with it.
var hold_progress := 0.0
var _rows: Array[Dictionary] = []
var _used := {}
var _open := {}
var _done := {}  # check id -> when it stamped
var _cleared := {}
var _contact := false
var _contact_at := -1.0
var _complete_at := -1.0
var _label_of: Callable


## `label_of(action) -> String` names an action's key; Controls.label by default.
func _init(label_of := Callable()) -> void:
	_label_of = label_of if label_of.is_valid() else Controls.label
	_add(Kind.TITLE, INTRO, TITLE)
	_add_field(INTRO, AUTHORITY, HELD_BY, Colors.PRIMARY_DIM, true)


func open(section: String) -> void:
	if _open.has(section) or not SECTIONS.has(section):
		return
	_open[section] = true
	if not _rows.is_empty():
		_add(Kind.BLANK, section)
	_add(Kind.HEAD, section, SECTIONS[section]["head"])
	for c in SECTIONS[section]["checks"]:
		var row := _add(Kind.CHECK, section)
		row["check"] = c
	if section == SONAR and _contact:
		_add_contact()


func is_open(section: String) -> bool:
	return _open.has(section)


## Open, and its heading has typed: its controls are back.
func is_live(section: String) -> bool:
	if _cleared.has(section):
		return true
	for row in _rows:
		if row["section"] == section and row["kind"] == Kind.HEAD:
			return row["shown"] >= _text_of(row).length()
	return false


func use(mark: StringName) -> void:
	_used[mark] = true


func is_used(mark: StringName) -> bool:
	return _used.has(mark)


func is_done(check_id: String) -> bool:
	return _done.has(check_id)


## Done and gone from the log.
func is_cleared(section: String) -> bool:
	return _cleared.has(section)


## A Sweep reached Freight: one CONTACT line under SWEEP, whenever SONAR is open.
func contact() -> void:
	if _contact:
		return
	_contact = true
	_contact_at = time
	if _open.has(SONAR) and not _cleared.has(SONAR):
		_add_contact()


func tick(dt: float) -> void:
	time += dt
	for row in _rows:
		row["reached"] = true  # typing has got this far down
		var length := _text_of(row).length()
		if row["shown"] < length:
			row["shown"] = minf(row["shown"] + TYPE_RATE * dt, length)
			break
	for row in _rows:
		if row["kind"] != Kind.CHECK or _done.has(row["check"]["id"]):
			continue
		if not _typed(row) or time - row["typed_at"] < STAMP_DELAY:
			continue
		if _passes(row["check"]):
			_done[row["check"]["id"]] = time
	_clear_finished()
	if _complete_at < 0.0 and _all_cleared():
		_complete_at = time
		# The header and the list of passes stay; the controls change hands
		_rows.assign(_rows.filter(func(r: Dictionary) -> bool: return r["kind"] == Kind.TITLE or r["section"] == PASSED))
		_add(Kind.BLANK, "")
		_add_field("", RESULT[0], RESULT[1], Colors.SUCCESS)
		_add_field("", AUTHORITY, HANDED_TO, Colors.PRIMARY_DIM, true)


## Every section open and every row stamped: the complete line is up.
func is_complete() -> bool:
	return _complete_at >= 0.0


## Complete, and its last line held long enough to read: the log can go.
func is_finished() -> bool:
	if not is_complete() or not _typed(_rows[-1]):
		return false
	return time - _rows[-1]["typed_at"] >= COMPLETE_HOLD


## The log as BBCode, as far as it has typed.
func render() -> String:
	return _render(true)


## The same, as plain text: what a player reads.
func plain() -> String:
	return _render(false)


# --- Rows --------------------------------------------------------------------

func _add(kind: Kind, section: String, text := "") -> Dictionary:
	var row := {"kind": kind, "section": section, "text": text, "shown": 0.0, "born": time, "typed_at": -1.0}
	_rows.append(row)
	return row


func _add_contact() -> void:
	var at := _rows.size()
	for i in _rows.size():
		if _rows[i]["kind"] == Kind.CHECK and _rows[i]["check"]["id"] == "sweep":
			at = i + 1
	var row := _add_field(SONAR, CONTACT[0], CONTACT[1], Colors.TEXT)
	_rows.erase(row)
	_rows.insert(at, row)


func _add_field(section: String, name: String, value: String, ink: Color, small := false) -> Dictionary:
	var row := _add(Kind.FIELD, section, name)
	row["value"] = value
	row["ink"] = ink
	row["small"] = small
	return row


func _typed(row: Dictionary) -> bool:
	if row["typed_at"] < 0.0 and row["shown"] >= _text_of(row).length():
		row["typed_at"] = time
	return row["typed_at"] >= 0.0


func _passes(check: Dictionary) -> bool:
	if check.has("any"):
		return check["any"].any(func(m: StringName) -> bool: return _used.has(m))
	return check["all"].all(func(m: StringName) -> bool: return _used.has(m))


## Drop every open section whose rows have all been stamped for CLEAR_DELAY, with the
## blank line that set it off and its CONTACT line; the rows below close up.
func _clear_finished() -> void:
	for section in ORDER:
		if not _open.has(section) or _cleared.has(section):
			continue
		var last := -1.0
		var all_done := true
		for c in SECTIONS[section]["checks"]:
			if not _done.has(c["id"]):
				all_done = false
				break
			last = maxf(last, _done[c["id"]])
		if section == SONAR and _contact:
			# A contact landing now gets read first: its line has to type, then hold
			var contact := _rows.filter(func(r: Dictionary) -> bool: return r["kind"] == Kind.FIELD and r["section"] == SONAR)
			if not contact.is_empty() and not _typed(contact[0]):
				continue
			last = maxf(last, contact[0]["typed_at"] if not contact.is_empty() else _contact_at)
		if not all_done or time - last < CLEAR_DELAY:
			continue
		_cleared[section] = true
		_rows.assign(_rows.filter(func(r: Dictionary) -> bool: return r["section"] != section))
		# Listed under the header, after the passes before it
		var at := 0
		for i in _rows.size():
			if _rows[i]["section"] in [INTRO, PASSED]:
				at = i + 1
		var row := _add_field(PASSED, SECTIONS[section]["head"], STAMP_OK, Colors.SUCCESS)
		_rows.erase(row)
		_rows.insert(at, row)


func _all_cleared() -> bool:
	return ORDER.all(func(s: String) -> bool: return _cleared.has(s))


# --- Text --------------------------------------------------------------------

## A row as [text, color] runs.
func _segments(row: Dictionary) -> Array:
	match row["kind"]:
		Kind.BLANK:
			return []
		Kind.HEAD:
			return [[row["text"], Colors.PRIMARY_DIM]]
		Kind.TITLE:
			return [[row["text"], Colors.PRIMARY]]
		Kind.FIELD:
			var runs := field(row["text"], row["value"], row["ink"])
			if row.get("small", false):
				for run in runs:
					run[1] = Colors.PRIMARY_DIM
			return runs
	var c: Dictionary = row["check"]
	var done := _done.has(c["id"])
	var ink := Colors.PRIMARY_DIM if done else Colors.PRIMARY
	var out: Array = [
		[c["label"] + " ", ink],
		[".".repeat(LABEL_COL - c["label"].length() - 1) + " ", Colors.PRIMARY_DIM],
	]
	var key_len := 0
	if c.get("hold", false):
		out.append(["HOLD ", ink])
		key_len += 5
	for action in c["keys"]:
		var key := "[%s]" % _label_of.call(action)
		var spent := done or _used.has(action)
		out.append([key, Colors.PRIMARY_DIM if spent else Colors.PRIMARY])
		key_len += key.length()
	out.append([" ".repeat(maxi(1, KEY_COL - key_len)), Colors.PRIMARY_DIM])
	if done:
		out.append([STAMP_OK, Colors.SUCCESS])
	elif c.get("hold", false) and hold_progress > 0.0:
		out.append([hold_meter(hold_progress), Colors.PRIMARY])
	else:
		out.append([STAMP_WAIT, Colors.PRIMARY_DIM])
	return out


## "CTRL AUTH ...... SYSTEM": the value ends in the stamps' column.
static func field(name: String, value: String, ink: Color) -> Array:
	var width := LABEL_COL + KEY_COL + STAMP_OK.length()
	var dots := maxi(2, width - name.length() - value.length() - 2)
	return [[name + " ", Colors.PRIMARY], [".".repeat(dots) + " ", Colors.PRIMARY_DIM], [value, ink]]


func _text_of(row: Dictionary) -> String:
	var s := ""
	for seg in _segments(row):
		s += seg[0]
	return s


## The magnet's pull as the stamp: "[██··]".
static func hold_meter(progress: float) -> String:
	var filled := clampi(roundi(progress * HOLD_CELLS), 0, HOLD_CELLS)
	return "[" + "█".repeat(filled) + "·".repeat(HOLD_CELLS - filled) + "]"


func _nudging(row: Dictionary) -> bool:
	if row["kind"] != Kind.CHECK or _done.has(row["check"]["id"]):
		return false
	var waited: float = time - row["born"]
	return waited > NUDGE_AFTER and fmod(waited - NUDGE_AFTER, NUDGE_EVERY) < NUDGE_FOR \
		and int(time * 5.0) % 2 == 0


func _render(bbcode: bool) -> String:
	var lines: PackedStringArray = []
	var cursor_on := fmod(time * CURSOR_HZ, 2.0) < 1.0
	var typist: Dictionary = {}  # the one row typing now; rows after it wait unseen
	for row in _rows:
		var typing: bool = row["shown"] < _text_of(row).length()
		if not typist.is_empty() and (typing or not row.get("reached", false)):
			continue
		if typing:
			typist = row
		# A typed row shows whole, even if a device swap has since made it longer
		var budget := int(row["shown"]) if typing else 1 << 30
		var line := ""
		var nudge := _nudging(row)
		for seg in _segments(row):
			if budget <= 0:
				break
			var part: String = seg[0].substr(0, budget)
			budget -= part.length()
			var ink: Color = Colors.PRIMARY_DIM if nudge else seg[1]
			line += "[color=#%s]%s[/color]" % [Colors.hex(ink), _escape(part)] if bbcode else part
		if typing or (row == _rows[-1] and is_complete() and cursor_on):
			line += "[color=#%s]%s[/color]" % [Colors.hex(Colors.PRIMARY), CURSOR] if bbcode else CURSOR
		if bbcode and row.get("small", false):
			line = "[font_size=%d]%s[/font_size]" % [SMALL_SIZE, line]
		lines.append(line)
	return "\n".join(lines)


static func _escape(s: String) -> String:
	return s.replace("[", "\u0001").replace("]", "[rb]").replace("\u0001", "[lb]")
