extends RefCounted
## Base for one Gate look under test in the Gate Lab (`dev/GateLab.gd`).
##
## A style owns nothing but its drawing. Every variant keeps the same radius, the same
## mouth at the bottom and the same cradle across it, so docking never changes and only
## the construction is up for debate.
##
## Geometry that wants randomness (rough stone, carved runes) is built once in `_init`
## from a private seeded RandomNumberGenerator. Never the shared RNG autoload: that one
## rolls gameplay, and drawing from it shifts loot.

## Matches Gate.RADIUS / MOUTH_ANGLE / CRADLE_HALF so the lab reads at true scale.
const RADIUS := 100.0
const MOUTH_ANGLE := deg_to_rad(52.0)
const CRADLE_HALF := 44.0

## Short key used for screenshots and the lab's selector.
var id := ""
var title := ""
## One line on what this variant is arguing for.
var blurb := ""

## The arc the hull covers, and where it starts (clockwise from the bottom-left horn).
func span() -> float:
	return TAU - MOUTH_ANGLE

func start() -> float:
	return PI / 2.0 + MOUTH_ANGLE / 2.0

static func polar(angle: float, radius: float) -> Vector2:
	return Vector2(cos(angle), sin(angle)) * radius

## A private generator, stable across runs, so a variant looks the same every time.
static func seeded(text: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(text)
	return r

# --- Shared palette ----------------------------------------------------------

## Machined hull. Powering the Module lights what runs through the Gate, not the
## metal itself, so the hull only picks up the spill: enough to say the light is
## nearby, never enough to turn the thing into a purple ring.
func hull_of(glow: float) -> Color:
	return Colors.HULL_DARK.lerp(Colors.HULL_DARK.lerp(Colors.TITAN, 0.3), glow)

func rim_of(glow: float) -> Color:
	return Colors.HULL_MID.lerp(Colors.HULL_MID.lerp(Colors.TITAN, 0.45), glow)

## Rough rock: dustier and warmer than machined hull, and rock all the way through.
## It catches even less of the light than hull does.
func stone_of(glow: float) -> Color:
	return Colors.HULL_MID.darkened(0.18).lerp(
		Colors.HULL_MID.darkened(0.12).lerp(Colors.TITAN, 0.18), glow)

## What the light in the cracks is: one amber ember while dormant, the Titan's
## purple once it is running.
func signal_of(glow: float) -> Color:
	return Colors.PRIMARY.lerp(Colors.TITAN, glow)

# --- Shared parts ------------------------------------------------------------

## The Module's light bleeding out past the hull.
func draw_halo(c: CanvasItem, glow: float, outer: float) -> void:
	if glow <= 0.0:
		return
	for i in 3:
		c.draw_arc(Vector2.ZERO, outer + i * 5.0, start(), start() + span(), 72,
			Color(Colors.TITAN, glow * 0.22 / (i + 1.0)), 4.0, true)

## The cradle across the mouth: a bar the ship rests on, braced back to the ring.
## Styles that build in stone override this with their own bracing.
func draw_cradle(c: CanvasItem, glow: float) -> void:
	var hull := hull_of(glow)
	var rim := rim_of(glow)
	var left := Vector2(-CRADLE_HALF, RADIUS)
	var right := Vector2(CRADLE_HALF, RADIUS)
	c.draw_line(left, right, hull, 7.0)
	c.draw_line(left + Vector2(0, -4), right + Vector2(0, -4), rim, 1.0)
	for x in [-CRADLE_HALF + 6.0, CRADLE_HALF - 6.0]:
		c.draw_line(Vector2(x, RADIUS), Vector2(x * 1.25, RADIUS + 14.0), hull, 4.0)

## One slow amber blinker is all that is still running while dormant.
func draw_blinker(c: CanvasItem, glow: float, clock: float, at: Vector2 = Vector2(0, -RADIUS)) -> void:
	if glow >= 1.0:
		c.draw_circle(at, 5.0, Color(Colors.TITAN, 0.3))
		c.draw_circle(at, 2.5, Colors.TITAN)
		return
	var lit := fmod(clock, 2.4) < 2.4 * 0.18
	c.draw_circle(at, 4.0, Color(Colors.PRIMARY, 0.25 if lit else 0.06))
	c.draw_circle(at, 2.0, Colors.PRIMARY if lit else Colors.PRIMARY_DIM)

## A rough-edged slab: `pts` walked with a little wander so nothing reads machined.
func rough(points: PackedVector2Array, r: RandomNumberGenerator, amount: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + Vector2(r.randf_range(-amount, amount), r.randf_range(-amount, amount)))
	return out

## Three harmonics with random phase, summed. Sampling this along an edge gives rock
## that has been weathered — long swells and a chip here and there — where per-point
## randomness only ever gives sawtooth noise.
func make_wander(r: RandomNumberGenerator, amplitude: float) -> Array:
	var out: Array = []
	for i in 3:
		out.append({
			"a": amplitude * r.randf_range(0.35, 1.0) / (i + 1.0),
			"f": (i + 1) * r.randf_range(1.6, 3.4),
			"p": r.randf() * TAU,
		})
	return out

## Sample a wander at `t` (0..1 along the edge).
static func wander_at(w: Array, t: float) -> float:
	var v := 0.0
	for h in w:
		v += h["a"] * sin(h["f"] * t * TAU + h["p"])
	return v

## One character of the script: a stem with a few branches, drawn in a box about
## `height` tall and centred on its own origin. Placed flat against the ring by
## whoever is drawing it.
func make_rune(r: RandomNumberGenerator, height: float) -> Array:
	var strokes: Array = []
	strokes.append(PackedVector2Array([Vector2(0, -height / 2.0), Vector2(0, height / 2.0)]))
	for i in r.randi_range(1, 3):
		var y := r.randf_range(-height / 2.0 + 1.0, height / 2.0 - 1.0)
		var w := height * r.randf_range(0.28, 0.5) * (1.0 if r.randf() < 0.5 else -1.0)
		strokes.append(PackedVector2Array([Vector2(0, y), Vector2(w, y + r.randf_range(-2.5, 2.5))]))
	if r.randf() < 0.4:
		strokes.append(PackedVector2Array([
			Vector2(-height * 0.3, -height / 2.0 - 1.5),
			Vector2(height * 0.3, -height / 2.0 - 1.5)]))
	return strokes

# --- Contract ----------------------------------------------------------------

## Draw the whole Gate centred on the origin. `glow` is 0 dormant to 1 fully powered.
func draw_gate(_c: CanvasItem, _glow: float, _clock: float) -> void:
	pass
