class_name RobotBeeper
extends AudioStreamPlayer

## The robot's voice: short procedural square-wave blips, no speech (DESIGN.md 5.3).
## blip() per typed character, chirp() when a line starts. Pitch follows the mood.

const MIX_RATE := 22050
const BASE_HZ := 740.0
const BLIP_LENGTH := 0.035
const CHIRP_NOTE_LENGTH := 0.045
const MIN_BLIP_GAP_MS := 55
const VOLUME_DB := -22.0
const AMPLITUDE := 0.35
## Pitch multiplier per face; anything missing is 1.0.
const MOOD_PITCH := {
	&"happy": 1.2, &"hello": 1.2, &"wink": 1.15, &"surprise": 1.35,
	&"worried": 0.8, &"sleep": 0.7, &"dead": 0.6, &"titan": 0.65, &"lost": 0.55,
}
## Faces whose line-start chirp falls instead of rises (a sigh).
const SAD_MOODS := [&"worried", &"sleep", &"dead", &"lost"]

var _blip: AudioStreamWAV
var _chirp_up: AudioStreamWAV
var _chirp_down: AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var _last_blip_ms := -MIN_BLIP_GAP_MS
## The Dummy driver (headless) never mixes, so its playbacks never retire and leak at exit.
var _silent := AudioServer.get_driver_name() == "Dummy"

func _ready() -> void:
	_rng.randomize()
	volume_db = VOLUME_DB
	max_polyphony = 3
	_blip = tone([BASE_HZ], BLIP_LENGTH)
	_chirp_up = tone([BASE_HZ * 0.8, BASE_HZ * 1.2, BASE_HZ * 1.6], CHIRP_NOTE_LENGTH)
	_chirp_down = tone([BASE_HZ * 1.2, BASE_HZ, BASE_HZ * 0.7], CHIRP_NOTE_LENGTH)

## A voice still playing at quit leaks its playback.
func _exit_tree() -> void:
	stop()

## One square-wave note per frequency, back to back, each with a click-free envelope.
static func tone(freqs: Array, note_length: float) -> AudioStreamWAV:
	var n := int(note_length * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * freqs.size() * 2)
	var offset := 0
	for f in freqs:
		for i in n:
			var env := minf(1.0, i / 40.0) * (1.0 - float(i) / n)
			var square := 1.0 if fmod(float(i) * f / MIX_RATE, 1.0) < 0.5 else -1.0
			data.encode_s16(offset, int(square * env * AMPLITUDE * 32767.0))
			offset += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav

func blip(mood: StringName, glitchy: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_blip_ms < MIN_BLIP_GAP_MS:
		return
	_last_blip_ms = now
	var spread := 0.5 if glitchy else 0.1
	_play(_blip, _pitch(mood) * _rng.randf_range(1.0 - spread, 1.0 + spread))

func chirp(mood: StringName) -> void:
	_play(_chirp_down if mood in SAD_MOODS else _chirp_up, _pitch(mood))

func _pitch(mood: StringName) -> float:
	return MOOD_PITCH.get(mood, 1.0)

func _play(sound: AudioStreamWAV, pitch: float) -> void:
	if _silent:
		return
	if stream != sound:
		stream = sound
	pitch_scale = pitch
	play()
