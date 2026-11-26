extends AudioStreamPlayer
class_name FoundChime

## The two soft notes a discoverable thing answers a Sweep with (SonarGlow's found trace):
## a D, then the A above it a beat later, both sine and fading out. Made once, procedurally,
## the way the robot's blips are (RobotBeeper.tone).

const MIX_RATE := 22050
const LOW_HZ := 587.0
const HIGH_HZ := 880.0
## The second note comes in this long after the first; each rings this long.
const HIGH_DELAY := 0.1
const LOW_LENGTH := 0.3
const HIGH_LENGTH := 0.5
const LOW_AMPLITUDE := 0.45
const HIGH_AMPLITUDE := 0.4
const VOLUME_DB := -14.0

static var _stream: AudioStreamWAV

## The Dummy driver (headless) never mixes, so its playbacks never retire and leak at exit.
var _silent := AudioServer.get_driver_name() == "Dummy"

func _ready() -> void:
	volume_db = VOLUME_DB
	max_polyphony = 2

## A voice still playing at quit leaks its playback.
func _exit_tree() -> void:
	stop()

func chime() -> void:
	if _silent:
		return
	if stream == null:
		stream = notes()
	play()

## Both notes mixed into one clip: the low one at 0, the high one HIGH_DELAY later.
static func notes() -> AudioStreamWAV:
	if _stream:
		return _stream
	var total := int((HIGH_DELAY + HIGH_LENGTH) * MIX_RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		var t := float(i) / MIX_RATE
		var v := _note(t, LOW_HZ, LOW_LENGTH) * LOW_AMPLITUDE \
			+ _note(t - HIGH_DELAY, HIGH_HZ, HIGH_LENGTH) * HIGH_AMPLITUDE
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	_stream = AudioStreamWAV.new()
	_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_stream.mix_rate = MIX_RATE
	_stream.data = data
	return _stream

## A sine note `t` s in: a 6 ms rise, then an exponential fall to silence over `length`.
static func _note(t: float, hz: float, length: float) -> float:
	if t < 0.0 or t >= length:
		return 0.0
	var env := minf(1.0, t / 0.006) * exp(-5.0 * t / length) * (1.0 - t / length)
	return sin(TAU * hz * t) * env
