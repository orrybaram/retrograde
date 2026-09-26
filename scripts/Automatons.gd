class_name Automatons

## The Automatons the player can meet, and which of them they hold a Record on.
## Meeting an Automaton earns its Record in the Log; the Log only ever gains Records.
##
## Holding a Record about an Automaton is the player's note on it, not the Automaton
## being present — nothing speaks from inside the Log (docs/GLOSSARY.md).

## UNIT-7, the Guide: stationed at SR-7 over Rook and the first Automaton the player
## meets (docs/DESIGN.md 5.3, NPC #1). The player holds its Record from the first
## transmission, so the Records tab is never empty (docs/adr/0003).
const GUIDE := preload("res://entities/Store/CheerfulGuideNPC.tres")

## Every Automaton in the game, in the order the player meets them. Records are listed
## in this order, not in the order they happened to be met.
const ALL := [GUIDE]


## The Automatons the player has met, in ALL order. A key in `met_automatons` with no
## Automaton behind it is ignored rather than drawn as a row (docs/adr/0003).
static func met(gs: GameState) -> Array[NPCData]:
	var known: Array[NPCData] = []
	if gs == null:
		return known
	for npc in ALL:
		if gs.has_met_automaton(npc.record_key()):
			known.append(npc)
	return known
