extends Control
class_name ContactLog

## What the ship reads up close (Readout, docs/SWEEP.md §10), typed into the HUD's bottom-right
## corner in the manual diagnostic's grammar: a heading, then dot-leader rows whose values
## end in the diagnostic's stamp column. It grows upward from the corner, above UNIT-7's
## panel while that is up.
##
## Each read is an entry that types, holds and fades; the newest is at the bottom, nearest
## the corner, and the oldest goes when there are too many. A read of something already
## showing keeps its entry up: what is typed stays, only what has changed types on, and the
## hold starts over.

const TEXT_SIZE := BootLog.TEXT_SIZE
const OUTLINE := BootLog.OUTLINE
## The corner: RadioPanel's margins (clear of the action prompt and the save indicator),
## and the gap it keeps above that panel while it is up.
const SCREEN_MARGIN := RadioPanel.SCREEN_MARGIN
const GAP := 10.0
## Characters a second, the diagnostic's own rate.
const TYPE_RATE := BootChecklist.TYPE_RATE
## Seconds an entry stays once it has typed, and how long it takes to fade.
const HOLD := 6.0
const FADE_TIME := 0.8
const MAX_ENTRIES := 3

var radio: Control = null
var _stack: VBoxContainer
## Oldest first. Each: {id: the readout's instance id, label: RichTextLabel,
## lines: Array of lines, each an Array of [text, color] segments, length: chars, age}.
var _entries: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("contact_log")
	# Main.clear_screen_effects: a new game, a load or a quit to the menu clears it
	add_to_group("screen_effects")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", TEXT_SIZE)
	add_child(_stack)
	EventBus.readout_read.connect(show_read)
	visible = false


## Type out what `readout` read.
func show_read(readout: Node, rows: Array) -> void:
	var r := readout as Readout
	if r == null:
		return
	var lines := entry_lines(r.shown_heading(), r.shown_title(), rows, r.undecipherable)
	var id := r.get_instance_id()
	for entry in _entries:
		if entry.id == id:
			var shown := mini(int(entry.age * TYPE_RATE), entry.length)
			var kept := mini(shown, _common_prefix(_flat(entry.lines), _flat(lines)))
			entry.lines = lines
			entry.length = _length(lines)
			entry.age = kept / TYPE_RATE
			entry.label.modulate.a = 1.0
			entry.label.text = _render(lines, kept)
			return
	var entry := {"id": id, "label": _make_label(), "lines": lines, "length": _length(lines), "age": 0.0}
	_entries.append(entry)
	_stack.add_child(entry.label)
	while _entries.size() > MAX_ENTRIES:
		_drop(0)
	visible = true


## An entry's lines: `MOUNT / FUEL TANK`, then one `STATE ...... EMPTY` per row. Something of
## the Titan's (`titan`) is all in its purple but the leaders, which stay the ship's.
static func entry_lines(heading: String, title: String, rows: Array, titan := false) -> Array:
	var head := heading + " / " + title if heading != "" and title != "" else heading + title
	var lines: Array = [[[head, Colors.TITAN if titan else Colors.PRIMARY]]]
	for row in rows:
		var line: Array = BootChecklist.field(row.label, row.value, Colors.TITAN if titan else Colors.TEXT)
		if titan:
			line[0][1] = Colors.TITAN
		lines.append(line)
	return lines


## Where `readout`'s entry is, for ReadoutLock's tether: {point: the left end of its heading,
## in this log's canvas, alpha}. Empty when it has none.
func entry_state(readout: Node) -> Dictionary:
	var id := readout.get_instance_id()
	for entry in _entries:
		if entry.id == id:
			var label: RichTextLabel = entry.label
			return {
				"point": label.global_position + Vector2(0.0, TEXT_SIZE * 0.6),
				"alpha": label.modulate.a,
			}
	return {}


## What the log reads right now, as plain text: what a player sees typed so far.
func text() -> String:
	var out := PackedStringArray()
	for entry in _entries:
		out.append(entry.label.get_parsed_text())
	return "\n\n".join(out)


func clear_now() -> void:
	while not _entries.is_empty():
		_drop(0)
	visible = false


func _process(dt: float) -> void:
	if _entries.is_empty():
		return
	for i in range(_entries.size() - 1, -1, -1):
		var entry: Dictionary = _entries[i]
		entry.age += dt
		var typed_for: float = entry.length / TYPE_RATE
		var gone_at := typed_for + HOLD + FADE_TIME
		if entry.age >= gone_at:
			_drop(i)
			continue
		entry.label.modulate.a = clampf((gone_at - entry.age) / FADE_TIME, 0.0, 1.0)
		entry.label.text = _render(entry.lines, int(entry.age * TYPE_RATE))
	if _entries.is_empty():
		visible = false
		return
	_place()


## Bottom right, growing upward: its bottom edge on the corner's margin, or a gap above
## UNIT-7's panel while that is up.
func _place() -> void:
	var box := _stack.get_combined_minimum_size()
	var bottom := get_parent_area_size().y - SCREEN_MARGIN.y
	if radio and radio.visible:
		bottom = radio.position.y - GAP
	_stack.size = box
	size = box
	position = Vector2(get_parent_area_size().x - SCREEN_MARGIN.x - box.x, bottom - box.y)


## `lines` as BBCode, cut off after `chars` characters have typed.
static func _render(lines: Array, chars: int) -> String:
	var out := PackedStringArray()
	for line in lines:
		if chars <= 0:
			break
		var typed := ""
		for seg in line:
			if chars <= 0:
				break
			var shown: String = seg[0].left(chars)
			chars -= seg[0].length()
			typed += "[color=#%s]%s[/color]" % [Colors.hex(seg[1]), shown.replace("[", "[lb]")]
		out.append(typed)
	return "\n".join(out)


## `lines` as the characters they type, in order.
static func _flat(lines: Array) -> String:
	var out := ""
	for line in lines:
		for seg in line:
			out += seg[0]
	return out


static func _common_prefix(a: String, b: String) -> int:
	var n := mini(a.length(), b.length())
	for i in n:
		if a[i] != b[i]:
			return i
	return n


static func _length(lines: Array) -> int:
	var n := 0
	for line in lines:
		for seg in line:
			n += seg[0].length()
	return n


func _make_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", TEXT_SIZE)
	label.add_theme_color_override("default_color", Colors.PRIMARY)
	label.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	label.add_theme_constant_override("outline_size", OUTLINE)
	# The same column as the diagnostic's, so the corner reads as one
	var font := label.get_theme_font("normal_font")
	if font:
		var width := BootChecklist.LABEL_COL + BootChecklist.KEY_COL + BootChecklist.STAMP_OK.length() + 1
		label.custom_minimum_size.x = font.get_string_size("0".repeat(width), HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	return label


func _drop(i: int) -> void:
	_entries[i].label.queue_free()
	_entries.remove_at(i)
