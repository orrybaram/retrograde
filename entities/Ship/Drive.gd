extends RefCounted
class_name Drive

## The ship's two engines (docs/adr/0010), owned by the Ship as `ship.drive`.
##
## The **Aux** is ordinary thrust: free, always available, never out. Nothing here can
## take it away, so nothing here models it - there is no Aux fuel, meter or cough.
##
## The **Burn** is the boost, and it is all this class is about: the tank that feeds it,
## the free quarter SR-7 tops it up to, and the cough a low tank gives it. It answers the
## one question flight, the boost gauge and the radio all ask - is the Burn lit? - so
## they cannot disagree.
##
## Every change to the tank goes through `fuel` (clamped to 0..max_fuel) and emits
## `changed`. The flight states drive it once per physics step: `tick` while flying,
## `rest` otherwise, then `try_burn` from the thrust that spends it.

## The tank moved (a burn, a refuel, a save loading, the dev panel).
signal changed
## A burn just ran the tank dry.
signal depleted
## A cough just cut the Burn. The engine backfires; LowFuelEffect draws it.
signal coughed

enum Level { OK, LOW, CRITICAL }

const LOW_RATIO := 0.25
const CRITICAL_RATIO := 0.10
## The ship's tank. Its limits are fixed: nothing is bought (docs/adr/0007).
const CAPACITY := 150.0
## What SR-7 puts in the tank for nothing (docs/OPENING.md §9): once its core is running,
## every dock and every relaunch tops the tank up to a quarter, never higher.
const FREE_FRACTION := 0.25
## Seconds between coughs while a Burn is being tried on a low tank. Rare when LOW,
## frequent when CRITICAL (and a dry tank is CRITICAL).
const COUGH_GAP := {Level.LOW: Vector2(1.2, 2.8), Level.CRITICAL: Vector2(0.25, 0.8)}
const COUGH_LENGTH := Vector2(0.2, 0.4)

var max_fuel := CAPACITY:
	set(value):
		max_fuel = maxf(value, 0.0)
		fuel = fuel  # re-clamp, and say so
## Always 0..max_fuel. Assigning it clamps and emits `changed`.
var fuel := 0.0:
	set(value):
		fuel = clampf(value, 0.0, max_fuel)
		changed.emit()
## Fuel a lit Burn spends per second. The Ship sets it from its tuning.
var burn_rate := 15.0
## The dev panel's infinite tank: the Burn still lights, the gauge never moves.
var infinite := false
## The cough's own dice, so it never shifts a gameplay roll. Seed it to test.
var rng := RandomNumberGenerator.new()

var _flying := false
var _attempting := false  # boost held with thrust on, this step
var _cough_left := 0.0  # > 0 while a cough has the Burn cut
var _next_cough := 0.0  # countdown to the next cough, only running while a Burn is tried

func _init() -> void:
	rng.randomize()

static func level_for(amount: float, capacity: float) -> Level:
	if capacity <= 0.0 or amount <= 0.0:
		return Level.CRITICAL
	var ratio := amount / capacity
	if ratio <= CRITICAL_RATIO:
		return Level.CRITICAL
	if ratio <= LOW_RATIO:
		return Level.LOW
	return Level.OK

func level() -> Level:
	return level_for(fuel, max_fuel)

## The tank's level as the ship shows it: only in flight. Docked or landed, a low tank
## is filling up or sitting still, and neither vents nor coughs.
func warning() -> Level:
	return level() if _flying else Level.OK

## Is the Burn lit? It needs the boost held with thrust on, fuel in the tank, and an
## engine that is not coughing. Failing any of those leaves ordinary Aux thrust.
func is_lit() -> bool:
	return _attempting and fuel > 0.0 and not is_coughing()

func is_coughing() -> bool:
	return _cough_left > 0.0

## One physics step in flight. `attempting`: the boost is held with thrust on. Only a
## Burn draws on the tank, so only a Burn can cough - including one tried on an empty
## tank, where there is nothing to burn and the engine says so.
func tick(dt: float, attempting: bool) -> void:
	_flying = true
	_attempting = attempting
	if level() == Level.OK:
		_cough_left = 0.0
		_next_cough = 0.0
		return
	if _cough_left > 0.0:
		_cough_left = maxf(_cough_left - dt, 0.0)
		return
	if not attempting:
		return
	var gap: Vector2 = COUGH_GAP[level()]
	if _next_cough <= 0.0:
		_next_cough = rng.randf_range(gap.x, gap.y) * 0.5
	_next_cough -= dt
	if _next_cough <= 0.0:
		_cough_left = rng.randf_range(COUGH_LENGTH.x, COUGH_LENGTH.y)
		_next_cough = rng.randf_range(gap.x, gap.y)
		coughed.emit()

## Out of flight (docked, landed, lost): the Burn is off and any cough is over.
func rest() -> void:
	_flying = false
	_attempting = false
	_cough_left = 0.0
	_next_cough = 0.0

## Spend `dt` seconds of Burn. Returns whether the Burn is lit; spends nothing if not.
func try_burn(dt: float) -> bool:
	if not is_lit():
		return false
	if infinite:
		return true
	fuel -= burn_rate * dt
	if fuel <= 0.0:
		depleted.emit()
	return true

## Add up to `points`, never past `up_to` or the tank, and never draining it. Returns the
## points actually added.
func refuel(points: float, up_to := INF) -> float:
	var target := minf(fuel + maxf(points, 0.0), minf(up_to, max_fuel))
	if target <= fuel:
		return 0.0
	var added := target - fuel
	fuel = target
	return added

## The level SR-7 tops the tank up to, or 0 while its core is cold.
func free_floor(gs: GameState) -> float:
	if gs == null or not gs.core_started:
		return 0.0
	return max_fuel * FREE_FRACTION

## Relaunch: SR-7 tops the tank up to its free quarter at once. Never drains it.
func top_up_to_free_floor(gs: GameState) -> void:
	refuel(INF, free_floor(gs))
	changed.emit()
