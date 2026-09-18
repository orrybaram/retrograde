class_name Identifiable
extends RefCounted

## The Unidentified pattern (CONTEXT.md): a find the player has never reached reads as
## `? ? ?` on the minimap until an Automaton names it on close approach. A Gate is the
## first thing to use it, and later finds keep the same shape — a save key, a flag in
## GameState, and a label that flips the moment the Guide says what the thing is.
##
## What lives here is the part every find shares: how close the ship has to come, and
## the label a MinimapTarget draws under its marker. The flag itself stays with the
## find, because each kind of thing is saved under its own key.
##
## The Guide never points at a find beforehand; it only names what the player flew to
## (docs/adr/0002).

## What the minimap prints for something nobody has reached yet.
const UNKNOWN_LABEL := "? ? ?"
## How close the ship has to come before the Guide can make out what it is looking at.
const RANGE := 1000.0
## Size of the label under a minimap marker.
const LABEL_FONT_SIZE := 8

## True once the ship is near enough for the Guide to name the find.
static func in_range(ship_position: Vector2, find_position: Vector2) -> bool:
	return ship_position.distance_squared_to(find_position) <= RANGE * RANGE

## The find's name once it has been identified, `? ? ?` before that.
static func label(identified: bool, known_name: String) -> String:
	return known_name if identified else UNKNOWN_LABEL

## Draws that label just under a minimap marker of radius `size`.
static func draw_label(map: Minimap, pos: Vector2, size: float, text: String, color: Color) -> void:
	var font := map.get_theme_default_font()
	if font == null or text == "":
		return
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
	var at := pos + Vector2(-text_size.x / 2.0, size + text_size.y)
	map.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, color)
