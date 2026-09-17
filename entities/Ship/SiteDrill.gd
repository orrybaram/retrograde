extends Node2D
class_name SiteDrill

## The ship's drill while it sits on a landing site. Owned by PlanetLandedState.
## A dig is LAYERS (RICH_LAYERS on rich sites) HarvestTiming sweeps in a row: hold
## `action` to sweep, release in the zone to break a layer and throw its gems into the
## hold's magnet. Deeper layers roll better gems, narrower zones on the last ones.
## An early release keeps (decaying) progress. Holding to OVERLOAD ends the dig with
## drill kickback. Between layers the player can bank (stop) and keep what was dug.
## Every finished dig spends the site; a spent site can't be drilled (phase starts DONE).
## Draws the drill bit and dust under the ship while it bites.

enum Phase { READY, DIGGING, DONE }

const LAYERS := 3
const RICH_LAYERS := 4
const TROPHY_DEPTH := 3  # layers this deep get the narrow timing zone
const KICKBACK_DAMAGE := 8.0
const BIT_START := 12.0  # ship tail, local -x
const BIT_LENGTH := 16.0
const DUST_COLOR := Colors.HULL_LIGHT

var site: LandingSite = null
var ship: Ship = null
var rng: RandomNumberGenerator = null
var phase := Phase.READY
var layer := 0  # layers broken so far
var timing: HarvestTiming = null
var dug: Array[String] = []  # every gem id dug this dig
var end_reason := ""

var _holding := false
var _dust: CPUParticles2D

static func attach(landed_ship: Ship, landing_site: LandingSite) -> SiteDrill:
	var drill := SiteDrill.new()
	drill.name = "SiteDrill"
	drill.ship = landed_ship
	drill.site = landing_site
	landed_ship.add_child(drill)
	return drill

func _ready() -> void:
	z_index = -1
	if not rng:
		rng = RNG.rng
	if site and site.is_spent():
		phase = Phase.DONE
		end_reason = "spent"
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.amount = 24
	_dust.lifetime = 0.6
	_dust.position = Vector2(-BIT_START, 0)
	_dust.direction = Vector2.LEFT
	_dust.spread = 70.0
	_dust.initial_velocity_min = 20.0
	_dust.initial_velocity_max = 60.0
	_dust.gravity = Vector2.ZERO
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.5
	_dust.color = DUST_COLOR
	add_child(_dust)

func layer_count() -> int:
	return RICH_LAYERS if site and site.rich else LAYERS

func depth() -> int:
	return layer + (1 if site and site.rich else 0)

func is_holding() -> bool:
	return _holding

## True between layers of a dig that has dug something (the player may bank).
func can_bank() -> bool:
	return phase == Phase.DIGGING and layer > 0 and not _holding

## Advance with the `action` key held or not. Called by PlanetLandedState each tick.
func tick(delta: float, holding: bool) -> void:
	if phase == Phase.DONE:
		_set_holding(false)
		return
	if phase == Phase.READY:
		if not holding:
			return
		phase = Phase.DIGGING
		_new_timing()
	if holding:
		_set_holding(true)
		if timing.hold(delta) == HarvestTiming.Grade.OVERLOAD:
			_overload()
		return
	if not _holding:
		timing.decay(delta)
		return
	_set_holding(false)
	var grade := timing.release()
	if grade != HarvestTiming.Grade.EARLY:
		_strike(grade)

## Stop between layers and keep what was dug. With nothing dug yet the drill just resets.
func bank() -> void:
	if can_bank():
		_end("bank")
	elif phase == Phase.DIGGING and layer == 0 and not _holding:
		phase = Phase.READY
		timing = null

## The ship is leaving: a dig in progress ends here.
func abort() -> void:
	if phase == Phase.DIGGING:
		if layer > 0:
			_end("liftoff")
		else:
			phase = Phase.READY
	_set_holding(false)

func _new_timing() -> void:
	timing = HarvestTiming.new(null, depth() >= TROPHY_DEPTH)

func _strike(grade: HarvestTiming.Grade) -> void:
	var drops := GemData.drill_drops(depth(), grade, rng)
	layer += 1
	dug.append_array(drops)
	var final := layer >= layer_count()
	_throw(drops, grade, final)
	EventBus.drill_struck.emit(site, grade, drops, layer, final)
	if final:
		_end("bottom")
	else:
		_new_timing()

func _overload() -> void:
	_set_holding(false)
	if is_instance_valid(ship):
		ship.take_damage(KICKBACK_DAMAGE)
	_juice(HarvestTiming.Grade.OVERLOAD, "", false)
	_end("overload")

func _end(reason: String) -> void:
	phase = Phase.DONE
	end_reason = reason
	_set_holding(false)
	if is_instance_valid(site):
		site.spend()
	EventBus.dig_ended.emit(site, reason, layer)

## Gems burst from the drill hole and the ship's magnet pulls them into the hold.
func _throw(drops: Array[String], grade: HarvestTiming.Grade, final: bool) -> void:
	if not is_instance_valid(ship) or not ship.is_inside_tree():
		return
	var hole := to_global(Vector2(-BIT_START, 0))
	Gem.burst(ship.get_parent(), hole, site.velocity(), drops, final, rng)
	_juice(grade, GemData.best_of(drops), final)

func _juice(grade: HarvestTiming.Grade, gem_id: String, final: bool) -> void:
	if not is_instance_valid(ship) or not ship.is_inside_tree():
		return
	HarvestJuice.play_at(ship, get_tree(), to_global(Vector2(-BIT_START, 0)), site.velocity(), grade, gem_id, final)

func _set_holding(value: bool) -> void:
	_holding = value
	if _dust:
		_dust.emitting = value

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not _holding:
		return
	var jitter := randf_range(-1.0, 1.0)
	var reach := BIT_LENGTH * (0.6 + 0.4 * timing.progress)
	var base := Vector2(-BIT_START + 2.0, jitter)
	var tip := Vector2(-BIT_START - reach, 0)
	draw_line(base, tip, Colors.HULL_LIGHT, 3.0)
	draw_line(base + Vector2(0, -3), tip, Colors.HULL_MID, 1.0)
	draw_line(base + Vector2(0, 3), tip, Colors.HULL_MID, 1.0)
	draw_circle(tip, 2.0, Colors.PRIMARY)
