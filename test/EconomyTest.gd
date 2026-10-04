extends GdUnitTestSuite

## The Stores economy's tuning target (docs/FREIGHT.md §8, issue #141): one full hold of
## ordinary gems buys about a full tank from empty. "Ordinary" is what GOOD hits on plain
## scrap roll (GemData.ROLL_WEIGHTS), worked out on average rather than sampled.

## Average Stores and hold units of one ordinary gem.
func _ordinary_gem() -> Vector2:
	var total := 0
	for tier in GemData.ROLL_WEIGHTS:
		total += GemData.ROLL_WEIGHTS[tier]
	var value := 0.0
	var space := 0.0
	for tier in GemData.ROLL_WEIGHTS:
		var share := float(GemData.ROLL_WEIGHTS[tier]) / total
		value += share * GemData.TIERS[tier]["value"]
		space += share * GemData.TIERS[tier]["space"]
	return Vector2(value, space)

## Stores a full hold of ordinary gems brings home.
func _ordinary_hold(ship: Ship) -> float:
	var gem := _ordinary_gem()
	return ship.max_cargo_weight / gem.y * gem.x

func _ship() -> Ship:
	var ship := auto_free(load("res://entities/Ship/Ship.tscn").instantiate()) as Ship
	ship.max_cargo_weight = 50.0  # the Cargo Bay fitted
	return ship

func test_a_full_hold_of_ordinary_gems_buys_about_a_full_tank() -> void:
	var ship := _ship()
	var tank := ship.drive.max_fuel * Economy.REFUEL_COST_PER_POINT
	var hold := _ordinary_hold(ship)
	assert_float(hold).is_between(tank * 0.85, tank * 1.15)

func test_a_full_hold_more_than_covers_the_tank_past_the_free_half() -> void:
	var ship := _ship()
	var past_half := ship.drive.max_fuel * (1.0 - Drive.FREE_FRACTION) * Economy.REFUEL_COST_PER_POINT
	assert_float(_ordinary_hold(ship)).is_greater(past_half)
