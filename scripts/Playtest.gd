extends Node

## Agent playtest driver. Inert unless the game is launched with a
## `--playtest=<target>` user arg (see tools/play.sh):
##   --playtest=res://playtests/foo.play   run a scenario file, then quit (exit 1 on failure)
##   --playtest=serve                      listen on 127.0.0.1:<port> for commands (tools/playctl)
##   --playtest-timeout=<sec>              real-time watchdog (default 300 for scenarios, off for serve)
##
## Both modes speak the same line-based command language. Every command
## replies with one JSON object. Input is injected as real InputEventKeys, so
## the game sees exactly what a player pressing keys would produce.
##
## Commands:
##   press <key|action> [n]        tap a key n times (default 1)
##   hold <key|action> <sec>       hold a key for game-time seconds
##   down <key|action> / up <...>  press / release without waiting
##   release_all                   release every held key
##   face <group> [tol_deg]        steer (with turn keys) until the nose points at the
##                                 nearest node in group, e.g. `face planets 5`
##   wait <sec>                    advance game time
##   frames <n>                    advance n process frames
##   wait_until <expr> [timeout]   wait until expression is truthy (default 10s)
##   assert <expr> [message]       record a failure if expression is falsy
##   eval <expr>                   evaluate an expression and return its value
##   state                         full JSON snapshot of the game
##   screen                        text currently visible on UI layers
##   screenshot <name>             save <out>/<name>.png (skipped under --headless)
##   timescale <n>                 set Engine.time_scale
##   log <text>                    echo text into the transcript
##   quit                          end the session
##
## Expressions are Godot `Expression`s with these names bound:
##   ship, main, gs (GameState), inv (InventoryManager), bus (EventBus),
##   pt (this node: pt.state_name(), pt.visible_ui(), pt.screen_text(), pt.nearest(group), pt.node(group))
## and this node as `self`, so get_tree() etc. also work.
## e.g. `assert ship.fuel < ship.max_fuel "thrusting burns fuel"`

const DEFAULT_PORT := 7777
const SAVE_PATH := "user://playtest_save.cfg"

var active := false
var out_dir := ""
var failures: Array[String] = []

var _held: Dictionary = {}  # keycode -> true
var _action_message := ""
var _server: TCPServer
var _log_file: FileAccess

func _ready() -> void:
	var target := _arg_value("--playtest")
	if target == "":
		return
	active = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	out_dir = _arg_value("--playtest-out")
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://.playtest")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_log_file = FileAccess.open(out_dir.path_join("transcript.jsonl"), FileAccess.WRITE)
	# Never touch the player's real save.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	EventBus.action_message_changed.connect(func(msg: String): _action_message = msg)

	# Watchdog: a stuck scenario must never hang the caller.
	var timeout := float(_arg_value("--playtest-timeout", "0" if target == "serve" else "300"))
	if timeout > 0:
		get_tree().create_timer(timeout, true, false, true).timeout.connect(func():
			failures.append("watchdog: exceeded %ss" % timeout)
			_finish())

	if target == "serve":
		_serve.call_deferred(int(_arg_value("--playtest-port", str(DEFAULT_PORT))))
	else:
		_run_file.call_deferred(target)

func save_path() -> String:
	return SAVE_PATH if active else "user://save.cfg"

# --- Runners -----------------------------------------------------------------

func _run_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		_emit({"ok": false, "error": "cannot open scenario %s" % path})
		get_tree().quit(2)
		return
	await _wait_for_main()
	var line_no := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		line_no += 1
		if line == "" or line.begins_with("#"):
			continue
		var reply: Dictionary = await execute(line)
		reply["line"] = line_no
		_emit(reply)
		if reply.get("quit", false):
			break
		if not reply.get("ok", false) and not line.begins_with("assert"):
			failures.append("line %d: %s -> %s" % [line_no, line, reply.get("error", "")])
			break
	_finish()

func _serve(port: int) -> void:
	await _wait_for_main()
	_server = TCPServer.new()
	var err := _server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("Playtest: cannot listen on port %d" % port)
		get_tree().quit(2)
		return
	print("PLAYTEST READY port=%d" % port)
	while true:
		if not _server.is_connection_available():
			await get_tree().process_frame
			continue
		var peer := _server.take_connection()
		var line := await _read_line(peer)
		var reply: Dictionary = await execute(line)
		_emit(reply)
		peer.put_data((JSON.stringify(reply) + "\n").to_utf8_buffer())
		peer.disconnect_from_host()
		if reply.get("quit", false):
			break
	_finish()

func _read_line(peer: StreamPeerTCP) -> String:
	var buf := PackedByteArray()
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		peer.poll()
		var n := peer.get_available_bytes()
		if n > 0:
			buf.append_array(peer.get_data(n)[1])
			if buf.has(10):
				break
		elif peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		await get_tree().process_frame
	return buf.get_string_from_utf8().strip_edges()

func _finish() -> void:
	_release_all()
	var summary := {"done": true, "ok": failures.is_empty(), "failures": failures, "out_dir": out_dir}
	_emit(summary)
	print("PLAYTEST %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _wait_for_main() -> void:
	while get_tree().get_first_node_in_group("main") == null:
		await get_tree().process_frame
	await get_tree().process_frame

# --- Command dispatch --------------------------------------------------------

func execute(line: String) -> Dictionary:
	var sp := line.find(" ")
	var cmd := line if sp == -1 else line.substr(0, sp)
	var rest := "" if sp == -1 else line.substr(sp + 1).strip_edges()
	var args := rest.split(" ", false)
	var reply := {"cmd": line, "ok": true}
	match cmd:
		"press":
			var n := int(args[1]) if args.size() > 1 else 1
			for i in n:
				if not _key(args[0], true, reply):
					return reply
				await _frames(2)
				_key(args[0], false, reply)
				await _frames(2)
		"hold":
			if not _key(args[0], true, reply):
				return reply
			await _game_seconds(float(args[1]))
			_key(args[0], false, reply)
			await _frames(1)
		"down", "up":
			_key(args[0], cmd == "down", reply)
			await _frames(1)
		"release_all":
			_release_all()
			await _frames(1)
		"wait":
			await _game_seconds(float(args[0]))
		"face":
			await _face(args[0], float(args[1]) if args.size() > 1 else 5.0, reply)
		"frames":
			await _frames(int(args[0]))
		"wait_until":
			var parsed := _split_trailing_number(rest, 10.0)
			var start := Time.get_ticks_msec()
			var met := false
			while (Time.get_ticks_msec() - start) / 1000.0 < parsed[1] / maxf(Engine.time_scale, 0.01):
				if _truthy(_eval(parsed[0], reply)):
					met = true
					break
				await get_tree().process_frame
			reply["waited"] = (Time.get_ticks_msec() - start) / 1000.0
			if not met:
				reply["ok"] = false
				reply["error"] = reply.get("error", "timeout: %s" % parsed[0])
		"assert":
			var parts := _split_assert(rest)
			var value = _eval(parts[0], reply)
			if not _truthy(value) or reply.has("error"):
				reply["ok"] = false
				var msg := "assert failed: %s (%s) got %s" % [parts[0], parts[1], var_to_str(value)]
				reply["error"] = reply.get("error", msg)
				failures.append(msg)
		"eval":
			reply["value"] = _jsonable(_eval(rest, reply))
			reply["ok"] = not reply.has("error")
		"state":
			reply["state"] = snapshot()
		"screen":
			reply["screen"] = screen_text()
		"screenshot":
			if DisplayServer.get_name() == "headless":
				reply["skipped"] = "headless: no rendered image"
				return reply
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			if img == null or img.is_empty():
				reply["ok"] = false
				reply["error"] = "no rendered image (running --headless?)"
			else:
				var p := out_dir.path_join((args[0] if args.size() > 0 else "shot") + ".png")
				img.save_png(p)
				reply["path"] = p
		"timescale":
			Engine.time_scale = float(args[0])
		"log":
			reply["message"] = rest
		"quit":
			reply["quit"] = true
		_:
			reply["ok"] = false
			reply["error"] = "unknown command '%s'" % cmd
	return reply

# --- Input -------------------------------------------------------------------

func _key(name: String, pressed: bool, reply: Dictionary) -> bool:
	var keycode := _resolve_key(name)
	if keycode == KEY_NONE:
		reply["ok"] = false
		reply["error"] = "unknown key or action '%s'" % name
		return false
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)
	if pressed:
		_held[keycode] = true
	else:
		_held.erase(keycode)
	return true

func _resolve_key(name: String) -> Key:
	if InputMap.has_action(name):
		for ev in InputMap.action_get_events(name):
			if ev is InputEventKey:
				return ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
	var aliases := {"enter": "Enter", "esc": "Escape", "escape": "Escape", "space": "Space",
		"up": "Up", "down": "Down", "left": "Left", "right": "Right", "shift": "Shift", "tab": "Tab"}
	return OS.find_keycode_from_string(aliases.get(name.to_lower(), name))

func _release_all() -> void:
	for keycode in _held.keys():
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = false
		Input.parse_input_event(ev)
	_held.clear()

func _face(group: String, tolerance: float, reply: Dictionary) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	var held := ""
	while Time.get_ticks_msec() < deadline:
		var target = nearest(group)
		if target == null:
			reply["ok"] = false
			reply["error"] = "nothing visible in group '%s'" % group
			break
		var bearing: float = target["bearing_deg"]
		reply["bearing_deg"] = bearing
		var want := "" if absf(bearing) <= tolerance else ("turn_right" if bearing > 0 else "turn_left")
		if want != held:
			if held != "":
				_key(held, false, reply)
			if want != "":
				_key(want, true, reply)
			held = want
		if want == "":
			break
		await get_tree().physics_frame
	if held != "":
		_key(held, false, reply)
		reply["ok"] = false
		reply["error"] = "face timed out at bearing %s" % reply.get("bearing_deg")
	await _frames(1)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _game_seconds(sec: float) -> void:
	# Timer ignores pause so a wait never deadlocks on a paused menu.
	await get_tree().create_timer(sec, true, false, false).timeout

# --- Expressions -------------------------------------------------------------

const _EXPR_NAMES := ["ship", "main", "gs", "inv", "bus", "pt"]

func _eval(src: String, reply: Dictionary) -> Variant:
	var expr := Expression.new()
	if expr.parse(src, PackedStringArray(_EXPR_NAMES)) != OK:
		reply["error"] = "parse error: %s" % expr.get_error_text()
		return null
	var tree := get_tree()
	var value = expr.execute([
		tree.get_first_node_in_group("ship"),
		tree.get_first_node_in_group("main"),
		tree.get_first_node_in_group("game_state"),
		InventoryManager, EventBus, self,
	], self, false)
	if expr.has_execute_failed():
		reply["error"] = "eval error: %s" % expr.get_error_text()
		return null
	return value

func _truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_NIL:
			return false
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return bool(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v) != ""
		TYPE_OBJECT:
			return is_instance_valid(v)
	return true

## "expr 3.5" -> ["expr", 3.5]; "expr" -> ["expr", default]
func _split_trailing_number(s: String, default: float) -> Array:
	var sp := s.rfind(" ")
	if sp != -1 and s.substr(sp + 1).is_valid_float():
		return [s.substr(0, sp).strip_edges(), float(s.substr(sp + 1))]
	return [s, default]

## `expr "message"` -> [expr, message]
func _split_assert(s: String) -> Array:
	if s.ends_with("\""):
		var q := s.rfind("\"", s.length() - 2)
		if q > 0:
			return [s.substr(0, q).strip_edges(), s.substr(q + 1, s.length() - q - 2)]
	return [s, s]

# --- Observation -------------------------------------------------------------

func snapshot() -> Dictionary:
	var tree := get_tree()
	var main := tree.get_first_node_in_group("main")
	var ship := tree.get_first_node_in_group("ship") as Ship
	var gs := tree.get_first_node_in_group("game_state") as GameState
	var s := {
		"time_ms": Time.get_ticks_msec(),
		"paused": tree.paused,
		"main_state": main.MainGameState.keys()[main.current_game_state] if main else null,
		"ui_open": visible_ui(),
		"action_message": _action_message,
		"credits": gs.credits if gs else null,
		"upgrades": gs.upgrade_levels if gs else {},
		"inventory": InventoryManager.get_all_items(),
	}
	if ship:
		s["ship"] = {
			"state": state_name(),
			"position": _jsonable(ship.global_position),
			"velocity": _jsonable(ship.linear_velocity),
			"speed": snappedf(ship.linear_velocity.length(), 0.1),
			"rotation_deg": snappedf(rad_to_deg(ship.global_rotation), 0.1),
			"fuel": snappedf(ship.fuel, 0.1),
			"max_fuel": ship.max_fuel,
			"hull": snappedf(ship.hull_strength, 0.1),
			"max_hull": ship.max_hull,
			"cargo_weight": ship.get_cargo_weight(),
			"max_cargo_weight": ship.max_cargo_weight,
		}
		s["nearest"] = {
			"planet": nearest("planets"),
			"space_port": nearest("space_ports"),
			"space_station": nearest("space_stations"),
			"resource": nearest("resource_nodes"),
		}
	return s

## First node in a group, e.g. pt.node("pause_menu").visible
func node(group: String) -> Node:
	return get_tree().get_first_node_in_group(group)

func state_name() -> String:
	var ship := get_tree().get_first_node_in_group("ship")
	return ship.state_machine.get_current_state_name() if ship and ship.state_machine else ""

## Names of CanvasLayer UI panels currently visible (HUD excluded).
func visible_ui() -> Array:
	var names := []
	for c in _ui_panels():
		if c.visible and c.name != "HUD" and c.name != "IndicatorManager":
			names.append(str(c.name))
	return names

## All text a player could read on visible UI panels, top to bottom.
func screen_text() -> Dictionary:
	var out := {}
	for c in _ui_panels():
		if not c.visible:
			continue
		var lines := []
		_collect_text(c, lines)
		if not lines.is_empty():
			out[str(c.name)] = lines
	return out

## Nearest node in group to the ship: {name, distance, bearing_deg (relative to ship nose)}.
func nearest(group: String) -> Variant:
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	if not ship:
		return null
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		if n is Node2D and n.is_visible_in_tree():
			var d := ship.global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	if not best:
		return null
	# Ship nose points along +X (thrust direction). Positive bearing = turn right.
	var to := best.global_position - ship.global_position
	var nose := Vector2.RIGHT.rotated(ship.global_rotation)
	return {
		"name": str(best.name),
		"distance": snappedf(best_d, 0.1),
		"bearing_deg": snappedf(rad_to_deg(nose.angle_to(to)), 0.1),
	}

func _ui_panels() -> Array:
	var main := get_tree().get_first_node_in_group("main")
	var layer := main.get_node_or_null("CanvasLayer") if main else null
	return layer.get_children().filter(func(c): return c is CanvasItem) if layer else []

func _collect_text(node: Node, lines: Array) -> void:
	if node is CanvasItem and not node.visible:
		return
	var text := ""
	if node is RichTextLabel:
		text = node.get_parsed_text()
	elif node is Label or node is Button:
		text = node.text
	text = text.strip_edges()
	var hidden: bool = node is CanvasItem and node.modulate.a < 0.05
	# Skip ASCII-art banners; they are noise to a reader.
	if text != "" and not hidden and not text.contains("█"):
		lines.append(text)
	for c in node.get_children():
		_collect_text(c, lines)

func _jsonable(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [snappedf(v.x, 0.1), snappedf(v.y, 0.1)]
		TYPE_OBJECT:
			return str(v)
		TYPE_DICTIONARY, TYPE_ARRAY, TYPE_STRING, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_NIL:
			return v
	return var_to_str(v)

func _emit(reply: Dictionary) -> void:
	var line := JSON.stringify(reply)
	print("PT ", line)
	if _log_file:
		_log_file.store_line(line)
		_log_file.flush()

func _arg_value(key: String, default := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a == key:
			return "1"
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return default
