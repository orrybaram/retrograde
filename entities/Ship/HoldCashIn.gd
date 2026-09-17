extends Node2D
class_name HoldCashIn

## Docking cash-in: gems leave the ship one at a time and arc into the port. Each gem
## comes out of the hold as it launches and is banked as credits when it lands, so the
## cargo readout drains while the credit readout counts up. Cheapest gems go first so
## the big ones close it out. Parented to the SpacePort so the flight rides the station.
## Taking off early banks whatever is left instantly (finish()).

signal finished(total: int)

const TOTAL_TIME := 2.4       # launch window for a hold of any size...
const MIN_INTERVAL := 0.02    # ...unless that would launch faster than this
const MAX_INTERVAL := 0.14
const START_DELAY := 0.5      # let the docking glide settle first
const FLIGHT_TIME := 0.7
const ARC_WIDTH := 44.0       # sideways swing along the pad
const ARC_HEIGHT := 12.0      # lift off the ship before diving into the port
const TARGET := Vector2(0, 36)  # inside the station, below the pad (ship sits at y=-20)

static var running := 0  # sequences in progress (the HUD rolls its credit count meanwhile)

var _ship: Node2D = null
var _gs: GameState = null
var _queue: Array[String] = []
var _flyers: Array[Flyer] = []
var _interval := MAX_INTERVAL
var _next_launch := START_DELAY
var _total := 0
var _flash := 0.0
var _launched := 0
var _done := false

## A gem in flight, in port-local space.
class Flyer extends Node2D:
	var item_id := ""
	var from := Vector2.ZERO
	var control := Vector2.ZERO
	var t := 0.0
	var _size := 2.0
	var _color := Colors.PRIMARY

	func _ready() -> void:
		_size = GemData.size_of(item_id)
		_color = GemData.color_of(item_id)

	## Advance along the arc; true once it has reached the port.
	func step(delta: float) -> bool:
		t = minf(t + delta / FLIGHT_TIME, 1.0)
		var e := t * t * (3.0 - 2.0 * t)
		position = from.lerp(control, e).lerp(control.lerp(TARGET, e), e)
		rotation += 9.0 * delta
		scale = Vector2.ONE * lerpf(1.6, 0.4, e)
		return t >= 1.0

	func _draw() -> void:
		Gem.draw_gem(self, _size, _color)

## Hold contents as one id per gem, cheapest first.
static func launch_order(items: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id in items:
		if GemData.is_gem(id):
			for i in int(items[id]):
				ids.append(id)
	ids.sort_custom(func(a, b): return GemData.tier_of(a) < GemData.tier_of(b))
	return ids

static func interval_for(count: int) -> float:
	return clampf(TOTAL_TIME / maxi(count, 1), MIN_INTERVAL, MAX_INTERVAL)

## Start cashing in the current hold at `port`. Returns null when there is nothing to cash.
static func begin(port: Node2D, ship: Node2D, gs: GameState) -> HoldCashIn:
	var ids := launch_order(InventoryManager.get_all_items())
	if ids.is_empty():
		return null
	var cash_in := HoldCashIn.new()
	cash_in._ship = ship
	cash_in._gs = gs
	cash_in._queue = ids
	cash_in._interval = interval_for(ids.size())
	cash_in.z_index = 5
	running += 1
	port.add_child(cash_in)
	return cash_in

func _process(delta: float) -> void:
	if _done:
		return
	_next_launch -= delta
	while _next_launch <= 0.0 and not _queue.is_empty():
		_launch(_queue.pop_front())
		_next_launch += _interval
	for flyer in _flyers.duplicate():
		if flyer.step(delta):
			_bank(flyer.item_id)
			_flyers.erase(flyer)
			flyer.queue_free()
			_flash = 1.0
	_flash = maxf(_flash - delta * 5.0, 0.0)
	queue_redraw()
	if _queue.is_empty() and _flyers.is_empty():
		_complete()

func _launch(id: String) -> void:
	InventoryManager.remove_item(id, 1)
	var flyer := Flyer.new()
	flyer.item_id = id
	var ship_pos := to_local(_ship.global_position) if is_instance_valid(_ship) else Vector2(0, -20)
	flyer.from = ship_pos
	flyer.position = ship_pos
	# Fan out to alternating sides so the stream arcs around the hull instead of over it.
	var side := 1.0 if _launched % 2 == 0 else -1.0
	_launched += 1
	flyer.control = Vector2(ship_pos.x + side * randf_range(ARC_WIDTH * 0.6, ARC_WIDTH), ship_pos.y - ARC_HEIGHT - randf() * 10.0)
	_flyers.append(flyer)
	add_child(flyer)

func _bank(id: String) -> void:
	var value := GemData.value_of(id)
	_total += value
	if _gs:
		_gs.credits += value

## Bank everything still queued or in flight right now.
func finish() -> void:
	if _done:
		return
	for flyer in _flyers:
		_bank(flyer.item_id)
		flyer.queue_free()
	_flyers.clear()
	for id in _queue:
		InventoryManager.remove_item(id, 1)
		_bank(id)
	_queue.clear()
	_complete()

func _complete() -> void:
	_done = true
	running -= 1
	if _total > 0:
		EventBus.hold_cashed_in.emit(_total)
	finished.emit(_total)
	queue_free()

func _draw() -> void:
	if _flash > 0.0:
		draw_circle(TARGET, 4.0 + 8.0 * (1.0 - _flash), Color(Colors.PRIMARY, 0.5 * _flash), false, 1.5)
