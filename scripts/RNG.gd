extends Node

# Global Random Number Generator singleton
# Access via RNG.rng throughout the project

var rng: RandomNumberGenerator
@export var seed_value: int = 12345

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

# Get a seeded RNG for a specific purpose (e.g., cell-based generation)
# This creates a new RNG with a seed derived from the base seed + the provided value
func get_seeded_rng(seed_offset: int) -> RandomNumberGenerator:
	var seeded_rng = RandomNumberGenerator.new()
	seeded_rng.seed = seed_value + seed_offset
	return seeded_rng

# Set the global seed (affects all future random calls)
func set_seed(new_seed: int) -> void:
	seed_value = new_seed
	if rng:
		rng.seed = new_seed

