extends Node
class_name PlanetLog

## Marks a Body Visited. Flying into a Body's inner orbit (Planet.scan_radius(), the
## same reach the Planetary Scanner needs) earns it its Record in the Log — scanner or
## no scanner. The Record starts out carrying no survey; scanning fills it in
## (docs/adr/0003). Permanent, and written to the save the moment it happens, because a
## Body is reached in open flight with no dock to hang a full save off.
##
## This cannot live in PlanetScanner: that node is inert until
## GameState.has_planet_scanner, and Visiting has to work from the first minute.
## Added to the Ship at runtime.

var _ship: Ship = null
var _gs: GameState = null

func _ready() -> void:
	_ship = get_parent() as Ship

func _physics_process(_delta: float) -> void:
	if not _active():
		return
	mark_at(_ship.global_position)

## Mark whatever Body's inner orbit holds `pos`, if any. Returns the Body that earned a
## new Record on this call, or null when nothing did. `save_file` defaults to the game
## save; tests hand it their own.
func mark_at(pos: Vector2, save_file: String = "") -> Planet:
	var gs := _game_state()
	if not gs:
		return null
	var body := PlanetScan.deepest(pos, get_tree().get_nodes_in_group("planets"))
	if not body:
		return null
	var key := body.save_key()
	if key == "" or gs.is_planet_visited(key):
		return null
	gs.mark_planet_visited(key)
	Save.save_visited_planets(PackedStringArray(gs.visited_planets.keys()), save_file)
	return body

func _game_state() -> GameState:
	if not is_instance_valid(_gs):
		_gs = get_tree().get_first_node_in_group("game_state") as GameState
	return _gs

func _active() -> bool:
	if not is_instance_valid(_ship) or _ship.is_destroyed():
		return false
	var main := get_tree().get_first_node_in_group("main")
	return main == null or main.current_game_state == main.MainGameState.PLAYING
