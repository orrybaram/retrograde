class_name RobotFaces
extends RefCounted

## ASCII faces shown on the robot's screen. Every face is ROWS rows of WIDTH chars:
## row 0 = eyes, row 1 = mouth. The case around the screen is drawn by RobotView.

const WIDTH := 7
const ROWS := 2

const FACES := {
	&"neutral": [" O   O ", "   -   "],
	&"happy": [" ^   ^ ", "  \\_/  "],
	&"talking": [" O   O ", "   o   "],
	&"wink": [" ^   - ", "  \\_/  "],
	&"worried": [" o   o ", "  ~~~  "],
	&"surprise": [" O   O ", "   0   "],
	&"dead": [" X   X ", "  ___  "],
	&"glitch": [" 0 #  O", " _/-\\% "],
	&"lost": [" %   # ", "  ###  "],
	&"hello": [" HELLO ", " PILOT "],
	&"loading": ["       ", "[==-  ]"],
	&"sleep": [" -   - ", "     z "],
	&"titan": [" @   @ ", "  ---  "],
}

## Mouth frames cycled while the robot is talking.
const TALK_MOUTHS := ["   -   ", "   o   ", "   O   ", "   o   "]

## Characters that read as open eyes and close to "-" on a blink.
const BLINKABLE := "Oo0^@"

const GLITCH_CHARS := "#%&$/\\|_-=+*"

static func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for key in FACES:
		out.append(key)
	return out

static func has_face(face: StringName) -> bool:
	return FACES.has(face)

static func rows_for(face: StringName) -> PackedStringArray:
	return PackedStringArray(FACES.get(face, FACES[&"neutral"]))

## Faces that are words or a progress bar shouldn't blink or lip-sync.
static func is_text_face(face: StringName) -> bool:
	return face == &"hello" or face == &"loading"

## `rows` with the eyes shut.
static func blink(rows: PackedStringArray) -> PackedStringArray:
	var out := rows.duplicate()
	var eyes := out[0]
	for i in eyes.length():
		if BLINKABLE.contains(eyes[i]):
			eyes[i] = "-"
	out[0] = eyes
	return out

## `rows` with the mouth swapped for talk frame `frame` (wraps).
static func talk(rows: PackedStringArray, frame: int) -> PackedStringArray:
	var out := rows.duplicate()
	out[1] = TALK_MOUTHS[posmod(frame, TALK_MOUTHS.size())]
	return out

## `rows` with roughly `amount` (0..1) of the characters replaced by noise.
static func corrupt(rows: PackedStringArray, rng: RandomNumberGenerator, amount: float) -> PackedStringArray:
	var out := rows.duplicate()
	for r in out.size():
		var row := out[r]
		for i in row.length():
			if rng.randf() < amount:
				row[i] = GLITCH_CHARS[rng.randi() % GLITCH_CHARS.length()]
		out[r] = row
	return out
