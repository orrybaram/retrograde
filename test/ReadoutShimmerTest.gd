extends GdUnitTestSuite

## What a Sweep read shimmers in the world, then settles back (ui/ReadoutShimmer.gd).

var _shimmer: ReadoutShimmer

func before_test() -> void:
	_shimmer = auto_free(ReadoutShimmer.new()) as ReadoutShimmer
	add_child(_shimmer)

func _readout(title: String) -> SweepReadout:
	var owner_node := auto_free(Node2D.new()) as Node2D
	add_child(owner_node)
	var r := SweepReadout.new()
	r.key = "shimmer_" + title
	r.heading = "MOUNT"
	r.title = title
	owner_node.add_child(r)
	return r

func _glow(node: CanvasItem) -> float:
	return (node.material as ShaderMaterial).get_shader_parameter("glow")


func test_the_thing_itself_lights_up() -> void:
	var r := _readout("FUEL TANK")
	var owner_node := r.get_parent() as Node2D
	_shimmer.show_read(r, 1, [])
	_shimmer._process(ReadoutShimmer.RISE)
	assert_bool(_shimmer.is_shimmering(owner_node)).is_true()
	assert_object(owner_node.material).is_instanceof(ShaderMaterial)
	assert_float(_glow(owner_node)).is_greater(0.5)


func test_what_it_draws_under_it_shimmers_with_it() -> void:
	var r := _readout("FUEL TANK")
	var owner_node := r.get_parent() as Node2D
	var part := Polygon2D.new()
	owner_node.add_child(part)
	var own := CanvasItemMaterial.new()
	var lit := Sprite2D.new()
	lit.material = own
	owner_node.add_child(lit)
	_shimmer.show_read(r, 1, [])
	assert_object(part.material).is_same(owner_node.material)
	assert_object(lit.material).override_failure_message("keeps a material of its own").is_same(own)
	assert_object(r.material).override_failure_message("the readout draws nothing").is_null()


func test_it_dies_down_and_gives_the_material_back() -> void:
	var r := _readout("FUEL TANK")
	var owner_node := r.get_parent() as Node2D
	var part := Polygon2D.new()
	owner_node.add_child(part)
	_shimmer.show_read(r, 1, [])
	_shimmer._process(0.01)
	_shimmer._process(ReadoutShimmer.DURATION)
	assert_int(_shimmer.count()).is_equal(0)
	assert_object(owner_node.material).is_null()
	assert_object(part.material).is_null()


func test_it_comes_up_fast_and_dies_down() -> void:
	assert_float(ReadoutShimmer.glow_at(0.0)).is_equal(0.0)
	assert_float(ReadoutShimmer.glow_at(ReadoutShimmer.RISE)).is_greater(0.8)
	assert_float(ReadoutShimmer.glow_at(ReadoutShimmer.DURATION * 0.5)).is_between(0.05, 0.6)
	assert_float(ReadoutShimmer.glow_at(ReadoutShimmer.DURATION)).is_equal(0.0)


func test_reading_it_again_shimmers_it_again_not_twice() -> void:
	var r := _readout("FUEL TANK")
	var owner_node := r.get_parent() as Node2D
	_shimmer.show_read(r, 1, [])
	_shimmer._process(ReadoutShimmer.DURATION * 0.8)
	_shimmer.show_read(r, 2, [])
	assert_int(_shimmer.count()).is_equal(1)
	_shimmer._process(ReadoutShimmer.DURATION * 0.5)
	assert_bool(_shimmer.is_shimmering(owner_node)).override_failure_message("its clock started over").is_true()


func test_something_of_the_titans_shimmers_in_its_purple() -> void:
	var r := _readout("")
	r.undecipherable = true
	var owner_node := r.get_parent() as Node2D
	_shimmer.show_read(r, 1, [])
	var tint: Color = (owner_node.material as ShaderMaterial).get_shader_parameter("tint")
	assert_object(tint).is_equal(Colors.TITAN)


func test_a_thing_gone_takes_its_shimmer() -> void:
	var r := _readout("FUEL TANK")
	_shimmer.show_read(r, 1, [])
	r.get_parent().free()
	_shimmer._process(0.1)
	assert_int(_shimmer.count()).is_equal(0)


func test_clearing_gives_the_material_back_at_once() -> void:
	var r := _readout("FUEL TANK")
	var owner_node := r.get_parent() as Node2D
	_shimmer.show_read(r, 1, [])
	_shimmer._process(0.01)
	_shimmer.clear_now()
	assert_object(owner_node.material).is_null()


class ElsewhereOwner extends Node2D:
	var look: CanvasItem
	func shimmer_items() -> Array[CanvasItem]:
		return [self, look]


func test_an_owner_can_name_a_look_that_lives_elsewhere() -> void:
	var owner_node := auto_free(ElsewhereOwner.new()) as ElsewhereOwner
	var look := auto_free(Polygon2D.new()) as Polygon2D
	add_child(owner_node)
	add_child(look)
	owner_node.look = look
	var r := SweepReadout.new()
	owner_node.add_child(r)
	_shimmer.show_read(r, 1, [])
	assert_object(look.material).is_same(owner_node.material)
	_shimmer.clear_now()
	assert_object(look.material).is_null()
