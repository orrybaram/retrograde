extends Control
class_name TrackingIndicator

## HUD guide to the player's tracked target (see NavSystem).
## Off screen: an outlined chevron on the screen edge pointing at the target,
## with a small unboxed readout of distance, closing speed and drift.
## On screen: a diamond over the target with name and distance.

const EDGE_MARGIN := 40.0
const ARROW_SIZE := 7.0
const MARKER_SIZE := 9.0
const READOUT_GAP := 20.0
const HOLDING_SPEED := 2.0
const LABEL_FONT_SIZE := 10
const READOUT_FONT_SIZE := 9
const READOUT_DETAIL_FONT_SIZE := 7
const READOUT_ALPHA := 0.8

var color: Color = Colors.NAV
## HUD panels the chevron and readout must not cover.
var blockers: Array[Control] = []
var ship: Ship = null
var solution: TrackingSolution = null

var _readout: VBoxContainer
var _readout_title: Label
var _readout_detail: Label
var _marker_label: Label
var _origin := Vector2.ZERO
var _screen_pos := Vector2.ZERO
var _on_screen := false

func _ready() -> void:
	name = "TrackingIndicator"
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_readout = VBoxContainer.new()
	_readout.mouse_filter = MOUSE_FILTER_IGNORE
	_readout.add_theme_constant_override("separation", 1)
	# Containers grow on their own but never shrink back.
	_readout.minimum_size_changed.connect(_readout.reset_size)
	add_child(_readout)
	_readout_title = _make_label(READOUT_FONT_SIZE, Color(color, READOUT_ALPHA), _readout)
	_readout_detail = _make_label(READOUT_DETAIL_FONT_SIZE, Color(color, READOUT_ALPHA * 0.85), _readout)
	_marker_label = _make_label(LABEL_FONT_SIZE, color)
	_set_active(false)

func _process(_delta: float) -> void:
	var target := NavSystem.get_target()
	if not _gameplay_active() or target == null or _edge_rect().size.x <= 0.0 or _edge_rect().size.y <= 0.0:
		_set_active(false)
		return

	solution = TrackingSolution.solve(ship.global_position, ship.linear_velocity, target.get_position(), target.get_velocity())
	if solution.distance <= target.get_arrival_radius():
		_set_active(false)
		return
	var to_local := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_canvas_transform()
	var rect := _edge_rect()
	_screen_pos = to_local * target.get_position()
	_origin = (to_local * ship.global_position).clamp(rect.position, rect.end)
	_on_screen = rect.has_point(_screen_pos)

	if _on_screen:
		_readout.visible = false
		_marker_label.visible = true
		_marker_label.text = "%s  %s" % [target.get_label(), TrackingSolution.format_distance(solution.distance)]
		_marker_label.reset_size()
		_marker_label.position = _screen_pos + Vector2(-_marker_label.size.x / 2.0, MARKER_SIZE + 6.0)
	else:
		_marker_label.visible = false
		_readout.visible = true
		var dir := _screen_dir()
		var lines := readout_lines(target.get_label(), solution)
		var detail := "\n".join(lines.slice(1))
		if _readout_title.text != lines[0]:
			_readout_title.text = lines[0]
		if _readout_detail.text != detail:
			_readout_detail.text = detail
		# Text aligns toward the screen edge the chevron sits on.
		var align := HORIZONTAL_ALIGNMENT_RIGHT if dir.x > 0.5 else (HORIZONTAL_ALIGNMENT_LEFT if dir.x < -0.5 else HORIZONTAL_ALIGNMENT_CENTER)
		_readout_title.horizontal_alignment = align
		_readout_detail.horizontal_alignment = align
		var anchor := _edge_marker(rect, dir) - dir * READOUT_GAP
		var pos := anchor - _readout.size * ((dir + Vector2.ONE) / 2.0)
		pos = pos.clamp(Vector2.ZERO, (size - _readout.size).max(Vector2.ZERO))
		# Slides the same way the chevron did, so the two stay together.
		pos = push_rect_out_of(Rect2(pos, _readout.size), _blocked_rects()).position
		_readout.position = pos
	queue_redraw()

func _draw() -> void:
	if not solution:
		return
	if _on_screen:
		var s := MARKER_SIZE
		var pts := PackedVector2Array([
			_screen_pos + Vector2(0, -s), _screen_pos + Vector2(s, 0),
			_screen_pos + Vector2(0, s), _screen_pos + Vector2(-s, 0), _screen_pos + Vector2(0, -s)])
		draw_polyline(pts, color, 2.0)
		return

	var rect := _edge_rect()
	var dir := _screen_dir()
	var tip_base := _edge_marker(rect, dir)
	var perp := dir.orthogonal()
	var tip := tip_base + dir * ARROW_SIZE
	draw_polyline(PackedVector2Array([
		tip,
		tip_base - dir * ARROW_SIZE * 0.4 + perp * ARROW_SIZE * 0.7,
		tip_base - dir * ARROW_SIZE * 0.4 - perp * ARROW_SIZE * 0.7,
		tip,
	]), color, 1.5)

## Point on the screen edge along `dir`, slid out from under any blocker.
func _edge_marker(rect: Rect2, dir: Vector2) -> Vector2:
	return push_out_of(edge_point(rect, _origin, dir), _blocked_rects())

func _blocked_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var to_local := get_global_transform_with_canvas().affine_inverse()
	for b in blockers:
		if is_instance_valid(b) and b.is_visible_in_tree():
			var r := b.get_global_rect()
			rects.append(Rect2(to_local * r.position, r.size).grow(ARROW_SIZE))
	return rects

func _screen_dir() -> Vector2:
	var d := _screen_pos - _origin
	return d.normalized() if not d.is_zero_approx() else Vector2.RIGHT

func _edge_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-EDGE_MARGIN)

func _gameplay_active() -> bool:
	if not ship or not is_instance_valid(ship):
		ship = get_tree().get_first_node_in_group("ship") as Ship
		if not ship:
			return false
	var main := get_tree().get_first_node_in_group("main")
	if main and main.current_game_state != main.MainGameState.PLAYING:
		return false
	return not ship.is_destroyed()

func _set_active(active: bool) -> void:
	if not active:
		solution = null
		_readout.visible = false
		_marker_label.visible = false
		queue_redraw()

func _make_label(font_size: int, font_color: Color, parent: Node = self) -> Label:
	var label := Label.new()
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_constant_override("line_spacing", 2)
	# Thin dark outline keeps the text legible over stations and debris.
	label.add_theme_color_override("font_outline_color", Colors.SPACE_BG)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label

## Readout text: name + distance, closing speed (+ closing / - receding), drift.
static func readout_lines(label: String, s: TrackingSolution) -> PackedStringArray:
	var speed := "HOLD"
	if absf(s.closing_speed) >= HOLDING_SPEED:
		speed = "%+d m/s" % roundi(s.closing_speed)
	return PackedStringArray([
		"%s  %s" % [label, TrackingSolution.format_distance(s.distance)],
		speed,
		"DRIFT %d m/s" % roundi(absf(s.drift_speed)),
	])

## Where a ray from `origin` (inside `rect`) along `dir` leaves `rect`.
static func edge_point(rect: Rect2, origin: Vector2, dir: Vector2) -> Vector2:
	var t := INF
	if dir.x > 0.0:
		t = minf(t, (rect.end.x - origin.x) / dir.x)
	elif dir.x < 0.0:
		t = minf(t, (rect.position.x - origin.x) / dir.x)
	if dir.y > 0.0:
		t = minf(t, (rect.end.y - origin.y) / dir.y)
	elif dir.y < 0.0:
		t = minf(t, (rect.position.y - origin.y) / dir.y)
	if is_inf(t):
		return origin
	return origin + dir * t

## Moves `rect` just above or just right of the first blocker it overlaps,
## whichever is the shorter slide. Mirrors `push_out_of` so a readout
## anchored to a pushed chevron follows it instead of jumping over the blocker.
static func push_rect_out_of(rect: Rect2, rects: Array[Rect2]) -> Rect2:
	for r in rects:
		if not r.intersects(rect):
			continue
		var up := rect.position.y + rect.size.y - r.position.y
		var right := r.end.x - rect.position.x
		if up <= right:
			return Rect2(Vector2(rect.position.x, r.position.y - rect.size.y), rect.size)
		return Rect2(Vector2(r.end.x, rect.position.y), rect.size)
	return rect

## Moves `point` to the nearest top or right edge of the first rect containing it.
## Blockers sit in screen corners, so this keeps edge markers on the screen edge.
static func push_out_of(point: Vector2, rects: Array[Rect2]) -> Vector2:
	for r in rects:
		if not r.has_point(point):
			continue
		var up := Vector2(point.x, r.position.y)
		var right := Vector2(r.end.x, point.y)
		return up if up.distance_to(point) <= right.distance_to(point) else right
	return point
