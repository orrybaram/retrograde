extends Node2D
class_name FuelGauge

## The level meter on SR-7's right fuel tank (the FUEL TANK Section): a recessed vertical
## slot up the tank's face with a tick at each quarter, filling from the bottom. It comes
## home empty - the tank was cut out and pushed away, and whatever was in it is long gone.
## It is here for the fuel the player will one day extract and bring back; `level` is what
## that sets.
##
## Drawn in the station's own space (a child of Visuals/FuelTank, which sits at the
## station's origin), so it shows and hides with the tank.

## The slot, in station space: up the tank's face, clear of its highlight line.
const SLOT := Rect2(155.0, -32.0, 7.0, 102.0)
const TICKS := 4
const TICK_LENGTH := 3.0
## How long the fill takes to move to a new level, s.
const EASE_TIME := 1.2

## 0 empty, 1 full.
var level := 0.0:
	set(v):
		level = clampf(v, 0.0, 1.0)
		queue_redraw()
## What is drawn, easing toward `level`.
var shown := 0.0

func _process(delta: float) -> void:
	if not is_equal_approx(shown, level):
		shown = move_toward(shown, level, delta / EASE_TIME)
		queue_redraw()

## Set the level without easing to it (a load).
func snap(v: float) -> void:
	level = v
	shown = level
	queue_redraw()

## Where the top of the fill is, in station space.
func fill_rect() -> Rect2:
	var inner := SLOT.grow(-1.5)
	var h := inner.size.y * shown
	return Rect2(inner.position.x, inner.end.y - h, inner.size.x, h)

func _draw() -> void:
	draw_rect(SLOT, Colors.HULL_DARK)
	draw_rect(SLOT.grow(-1.0), Colors.SPACE_BG)
	var fill := fill_rect()
	if fill.size.y > 0.0:
		draw_rect(fill, Colors.PRIMARY)
	# Quarter ticks on the outer edge, the empty mark brightest
	for i in TICKS + 1:
		var y := SLOT.end.y - SLOT.size.y * float(i) / TICKS
		var color := Colors.PRIMARY_DIM if i > 0 else Colors.PRIMARY
		draw_line(Vector2(SLOT.end.x, y), Vector2(SLOT.end.x + TICK_LENGTH, y), color, 1.0)
