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
##   burst <name> <n> <interval>   n screenshots <interval> game-seconds apart (<name>_00.png ...)
##   seek <Kind> [hops]            warp around deep space until something of that kind is streaming
##                                 nearby, and park there. The void is sparse by design, so a
##                                 scenario can't assume a given spot holds a container or a wreck.
##   stage_harvest [dist] [trophy|plain] [kind:<Kind>]
##                                 put the flying ship <dist>px (default 40; harvest radius 60) behind the nearest scrap,
##                                 `plain` forces an ordinary 3-hit node, `kind:Container` picks that sort only.
##                                 nose on it, velocity matched — ready to hold `action`.
##                                 `trophy` forces the node to be a trophy. Sets pt.staged
##                                 (its HarvestTiming is pt.staged.timing once a harvest starts).
##   land <planet> [descent] [sec] throttle real `thrust` presses to fall onto the planet at
##                                 about <descent> px/s (default 15) until PlanetLandedState.
##                                 Start nose-up above a pad (pt.hover_over_site).
##   reload                        reload the game from the save and wait for it to finish
##   timescale <n>                 set Engine.time_scale
##   log <text>                    echo text into the transcript
##   quit                          end the session
##
## Expressions are Godot `Expression`s with these names bound:
##   ship, main, gs (GameState), inv (InventoryManager), bus (EventBus),
##   pt (this node: pt.state_name(), pt.item_count(), pt.gem_count(), pt.spawn_gem(id, offset, [rel_vel]), pt.popup_counts(), pt.last_drops, pt.visible_ui(),
##       pt.screen_text(), pt.nearest(group), pt.node(group), pt.planet(name),
##       pt.park_near_planet(name, dist, [angle_deg]), pt.scanner(), pt.redock(),
##       pt.ore(planet), pt.hover_over_ore(planet, height, [tilt_deg], [descent]), pt.altitude(planet), pt.rel_speed(planet), pt.drill(),
##       pt.caption(text) (on-screen caption for recorded videos))
## and this node as `self`, so get_tree() etc. also work.
## e.g. `assert ship.fuel < ship.max_fuel "thrusting burns fuel"`

const DEFAULT_PORT := 7777
## Per-run save file. Godot's user dir is keyed by project name, so parallel runs
## (and other worktrees of this project) would otherwise share one save and clobber
## each other's state mid-scenario.
const SAVE_DIR := "user://playtest"


var active := false
var _save_file := ""
var out_dir := ""
var failures: Array[String] = []
var staged: ScrapNode = null  # last node picked by stage_harvest, for expressions: pt.staged
var last_drops: Array[String] = []  # gem ids from the most recent harvest hit: pt.last_drops
var notes: Dictionary = {}  # scratch values a scenario wants to compare later: pt.remember/pt.recall

var _held: Dictionary = {}  # keycode -> true
var _caption: Label = null
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
	# Never touch the player's real save, and never share one with a parallel run.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_save_file = "%s/save_%d.cfg" % [SAVE_DIR, OS.get_process_id()]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_file))
	EventBus.action_message_changed.connect(func(msg: String): _action_message = msg)
	EventBus.harvest_hit.connect(func(_s, grade: HarvestTiming.Grade, gems: Array[String], final: bool):
		last_drops = gems
		_emit({"event": "harvest_hit", "grade": HarvestTiming.Grade.keys()[grade], "gems": gems, "final": final}))
	EventBus.gem_collected.connect(func(id: String, _pos): _emit({"event": "gem_collected", "gem": id}))
	EventBus.hold_cashed_in.connect(func(cr: int): _emit({"event": "hold_cashed_in", "credits": cr}))
	EventBus.drill_struck.connect(func(_s, grade: HarvestTiming.Grade, gems: Array[String], layer: int, final: bool):
		last_drops = gems
		_emit({"event": "drill_struck", "grade": HarvestTiming.Grade.keys()[grade], "gems": gems, "layer": layer, "final": final}))
	EventBus.dig_ended.connect(func(_s, reason: String, layers: int): _emit({"event": "dig_ended", "reason": reason, "layers": layers}))

	var pace_fps := float(_arg_value("--playtest-fps", "0"))
	if pace_fps > 0.0:
		_frame_usec = int(1_000_000.0 / pace_fps)

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

## Frame pacing for recordings: Movie Maker renders as fast as it can, but orbits run on
## the wall clock, so a recording would drift from how the game actually plays. With
## --playtest-fps=<n> each frame is held back to real time.
var _pace_usec := 0
var _frame_usec := 0

func _process(_delta: float) -> void:
	if _frame_usec <= 0:
		return
	var elapsed := Time.get_ticks_usec() - _pace_usec
	if _pace_usec > 0 and elapsed < _frame_usec:
		OS.delay_usec(_frame_usec - elapsed)
	_pace_usec = Time.get_ticks_usec()

func save_path() -> String:
	return _save_file if active else "user://save.cfg"

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
	if _save_file != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_file))
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
		"burst":
			if DisplayServer.get_name() == "headless":
				reply["skipped"] = "headless: no rendered image"
				return reply
			var paths := []
			for i in int(args[1]):
				await RenderingServer.frame_post_draw
				var p := out_dir.path_join("%s_%02d.png" % [args[0], i])
				get_viewport().get_texture().get_image().save_png(p)
				paths.append(p)
				await _game_seconds(float(args[2]))
			reply["paths"] = paths
		"seek":
			await _seek_kind(args[0] if args.size() > 0 else "Scrap",
				int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 60, reply)
		"stage_harvest":
			var want_kind := ""
			for arg in args:
				if arg.begins_with("kind:"):
					want_kind = arg.substr(5)
			await _stage_harvest(float(args[0]) if args.size() > 0 and args[0].is_valid_float() else 40.0,
				args.has("trophy"), args.has("plain"), want_kind, reply)
		"land":
			await _land(args[0], float(args[1]) if args.size() > 1 else 15.0, float(args[2]) if args.size() > 2 else 15.0, reply)
		"reload":
			await _reload(reply)
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

## Godot releases every pressed key when the window loses focus, which would silently
## end a `down`/`hold` mid-scenario. Re-press whatever we still hold, before game code runs.
func _notification(what: int) -> void:
	if active and what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_emit({"event": "focus_out", "held": _held.size()})
		_repress_held.call_deferred()

func _repress_held() -> void:
	for keycode in _held.keys():
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = true
		Input.parse_input_event(ev)
	Input.flush_buffered_events()

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

## Autopilot for a vertical descent: hold `thrust` whenever the ship falls faster than
## `descent` px/s relative to the planet, release it otherwise.
func _land(planet_name: String, descent: float, timeout: float, reply: Dictionary) -> void:
	var p := planet(planet_name)
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if not p or not ship:
		reply["ok"] = false
		reply["error"] = "land: no planet '%s' or no ship" % planet_name
		return
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	var thrusting := false
	var fastest := 0.0
	while Time.get_ticks_msec() < deadline and state_name() == "FlyingState":
		var up := p.global_position.direction_to(ship.global_position)
		var falling := -(ship.linear_velocity - p.linear_velocity).dot(up)
		fastest = maxf(fastest, falling)
		var want := falling > descent
		if want != thrusting:
			_key("thrust", want, reply)
			thrusting = want
		await get_tree().physics_frame
	if thrusting:
		_key("thrust", false, reply)
	await _frames(2)
	reply["state"] = state_name()
	reply["max_descent"] = snappedf(fastest, 0.1)
	if state_name() != "PlanetLandedState":
		reply["ok"] = false
		reply["error"] = "land: ended in %s" % state_name()

## Skip the flight: park the ship just behind the nearest live scrap node, nose on it,
## Nodes of `kind` that the encounter field put there. A planet's own ring doesn't count:
## seeking is about finding a populated stretch of the void, and the station's ring would
## satisfy every search from the dock.
func _deep_count(kind: String) -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if node is ScrapNode and (node as ScrapNode).kind == kind and (node as OrbitalNode).spawner_key != "":
			total += 1
	return total

## Hunt deep space for a node of `kind`, parking the ship where one is found. Hops follow
## a fixed sequence, so a scenario that finds one finds the same one every run.
## Planets sweep encounters out of their gravity fields as they orbit, so a stretch of
## void with one nearby quietly gains and loses nodes. Seek keeps well clear of that.
const SEEK_PLANET_CLEARANCE := 60000.0

func _seek_kind(kind: String, hops: int, reply: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in hops:
		# Out past the sun's exclusion, inside Veld's orbit. Always hop first: starting
		# docked, the station's ring is right there.
		warp_to(Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(60000.0, 250000.0))
		for _f in 24:
			await get_tree().process_frame
		var planet: Variant = nearest("planets")
		if planet != null and float(planet["distance"]) < SEEK_PLANET_CLEARANCE:
			continue
		if _deep_count(kind) > 0:
			var found := nearest_kind(kind)
			if found:
				# Park on it rather than wherever the hop landed. Left at arm's length the
				# ring can carry it out of the loaded cells before the scenario gets to it.
				warp_to(found.global_position + Vector2(120, 0))
				# Long enough for the field to reconcile (it checks every 0.25s) and
				# release whatever the move dropped out of the window, so the caller
				# isn't handed a node that is about to go back to the pool.
				for _s in 30:
					await get_tree().process_frame
				if not is_instance_valid(found) or _deep_count(kind) == 0:
					continue
				reply["at"] = [found.global_position.x, found.global_position.y]
			reply["hops"] = i + 1
			reply["found"] = kind
			return
	reply["ok"] = false
	reply["error"] = "seek: no %s found in %d hops" % [kind, hops]

## velocity matched, so the next `hold action` starts a harvest.
func _stage_harvest(dist: float, trophy: bool, plain: bool, want_kind: String, reply: Dictionary) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	var scrap: ScrapNode = null
	var best := INF
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if n is ScrapNode and n.is_visible_in_tree() and not n._is_depleted and n.amount > 0:
			if want_kind != "" and (n as ScrapNode).kind != want_kind:
				continue
			var d := ship.global_position.distance_squared_to(n.global_position)
			if d < best:
				best = d
				scrap = n
	if not ship or not scrap:
		reply["ok"] = false
		reply["error"] = "stage_harvest: no ship or no live %s node" % (want_kind if want_kind != "" else "scrap")
		return
	if trophy and not scrap.is_trophy:
		scrap.is_trophy = true
	# A trophy roll would otherwise make the hit count vary run to run
	if plain and scrap.is_trophy:
		scrap.is_trophy = false
		scrap.hits_left = ScrapNode.NORMAL_HITS
		scrap.health_component.reset()
	if ship.state_machine.get_current_state_name() != "FlyingState":
		ship.state_machine.change_state("FlyingState")
	# Distant nodes only update their orbit every 60 frames; mark it in range so it
	# ticks every frame, then hold the pose until the cone's area_entered fires.
	scrap._cached_in_range = true
	for i in 120:
		if i > 3 and scrap._state_machine.get_current_state_name() == "ScrapInRangeState":
			break
		var vel := scrap.get_orbital_velocity()
		var approach := vel.normalized() if vel.length() > 1.0 else Vector2.RIGHT
		var pos := scrap.global_position - approach * dist
		var xform := Transform2D(approach.angle(), pos)
		PhysicsServer2D.body_set_state(ship.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, xform)
		PhysicsServer2D.body_set_state(ship.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, vel)
		PhysicsServer2D.body_set_state(ship.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
		await get_tree().physics_frame
	staged = scrap
	if not scrap.harvest_stopped.is_connected(_on_staged_event):
		for sig in ["harvest_started", "harvest_stopped", "resource_depleted"]:
			scrap.connect(sig, _on_staged_event.bind(sig, scrap))
	reply["scrap"] = str(scrap.name)
	reply["trophy"] = scrap.is_trophy
	reply["scrap_state"] = scrap._state_machine.get_current_state_name()
	if reply["scrap_state"] != "ScrapInRangeState":
		reply["ok"] = false
		reply["error"] = "stage_harvest: scrap is %s, expected ScrapInRangeState" % reply["scrap_state"]

func _on_staged_event(sig: String, scrap: ScrapNode) -> void:
	_emit({"event": sig, "t": Time.get_ticks_msec(), "hits_left": scrap.hits_left,
		"action_pressed": Input.is_action_pressed("action"),
		"dist": snappedf(scrap.global_position.distance_to(get_tree().get_first_node_in_group("ship").global_position), 0.1)})

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
		"hold_value": InventoryManager.get_total_value(),
		"loose_gems": Gem.active.size(),
		"void": {
			"inside": VoidZone.is_inside(),
			"depth": snappedf(VoidZone.depth, 0.001),
			"dread": snappedf(VoidZone.dread, 0.001),
			"shroud": snappedf(VoidZone.shroud, 0.001),
			"exposure": snappedf(VoidZone.exposure, 0.1),
		},
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
		var target := NavSystem.get_target()
		if target:
			var sol := TrackingSolution.solve(ship.global_position, ship.linear_velocity, target.get_position(), target.get_velocity())
			s["tracking"] = {
				"label": target.get_label(),
				"distance": snappedf(sol.distance, 0.1),
				"closing_speed": snappedf(sol.closing_speed, 0.1),
				"drift_speed": snappedf(sol.drift_speed, 0.1),
				"eta": null if is_inf(sol.eta) else snappedf(sol.eta, 0.1),
			}
	return s

## First node in a group, e.g. pt.node("pause_menu").visible
func node(group: String) -> Node:
	return get_tree().get_first_node_in_group(group)

## Loose gems floating in space.
func gem_count() -> int:
	return Gem.active.size()

## Gems left at wrecks (never expire).
func wreck_gem_count() -> int:
	return Gem.wreck_rows().size()

## The live ship explosion, or null.
func explosion() -> ShipExplosion:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	for child in ship.get_parent().get_children():
		if child is ShipExplosion:
			return child
	return null

## Teleport the ship onto the first wreck gem, at rest.
func warp_to_wreck() -> void:
	var rows := Gem.wreck_rows()
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if rows.is_empty() or not ship:
		return
	warp_to(Vector2(rows[0][1], rows[0][2]) + Vector2(30, 0))

## Teleport the ship to `pos`, at rest.
## Harvestable nodes of a given ScrapNode.kind ("Scrap", "Container", "Derelict").
func count_kind(kind: String) -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if node is ScrapNode and (node as ScrapNode).kind == kind:
			total += 1
	return total

## The closest harvestable node of `kind`, for warping to and salvaging.
func nearest_kind(kind: String) -> ScrapNode:
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	if not ship:
		return null
	var best: ScrapNode = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("resource_nodes"):
		if not (node is ScrapNode) or (node as ScrapNode).kind != kind:
			continue
		var d: float = ship.global_position.distance_squared_to((node as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

## Write the save file now, without having to dock or die for it.
func save_now() -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if gs and ship:
		Save.save(gs, ship)

## Park a value under `key` so a later assert can compare against it. Scenarios have no
## variables of their own, so this is how a run says "the same as before".
func remember(key: String, value: Variant) -> Variant:
	notes[key] = value
	return value

func recall(key: String, fallback: Variant = null) -> Variant:
	return notes.get(key, fallback)

func warp_to(pos: Vector2) -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	var rid := ship.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(ship.rotation, pos))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	ship.global_position = pos

## A planet (or moon) by node name, e.g. pt.planet("Rook").
func planet(planet_name: String) -> Planet:
	for n in get_tree().get_nodes_in_group("planets"):
		if n.name == planet_name:
			return n
	return null

## Park the ship `dist` px from a planet's centre at `angle_deg` (0 = +x), riding along
## with the planet, nose pointing away from it. With `orbit`, the ship also gets the
## circular-orbit velocity for that distance, so it holds station instead of falling -
## needed by anything that has to sit in the gravity well for a while (a planet scan).
func park_near_planet(planet_name: String, dist: float, angle_deg := 180.0, orbit := false) -> void:
	var p := planet(planet_name)
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if not p or not ship:
		return
	var dir := Vector2.from_angle(deg_to_rad(angle_deg))
	var pos := p.global_position + dir * dist
	var velocity := p.linear_velocity
	if orbit:
		velocity += dir.orthogonal() * orbital_speed(p, ship, dist)
	var rid := ship.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(dir.angle(), pos))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, velocity)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	ship.global_position = pos
	ship.rotation = dir.angle()

## Speed of a circular orbit `dist` px out: PlanetGravityField pulls with
## mass * G / dist^2, so v = sqrt(pull * dist / ship mass).
static func orbital_speed(p: Planet, ship: Ship, dist: float) -> float:
	var pull := p.mass * p.gravitational_constant / maxf(dist * dist, 1.0)
	return sqrt(pull * dist / ship.mass)

## Hover `height` px above a planet's first ore seam (from its surface), nose tilted
## `tilt_deg` off straight up, falling toward it at `descent` px/s relative to the planet.
func hover_over_ore(planet_name: String, height: float, tilt_deg := 0.0, descent := 0.0) -> void:
	var p := planet(planet_name)
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	var seam := p.get_ore_deposits()[0]
	var up := seam.normal()
	var pos := seam.global_position + up * (PlanetLandedState.LANDED_HEIGHT + height)
	var rid := ship.get_rid()
	var rot := up.angle() + deg_to_rad(tilt_deg)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(rot, pos))
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, p.linear_velocity - up * descent)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	ship.global_position = pos
	ship.rotation = rot

## Reload from the save (as CONTINUE does) and wait for the load to finish, so the next
## command sees the loaded world. Fails when there is no save to load.
func _reload(reply: Dictionary) -> void:
	if not Save.save_exists():
		reply["ok"] = false
		reply["error"] = "reload: no save file yet"
		return
	var main := get_tree().get_first_node_in_group("main")
	await main.load_game()
	await _frames(2)
	reply["state"] = state_name()

## True when a save file exists (scenarios that reload should check this first).
func save_exists() -> bool:
	return Save.save_exists()

## The landed ship's drill (pt.drill().timing, .layer, .phase), or null.
func drill() -> OreDrill:
	var ship := get_tree().get_first_node_in_group("ship")
	return ship.get_node_or_null("OreDrill") if ship else null

## The first ore seam on a planet.
func ore(planet_name: String) -> OreDeposit:
	return planet(planet_name).get_ore_deposits()[0]

## Height of the ship's centre above a planet's surface.
func altitude(planet_name: String) -> float:
	var p := planet(planet_name)
	var ship := get_tree().get_first_node_in_group("ship") as Node2D
	return ship.global_position.distance_to(p.global_position) - p.radius * p.collision_radius_ratio

## Ship speed relative to a planet.
func rel_speed(planet_name: String) -> float:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	return (ship.linear_velocity - planet(planet_name).linear_velocity).length()

## Warp back to the home port and dock (as if the player had flown in).
func redock() -> void:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	var port := node("space_ports") as Node2D
	warp_to(port.get_dock_position())
	ship.set_meta("pending_dockable", port)
	ship.state_machine.change_state("LandedState")

## The ship's PlanetScanner (pt.scanner().progress(), .target()).
func scanner() -> PlanetScanner:
	var ship := get_tree().get_first_node_in_group("ship")
	return ship.get_node_or_null("PlanetScanner") if ship else null

## Show `text` as a caption at the top of the screen (for recorded videos); "" hides it.
func caption(text: String) -> void:
	var label := _caption
	if not is_instance_valid(label):
		var layer := CanvasLayer.new()
		layer.layer = 100
		layer.name = "CaptionLayer"
		add_child(layer)
		label = Label.new()
		label.name = "Caption"
		# Top left: the scan panel owns the top right, the minimap the bottom left
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.offset_left = 16
		label.offset_top = 16
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Colors.PRIMARY)
		var box := StyleBoxFlat.new()
		box.bg_color = Colors.UI_BACKGROUND
		box.border_color = Colors.UI_BORDER
		box.set_border_width_all(2)
		box.set_content_margin_all(10)
		label.add_theme_stylebox_override("normal", box)
		layer.add_child(label)
		_caption = label
	label.text = text
	label.visible = text != ""

## Abandoned ships in the world.
## Ships the player abandoned. Wrecks the encounter field put in deep space share the
## group but are not the player's, so they don't count here.
func derelict_count() -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("derelicts"):
		if node is DerelictShip and not (node as DerelictShip).transient:
			total += 1
	return total

## The ship the player abandoned, ignoring any deep-space wreck that happens to be loaded.
func abandoned_ship() -> DerelictShip:
	for node in get_tree().get_nodes_in_group("derelicts"):
		if node is DerelictShip and not (node as DerelictShip).transient:
			return node
	return null

## Drop a loose gem `offset` px from the ship, moving at the ship's velocity plus `rel_velocity`.
func spawn_gem(id: String, offset: Vector2, rel_velocity := Vector2.ZERO) -> Gem:
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	return Gem.spawn(ship.get_parent(), id, ship.global_position + offset, ship.linear_velocity + rel_velocity, Vector2.ZERO)

## Pickup popups shown so far, summed per gem id: {"gem": 3, ...}. Compare with inv.get_all_items().
func popup_counts() -> Dictionary:
	var counts := {}
	for line in get_tree().get_first_node_in_group("resource_manager").shown:
		if GemData.is_gem(line["style"]):
			assert(line["color"] == GemData.color_of(line["style"]))
			counts[line["style"]] = counts.get(line["style"], 0) + line["amount"]
	return counts

## Total number of gems in the hold across all stacks.
func item_count() -> int:
	var total := 0
	for q in InventoryManager.get_all_items().values():
		total += int(q)
	return total

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
