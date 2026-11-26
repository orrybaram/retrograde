extends SpaceStation
class_name SunStation

## The station at the sun, where the Core's Gate is powered: the last and hardest place
## to reach. Placed but inert — the endgame that happens out here is still to be
## designed, so for now it is a dock, a silhouette and the Core's Gate beside it.
##
## Deliberately NOT in the "space_stations" group. Home tracking (NavSystem.home_target),
## the chart's home label (SystemMap._home_station) and the Void's clearance guard all
## read the first station in that group, and that has to stay Rook's.

## What the Sun Station answers to instead, for anything that wants it by name.
const GROUP := &"sun_station"

func station_group() -> StringName:
	return GROUP
