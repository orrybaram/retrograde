extends Node2D
## Claw Lab - a bench for flying Freight into the DORSAL ARM's claw (DorsalClaw).
##
## The real SR-7 (held still, every piece home, the core running) and its DORSAL ARM claw
## (DorsalClaw), with the catch radius drawn; the real ship, with a Cargo Bay on its nose. Fly it to the drop point off the right mast and hold
## ACTION to let go. Nothing here is in the shipped game, and it never touches the real
## save: saves go to user://claw_lab/.
##
##   tools/clawlab.sh             windowed
##   tools/clawlab.sh --shots     stage a delivery, screenshot each beat, and quit (--flip: Lug inboard)
##
##   R   a new load on the nose, back at the start     N   a loose load to clamp
##   H   DORSAL ARM home / not yet home (its Mount)     B   empty the bay, fold the arm
##   G   drop tolerance on / off                        T   slow motion
##   ESC quit
##
## Tune the arm live from the editor's remote inspector: SpaceStation/DorsalClaw's exports.

const STATION_SCENE := preload("res://entities/structures/SpaceStation.tscn")
const SHIP_SCENE := preload("res://entities/Ship/Ship.tscn")
const SAVE_DIR := "user://claw_lab"
const SHOT_DIR := "res://.playtest/clawlab"
## Where the ship starts, in the station's space: out to the right, level with the drop
## point, nose toward the station.
const START := Vector2(560, -640)
## Where the folded DORSAL ARM hangs while it is not home, in the station's space.
const ARM_WAITS_AT := Vector2(-320, -780)

var station: SpaceStation
var claw: DorsalClaw
var ship: Ship
var _hud: Label
var _prompt := ""
var _last := ""

func _ready() -> void:
	DisplayServer.window_set_title("RETROGRADE  //  CLAW LAB")
	_isolate_save()
	_build_backdrop()
	var gs := GameState.new()
	gs.name = "GameState"
	gs.mark_station_whole()
	gs.core_started = true
	add_child(gs)
	_build_station()
	ship = SHIP_SCENE.instantiate() as Ship
	# Main.tscn's overrides on its Ship: the scene's own mass is a placeholder
	ship.mass = 3.0
	ship.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	ship.fuel_consumption_rate = 2.0
	add_child(ship)
	_build_hud()
	EventBus.action_message_changed.connect(func(msg: String) -> void: _prompt = msg)
	claw.delivered.connect(func(id: String) -> void: _last = "%s delivered" % Components.label(id))
	_new_load.call_deferred(true)
	if "--probe" in OS.get_cmdline_user_args():
		_probe.call_deferred()
	if "--shots" in OS.get_cmdline_user_args():
		_shoot.call_deferred()

## Saves (a dock, say) go to the lab's own file, never the player's.
func _isolate_save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	Playtest._save_file = SAVE_DIR + "/save.cfg"
	Playtest.active = true

func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	var bg := ColorRect.new()
	bg.color = Colors.SPACE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	add_child(layer)

func _build_station() -> void:
	station = STATION_SCENE.instantiate() as SpaceStation
	station.freeze = true
	add_child(station)
	claw = Cradle.find(get_tree()) as DorsalClaw
	claw.show_tolerance = true

## Put the DORSAL ARM home, or take it away again, the way a save would: the Mount shows
## the arm or the cut, and the claw follows. Taken away, the folded arm hangs at
## ARM_WAITS_AT to be fetched and seated.
func _set_arm_home(home: bool) -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if home:
		gs.mark_section_seated(Sections.DORSAL_ARM)
	else:
		gs.seated_sections.erase(Sections.DORSAL_ARM)
	var m := Mount.for_section(get_tree(), Sections.DORSAL_ARM)
	m.refresh()
	claw.refresh()
	# Not home: the folded arm hangs just above the station, to fetch and seat
	for f in get_tree().get_nodes_in_group("freight"):
		if f is Freight and f.section == Sections.DORSAL_ARM:
			f.lodge_in(station, ARM_WAITS_AT, 0.4)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	_hud = Label.new()
	_hud.position = Vector2(20, 16)
	_hud.add_theme_color_override("font_color", Colors.PRIMARY)
	_hud.add_theme_font_override("font", load("res://assets/fonts/Andale Mono.ttf"))
	_hud.add_theme_font_size_override("font_size", 14)
	layer.add_child(_hud)
	add_child(layer)

func _process(_delta: float) -> void:
	var state := claw.state_machine.get_current_state_name() if claw.state_machine else ""
	_hud.text = "C L A W   L A B\n\nCLAW    %s\nBAY     %s\nPROMPT  %s\n%s\n\nR new load   N loose load   H arm home   B reset bay\nG tolerance   T slow motion   ESC quit" % [
		state.trim_prefix("Claw").to_upper(),
		"BUSY" if claw.is_full() else "OPEN",
		_prompt,
		_last,
	]

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_R: _new_load(true)
		KEY_N: _new_load(false)
		KEY_H: _set_arm_home(not claw.arm_home())
		KEY_B: claw.refresh()
		KEY_G: claw.show_tolerance = not claw.show_tolerance
		KEY_T: Engine.time_scale = 0.25 if Engine.time_scale > 0.5 else 1.0

## Put the ship back at the start, still, with a fresh Cargo Bay: clamped on the nose, or
## floating just ahead of it to be clamped by hand.
func _new_load(clamped: bool) -> void:
	for f in get_tree().get_nodes_in_group("freight"):
		if f is Freight and f.component != "":
			if ship.is_carrying() and ship.freight == f:
				ship.let_go()
			f.queue_free()
	_place_ship(station.global_transform * Transform2D(PI, START))
	var f := Freight.new()
	Components.apply(f, Components.CARGO_BAY)
	add_child(f)
	var nose := Transform2D(ship.global_rotation, ship.global_position) * Freight.clamped_pose(f.lug_position, f.lug_facing, Ship.NOSE)
	f.global_transform = nose
	if clamped:
		ship.carry(f, true)
	else:
		f.global_position += Vector2.from_angle(ship.global_rotation) * 8.0
	_last = ""

func _place_ship(xf: Transform2D) -> void:
	var rid := ship.get_rid()
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(rid, PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	ship.global_transform = xf

# --- --shots -------------------------------------------------------------------------------

## Stage the ship with its load at the drop point, let go, and screenshot each beat.
func _shoot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await _frames(20)
	while not ship.is_carrying():
		await get_tree().process_frame
	# The ship's pose that puts its load exactly on the drop point
	# Off the drop point and turned, the way a real approach arrives; --flip brings it in
	# the other way round, Lug inboard
	var turn := deg_to_rad(215.0 if "--flip" in OS.get_cmdline_user_args() else 35.0)
	var drop := Transform2D(PI + turn, claw.global_transform * (claw.drop_point + Vector2(20, -25)))
	_place_ship(drop * ship.freight.transform.affine_inverse())
	await _snap("00_at_drop", 0.2)
	await _snap("01_reaching", 0.6)
	await _snap("02_latched", 0.7)
	var f := ship.let_go()
	claw.seat(f)
	_place_ship(ship.global_transform.translated(Vector2(120, 0)))
	await _snap("03_swing", 0.8)
	await _snap("04_set", 1.3)
	await _snap("05_stowing", 1.0)
	await _snap("06_sinking", 1.0)
	await _snap("07_taken", 1.2)
	await _snap("08_reopened", 1.6)
	_set_arm_home(false)
	await _snap("09_arm_not_home", 0.5)
	get_tree().quit()

func _snap(n: String, after: float) -> void:
	await get_tree().create_timer(after).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT_DIR + "/" + n + ".png"))
	print("CLAWLAB shot ", n, " claw=", claw.state_machine.get_current_state_name(), " wrist=", claw.wrist, " jaw=", snappedf(claw.jaw, 0.01), " pad=", snappedf(claw.pad_drop, 0.1), " beam=", snappedf(claw.beam, 0.01), " prompt=", _prompt, " piece=", claw.piece != null)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _probe() -> void:
	await _frames(30)
	print("PROBE start pos=", ship.global_position, " state=", ship.state_machine.get_current_state_name(), " sleeping=", ship.sleeping, " freeze=", ship.freeze, " cruise=", ship.cruise_speed, " thrust=", ship.thrust_power, " mass=", ship.mass, " mode=", ship.process_mode, " paused=", get_tree().paused)
	Input.action_press("thrust")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("thrust")
	print("PROBE after thrust pos=", ship.global_position, " vel=", ship.linear_velocity, " want=", ship.want_thrust)
	for dy in [-80.0, 0.0, 80.0]:
		_place_ship(claw.drop_pose().translated(Vector2(250, dy)) * ship.freight.transform.affine_inverse())
		await _frames(3)
		var names := claw.slope_lamps().map(func(c: Color) -> String: return "GREEN" if c == Colors.SAGE else ("RED" if c == Colors.RUST_RED else "AMBER"))
		print("PROBE lamps dy=", dy, " ", names)
	_place_ship(claw.drop_pose() * ship.freight.transform.affine_inverse())
	await get_tree().create_timer(1.5).timeout
	print("PROBE at drop claw=", claw.state_machine.get_current_state_name(), " prompt=", _prompt)
	Input.action_press("action")
	await get_tree().create_timer(1.2).timeout
	Input.action_release("action")
	print("PROBE after hold claw=", claw.state_machine.get_current_state_name(), " carrying=", ship.is_carrying(), " piece=", claw.piece != null)
	get_tree().quit()
