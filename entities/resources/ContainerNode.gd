extends ScrapNode
class_name ContainerNode

## A sealed cargo container, still intact. Salvages like scrap but always comes out
## trophy grade — it takes five clean cuts and what's inside is worth the detour.
## Spawned by the encounter field out in deep space (see docs/ENCOUNTERS.md).

const _SHAPE := preload("res://entities/resources/ScrapShapes/ContainerShape.tscn")

func _shape_scenes() -> Array:
	return [_SHAPE]

## It keeps the sparkles, but it doesn't breathe — a container is a solid object, and a
## pulsing one reads as soft.
func _pulses_when_trophy() -> bool:
	return false
