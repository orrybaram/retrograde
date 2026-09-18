class_name TitanInfluence

## How Titan Influence (`GameState.titan_influence()`, 0-5) shows itself outside the
## Gate terminal. Every Gate the player powers brings one more Module online, and the
## Titan leans on the ship a little harder from then on: the dashboard never reads
## quite clean again, and past halfway the guide's own face starts taking the Titan's
## color mid-sentence. None of it touches gameplay - it is all readouts and paint.
##
## Every knob lives here, and the arithmetic is static and pure, so the wrongness can
## be read and tested without a running HUD.

## Modules in the Titan, one per planet. The Core in the sun is a separate final
## state, not step 6.
const MODULES := 5

## What the dashboard's permanent glitch reaches with all five Modules online.
## Deliberately under `HudGlitch.ROT_THRESHOLD`: the Titan dims the readouts and cuts
## them out, but it never eats the characters. Five Modules in, the HUD is still a
## HUD you can fly on.
const MAX_BASELINE_GLITCH := 0.3

## How long the Titan holds the dashboard dark when it blinks it. Short enough to read
## as an interruption rather than a fault — the readouts are never wrong, just gone
## for a moment.
const BLINK_SEC := 0.05

## Seconds between blinks with one Module online, and with all five. This is what makes
## each Gate the player powers show up on the HUD: same blink, steadily more often.
const BLINK_GAP_FIRST := 12.0
const BLINK_GAP_FULL := 2.5

## How far either side of the gap a blink can land, so it never becomes a metronome.
const BLINK_GAP_SPREAD := 0.4

## From here on the guide is not entirely its own voice: half the Titan is awake.
const FACE_MIN_INFLUENCE := 3

## Roughly every second line bleeds through.
const FACE_FLASH_CHANCE := 0.5

## A frame or two at 60fps - long enough to catch, too short to be sure of.
const FACE_FLASH_SEC := 0.05

## The floor under the dashboard glitch: nothing before the first Gate, one step more
## with every Module that comes online, and it never goes back down.
static func baseline_glitch(influence: int) -> float:
	return MAX_BASELINE_GLITCH * clampf(float(influence) / float(MODULES), 0.0, 1.0)

## Seconds to wait between blinks of the dashboard, shorter with every Module online,
## and INF while the Titan is still entirely powered down.
static func blink_gap(influence: int) -> float:
	if influence <= 0:
		return INF
	var t := clampf(float(influence - 1) / float(MODULES - 1), 0.0, 1.0)
	return lerpf(BLINK_GAP_FIRST, BLINK_GAP_FULL, t)

## Whether the Titan is far enough awake to reach the guide's face at all.
static func bleeds_into_the_guide(influence: int) -> bool:
	return influence >= FACE_MIN_INFLUENCE

## Whether this particular radio line flashes the Titan's color. `rng` is the caller's
## own generator, never `RNG.rng` - that one rolls gameplay.
static func flashes_titan_face(influence: int, rng: RandomNumberGenerator) -> bool:
	return bleeds_into_the_guide(influence) and rng.randf() < FACE_FLASH_CHANCE
