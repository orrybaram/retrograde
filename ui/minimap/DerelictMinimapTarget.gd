extends ResourceMinimapTarget
class_name DerelictMinimapTarget

## MinimapTarget for an abandoned ship. Deliberately says nothing about what is out there:
## it is an echo a little bigger than scrap, and finding a hull instead of a rock should be
## the surprise of arriving. Stays on the rim when out of range so it can always be found.

## Roughly a hull's reach, world px.
const HULL_RADIUS := 90.0

func echo_world_radius() -> float:
	return HULL_RADIUS

func pins_to_edge() -> bool:
	return true
