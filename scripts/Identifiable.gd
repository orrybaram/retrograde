class_name Identifiable
extends RefCounted

## The Unidentified pattern (docs/GLOSSARY.md): a find the player has never reached stays
## unnamed until an Automaton names it on close approach. A Gate is the first thing to
## use it, and later finds keep the same shape — a save key, a flag in GameState, and a
## name the Guide says the moment the ship gets near enough.
##
## What lives here is the part every find shares: how close the ship has to come. The
## flag itself stays with the find, because each kind of thing is saved under its own
## key. The maps never spell the state out — an unreached find simply has no name on
## them yet.
##
## The Guide never points at a find beforehand; it only names what the player flew to
## (docs/adr/0002).

## How close the ship has to come before the Guide can make out what it is looking at.
const RANGE := 1000.0

## True once the ship is near enough for the Guide to name the find.
static func in_range(ship_position: Vector2, find_position: Vector2) -> bool:
	return ship_position.distance_squared_to(find_position) <= RANGE * RANGE
