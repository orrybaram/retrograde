extends Node
class_name ReadoutShimmer

## What a Sweep just read shimmers (docs/SWEEP.md §10): bands of light run across the thing
## itself, in the world, and die down, so the eye knows which thing answered before it reads
## the rows in the corner (ContactLog). No words over it. Something of the Titan's shimmers in
## its purple. The light is added on top (ReadoutShimmer.gdshader), so dark hull lights up too.
## It lends its material to the owner and every CanvasItem under it that has none of its own,
## and takes it back after. An owner whose look lives elsewhere names it with
## `shimmer_items() -> Array[CanvasItem]` (a Mount: its seated Section is the station's).

const SHADER := preload("res://ui/ReadoutShimmer.gdshader")
## Seconds a shimmer lasts, and how many bands run past any one point in that time.
const DURATION := 1.6
const WAVES := 3.0
## Seconds it takes to come up to full.
const RISE := 0.12

## Oldest first. Each: {id: the owner's instance id, material, lent: instance ids of the nodes
## wearing it, age}.
var _shimmers: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("readout_shimmer")
	# Main.clear_screen_effects: a new game, a load or a quit to the menu clears it
	add_to_group("screen_effects")
	EventBus.readout_swept.connect(show_read)


## Shimmer the thing `readout` is part of.
func show_read(readout: Node, _tier: int, _rows: Array) -> void:
	var r := readout as SweepReadout
	if r == null:
		return
	var owner_node := r.get_parent() as CanvasItem
	if owner_node == null:
		return
	var id := owner_node.get_instance_id()
	for s in _shimmers:
		if s.id == id:
			s.age = 0.0
			return
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tint", Colors.TITAN if r.undecipherable else Colors.CREAM)
	mat.set_shader_parameter("glow", 0.0)
	var roots: Array = owner_node.shimmer_items() if owner_node.has_method("shimmer_items") else [owner_node]
	var lent: Array[int] = []
	for root: CanvasItem in roots:
		for node in _canvas_items(root):
			if node != r and node.material == null and not node.use_parent_material:
				node.material = mat
				lent.append(node.get_instance_id())
	_shimmers.append({"id": id, "material": mat, "lent": lent, "age": 0.0})


## Whether `node` is shimmering right now.
func is_shimmering(node: CanvasItem) -> bool:
	var id := node.get_instance_id()
	return _shimmers.any(func(s: Dictionary) -> bool: return s.id == id)


## How many things are shimmering.
func count() -> int:
	return _shimmers.size()


## How bright a shimmer `age` seconds in is: up fast, then dying down to 0 at DURATION.
static func glow_at(age: float) -> float:
	if age >= DURATION:
		return 0.0
	return clampf(age / RISE, 0.0, 1.0) * pow(1.0 - age / DURATION, 1.2)


func clear_now() -> void:
	while not _shimmers.is_empty():
		_drop(0)


func _process(dt: float) -> void:
	for i in range(_shimmers.size() - 1, -1, -1):
		var s: Dictionary = _shimmers[i]
		var node := instance_from_id(s.id) as CanvasItem
		if node == null or not is_instance_valid(node):
			_shimmers.remove_at(i)
			continue
		s.age += dt
		if s.age >= DURATION:
			_drop(i)
			continue
		var mat: ShaderMaterial = s.material
		mat.set_shader_parameter("glow", glow_at(s.age))
		mat.set_shader_parameter("sweep", s.age / DURATION * WAVES)


func _canvas_items(root: Node) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	if root is CanvasItem:
		out.append(root)
	for child in root.get_children():
		out.append_array(_canvas_items(child))
	return out


func _drop(i: int) -> void:
	var s: Dictionary = _shimmers[i]
	for lent_id: int in s.lent:
		var node := instance_from_id(lent_id) as CanvasItem
		if node and is_instance_valid(node) and node.material == s.material:
			node.material = null
	_shimmers.remove_at(i)
