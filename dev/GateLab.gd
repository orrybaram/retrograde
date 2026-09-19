extends Node2D
## Gate Lab — a bench for arguing about what a Gate looks like.
##
## Every variant lives in `dev/gate_styles/` and draws the same Gate: same radius, same
## mouth at the bottom, same cradle across it, so the only thing under test is the
## construction. Nothing here is in the shipped game; when a look wins, it gets ported
## into `entities/structures/Gate.gd` and the lab keeps the losers around for reference.
##
##   tools/gatelab.sh              windowed, drive it with the keys below
##   tools/gatelab.sh --shots      writes every variant, dormant and powered, and quits
##
##   LEFT / RIGHT   pick a variant        ENTER   solo <-> grid
##   P              power it up / down    R       restart the power-up ramp
##   S              screenshot this view  A       screenshot every variant
##   1 - 9          jump to a variant     ESC     quit
##
## Shots land in `.playtest/gatelab/`.

const STYLE_SCRIPTS := [
	"res://dev/gate_styles/BezelStyle.gd",
	"res://dev/gate_styles/VeinStyle.gd",
	"res://dev/gate_styles/GlyphStyle.gd",
	"res://dev/gate_styles/HengeStyle.gd",
	"res://dev/gate_styles/SlabStyle.gd",
	"res://dev/gate_styles/CairnStyle.gd",
	"res://dev/gate_styles/KeystoneStyle.gd",
]

const SHOT_DIR := "res://.playtest/gatelab"
## Every style draws at this radius (GateStyle.RADIUS), matching Gate.RADIUS.
const RADIUS := 100.0
## Matches Gate.POWER_UP_TIME, so the ramp reads the way it will in the game.
const POWER_UP_TIME := 1.6
const COLUMNS := 3
const SOLO_SCALE := 1.55

var _styles: Array = []
var _selected := 0
var _solo := false
var _powered := false
var _glow := 0.0
var _clock := 0.0
var _busy := false
var _font: Font = load("res://assets/fonts/Andale Mono.ttf")

func _ready() -> void:
	for path in STYLE_SCRIPTS:
		_styles.append((load(path) as GDScript).new())
	DisplayServer.window_set_title("RETROGRADE  //  GATE LAB")
	if "--shots" in OS.get_cmdline_user_args():
		_shoot_everything.call_deferred()

func _process(delta: float) -> void:
	_clock += delta
	var target := 1.0 if _powered else 0.0
	if not is_equal_approx(_glow, target):
		_glow = move_toward(_glow, target, delta / POWER_UP_TIME)
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _busy:
		return
	match key.keycode:
		KEY_ESCAPE: get_tree().quit()
		KEY_LEFT: _selected = wrapi(_selected - 1, 0, _styles.size())
		KEY_RIGHT: _selected = wrapi(_selected + 1, 0, _styles.size())
		KEY_ENTER, KEY_KP_ENTER: _solo = not _solo
		KEY_P: _powered = not _powered
		KEY_R: _glow = 0.0
		KEY_S: _shoot_view(_current().id + ("_on" if _powered else "_off"))
		KEY_A: _shoot_everything()
		_:
			var n := key.keycode - KEY_1
			if n >= 0 and n < _styles.size():
				_selected = n
				_solo = true

func _current():
	return _styles[_selected]

# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Colors.SPACE_BG, true)
	if _solo:
		_draw_solo(size)
	else:
		_draw_grid(size)
	_draw_chrome(size)

func _draw_grid(size: Vector2) -> void:
	var rows := int(ceil(float(_styles.size()) / COLUMNS))
	var cell := Vector2(size.x / COLUMNS, (size.y - 104.0) / rows)
	# A Gate is about 340 x 320 drawn, plus room under it for the two labels.
	var scale: float = minf(cell.x / 360.0, (cell.y - 52.0) / 330.0)
	for i in _styles.size():
		var at := Vector2(cell.x * (i % COLUMNS) + cell.x / 2.0,
			62.0 + cell.y * (i / COLUMNS) + cell.y / 2.0 - 16.0)
		if i == _selected:
			_draw_selection(at, cell)
		draw_set_transform(at, 0.0, Vector2.ONE * scale)
		_styles[i].draw_gate(self, _glow, _clock)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_label(at + Vector2(0, cell.y / 2.0 - 34.0), "%d. %s" % [i + 1, _styles[i].title],
			Colors.PRIMARY if i == _selected else Colors.PRIMARY_DIM, 15)
		_label(at + Vector2(0, cell.y / 2.0 - 16.0), _styles[i].blurb,
			Color(Colors.TEXT_MUTED, 0.75 if i == _selected else 0.4), 11)

## A bracket around the picked cell, drawn the way the terminal UI marks a row.
func _draw_selection(at: Vector2, cell: Vector2) -> void:
	var box := Rect2(at - cell / 2.0 + Vector2(10, 8), cell - Vector2(20, 16))
	var arm := 14.0
	for corner in [box.position, Vector2(box.end.x, box.position.y),
			Vector2(box.position.x, box.end.y), box.end]:
		var sx: float = -1.0 if corner.x > box.get_center().x else 1.0
		var sy: float = -1.0 if corner.y > box.get_center().y else 1.0
		draw_line(corner, corner + Vector2(arm * sx, 0), Colors.PRIMARY_FADED, 1.5)
		draw_line(corner, corner + Vector2(0, arm * sy), Colors.PRIMARY_FADED, 1.5)

func _draw_solo(size: Vector2) -> void:
	var at := Vector2(size.x / 2.0, size.y / 2.0 - 6.0)
	draw_set_transform(at, 0.0, Vector2.ONE * SOLO_SCALE)
	_current().draw_gate(self, _glow, _clock)
	_draw_ship_for_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_label(Vector2(size.x / 2.0, size.y - 74.0), _current().title, Colors.PRIMARY, 22)
	_label(Vector2(size.x / 2.0, size.y - 52.0), _current().blurb, Colors.TEXT_MUTED, 13)

## The ship parked in the cradle, so chunkiness can be judged against the thing that
## has to fit there. Same silhouette the HUD uses: a nose-up wedge.
func _draw_ship_for_scale() -> void:
	var at := Vector2(0, RADIUS - 12.0)
	var hull := PackedVector2Array([
		at + Vector2(0, -11), at + Vector2(8, 7), at + Vector2(0, 3), at + Vector2(-8, 7),
	])
	draw_colored_polygon(hull, Color(Colors.PRIMARY, 0.22))
	draw_polyline(hull, Color(Colors.PRIMARY, 0.55), 1.2, true)

func _draw_chrome(size: Vector2) -> void:
	_label(Vector2(size.x / 2.0, 34.0), "G A T E   L A B", Colors.PRIMARY, 18)
	var state := "POWERED" if _powered else "DORMANT"
	var view := "SOLO" if _solo else "GRID"
	_label(Vector2(size.x / 2.0, 54.0),
		"%s   //   %s   //   %d of %d" % [view, state, _selected + 1, _styles.size()],
		Colors.PRIMARY_DIM, 12)
	_label(Vector2(size.x / 2.0, size.y - 18.0),
		"LEFT/RIGHT pick    ENTER solo    P power    R replay ramp    S shot    A shot all    ESC quit",
		Color(Colors.TEXT_MUTED, 0.5), 11)

func _label(at: Vector2, text: String, color: Color, size_px: int) -> void:
	draw_string(_font, at - Vector2(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		-1, size_px).x / 2.0, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

# --- Shots -------------------------------------------------------------------

func _shoot_view(shot_name: String) -> void:
	_busy = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOT_DIR, shot_name]
	image.save_png(path)
	print("shot  ", ProjectSettings.globalize_path(path))
	_busy = false

## Every variant, dormant and powered, solo. What to look at when picking one.
func _shoot_everything() -> void:
	var was_solo := _solo
	var was_powered := _powered
	var was_selected := _selected
	_solo = true
	for i in _styles.size():
		_selected = i
		for on in [false, true]:
			_powered = on
			_glow = 1.0 if on else 0.0
			_clock = 3.4 if on else 0.9  # a pose partway through the pulse, not a trough
			queue_redraw()
			await _shoot_view("%d_%s_%s" % [i + 1, _styles[i].id, "on" if on else "off"])
	# Two contact sheets: every variant at once, dead and running. What to look at
	# first when picking one.
	_solo = false
	for on in [false, true]:
		_powered = on
		_glow = 1.0 if on else 0.0
		_clock = 3.4 if on else 0.9
		queue_redraw()
		await _shoot_view("all_%s" % ["on" if on else "off"])
	_solo = was_solo
	_powered = was_powered
	_selected = was_selected
	_glow = 1.0 if _powered else 0.0
	if "--shots" in OS.get_cmdline_user_args():
		get_tree().quit()
