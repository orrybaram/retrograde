extends Resource
class_name NPCData

## One Automaton: how it looks and talks at the station it is stationed at, and the
## Record the player keeps about it in the Log (CONTEXT.md: Automaton, Record, Note).

@export var npc_name: String = ""
## The designation on its own, e.g. "UNIT-7". This is what its Record is filed under
## in the Log; npc_name carries the title as well ("UNIT-7 - The Guide").
@export var designation: String = ""
## The station this Automaton is found at, e.g. "SR-7". An Automaton never travels, so
## its Record says where the player met it.
@export var station: String = ""
@export_multiline var ascii_art: String = ""
@export var greeting: String = ""
@export var talk_topics: Array[String] = []

## The Notes on this Automaton's Record, in the player's own voice. Note i appears once
## Titan Influence reaches note_influence[i], which is how a Record sours as the Titan
## wakes. Authoring the prose is a separate slice: both arrays ship empty, so a Record
## renders no Notes at all.
@export var record_notes: Array[String] = []
## Titan Influence (0-5) each Note in record_notes waits for, index for index.
@export var note_influence: Array[int] = []


## The designation the Log files this Automaton's Record under. Falls back to the part
## of npc_name ahead of the title, so an NPCData with no designation still has a key.
func record_key() -> String:
	if designation != "":
		return designation
	return npc_name.split(" - ")[0].strip_edges()


## The Notes visible at `influence` Titan Influence, in authored order. A Note with no
## threshold of its own is visible from the first meeting.
func notes_at(influence: int) -> Array[String]:
	var visible: Array[String] = []
	for i in record_notes.size():
		var needed: int = note_influence[i] if i < note_influence.size() else 0
		if influence >= needed:
			visible.append(record_notes[i])
	return visible
