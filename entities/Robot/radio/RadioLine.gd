class_name RadioLine
extends Resource

## One line of radio chatter. `{key:<action>}` in `text` becomes that action's key
## name (e.g. "{key:thrust}" -> "UP") so hints follow the input map, and `{name}`
## is filled from the conversation's `vars`.

const MIN_READ_TIME := 3.0
const MAX_READ_TIME := 9.0
const READ_SECONDS_PER_CHAR := 0.06

## Empty means the guide robot (RobotRadio.SPEAKER_NAME).
@export var speaker: String = ""
@export_multiline var text: String = ""
## A face name from RobotFaces.FACES.
@export var expression: StringName = &"neutral"
## Scramble the robot's face and beeps while this line plays.
@export var glitch: bool = false
## Non-empty makes this a confirm line: it shows `> <confirm>` and waits for the
## player to accept (RobotRadio.confirm). It can't be skipped or time out.
@export var confirm: String = ""

static func make(line_text: String, face: StringName = &"neutral", glitchy: bool = false, confirm_label: String = "") -> RadioLine:
	var line := RadioLine.new()
	line.text = line_text
	line.expression = face
	line.glitch = glitchy
	line.confirm = confirm_label
	return line

func is_confirm() -> bool:
	return confirm != ""

func speaker_name() -> String:
	return speaker if speaker != "" else RobotRadio.SPEAKER_NAME

func display_text(vars: Dictionary = {}) -> String:
	return _fill(text, vars)

func confirm_text(vars: Dictionary = {}) -> String:
	return _fill(confirm, vars)

static func _fill(template: String, vars: Dictionary) -> String:
	var regex := RegEx.create_from_string("\\{key:([a-z_]+)\\}")
	var out := template
	for m in regex.search_all(template):
		out = out.replace(m.get_string(), InputUtils.get_action_key_name(m.get_string(1)).to_upper())
	return out.format(vars) if not vars.is_empty() else out

## Seconds the finished line stays up before it auto-dismisses.
func read_time(vars: Dictionary = {}) -> float:
	return clampf(1.5 + display_text(vars).length() * READ_SECONDS_PER_CHAR, MIN_READ_TIME, MAX_READ_TIME)
