extends GdUnitTestSuite

## The pool owns what it hands out. A node freed behind its back must never be handed out
## again, and returning a freed node is a loud error rather than a silent no-op.

const VARIANT := "Scrap1"

var _taken: Array = []
var _returning: Variant = null  # a member, not a lambda capture: lambdas null out freed captures

func after_test() -> void:
	for node in _taken:
		if is_instance_valid(node):
			ResourceNodePool.return_instance(node)
	_taken.clear()

func _take() -> void:
	_taken.append(ResourceNodePool.get_instance(VARIANT, self))

func _give_back() -> void:
	ResourceNodePool.return_instance(_returning)

func test_a_freed_node_parked_in_the_pool_is_dropped_not_handed_out() -> void:
	var node := ResourceNodePool.get_instance(VARIANT, self)
	ResourceNodePool.return_instance(node)
	node.free()  # the bug: something else owned it too

	await assert_error(_take).is_push_error(
		"ResourceNodePool: dropped a freed %s instance; something freed a pooled node instead of returning it" % VARIANT)
	assert_int(_taken.size()).is_equal(1)
	assert_bool(is_instance_valid(_taken[0])).is_true()

func test_returning_a_freed_node_errors_loudly() -> void:
	_returning = ResourceNodePool.get_instance(VARIANT, self)
	var in_use_before: int = ResourceNodePool.get_stats()[VARIANT]["in_use"]
	_returning.free()

	await assert_error(_give_back).is_push_error(
		"ResourceNodePool: a freed node was returned to the pool; pooled nodes must be returned, never freed")
	assert_int(ResourceNodePool.get_stats()[VARIANT]["in_use"]).is_equal(in_use_before - 1)

func test_returning_null_is_a_quiet_no_op() -> void:
	_returning = null
	await assert_error(_give_back).is_success()
