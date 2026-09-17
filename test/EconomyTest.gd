extends GdUnitTestSuite

## Tests for Economy pricing.


func test_get_resource_price_known() -> void:
	assert_int(Economy.get_resource_price("artifact")).is_equal(250)


func test_get_resource_price_unknown_is_zero() -> void:
	assert_int(Economy.get_resource_price("unobtainium")).is_equal(0)
