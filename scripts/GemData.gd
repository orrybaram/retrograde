extends RefCounted
class_name GemData

## Gem tiers: the currency knocked loose from scrap. Bigger gems are worth more and
## take more hold space. Each harvest hit drops a handful (a chip); the final hit
## breaks the scrap into a bigger burst. The hold is cashed in for credits on docking.

enum Tier { SHARD, GEM, CRYSTAL, ARTIFACT }

## value: credits when cashed in. space: hold units. size: drawn half-width in px.
const TIERS := {
	Tier.SHARD:    {"item_id": "shard",    "display_name": "Shard",    "value": 2,   "space": 1, "size": 3.2},
	Tier.GEM:      {"item_id": "gem",      "display_name": "Gem",      "value": 8,   "space": 1, "size": 4.4},
	Tier.CRYSTAL:  {"item_id": "crystal",  "display_name": "Crystal",  "value": 25,  "space": 2, "size": 5.8},
	Tier.ARTIFACT: {"item_id": "artifact", "display_name": "Artifact", "value": 100, "space": 3, "size": 7.0},
}

const ROLL_WEIGHTS := {Tier.SHARD: 60, Tier.GEM: 30, Tier.CRYSTAL: 9, Tier.ARTIFACT: 1}
const PERFECT_ROLL_WEIGHTS := {Tier.SHARD: 25, Tier.GEM: 45, Tier.CRYSTAL: 24, Tier.ARTIFACT: 6}
const TROPHY_ROLL_WEIGHTS := {Tier.GEM: 50, Tier.CRYSTAL: 35, Tier.ARTIFACT: 15}

const CHIP_MIN := 1
const CHIP_MAX := 3
const BREAK_MIN := 5
const BREAK_MAX := 8
const PERFECT_CHIP_BONUS := 1
const PERFECT_BREAK_BONUS := 2
const TROPHY_BREAK_BONUS := 3

## Item ids for one hit. Botched timing (LATE / OVERLOAD) still breaks off gems, but only shards.
static func drops_for_hit(grade: HarvestTiming.Grade, final: bool, trophy: bool, rng: RandomNumberGenerator) -> Array[String]:
	var perfect := grade == HarvestTiming.Grade.PERFECT
	var count: int
	if final:
		count = rng.randi_range(BREAK_MIN, BREAK_MAX)
		if perfect:
			count += PERFECT_BREAK_BONUS
		if trophy:
			count += TROPHY_BREAK_BONUS
	else:
		count = rng.randi_range(CHIP_MIN, CHIP_MAX)
		if perfect:
			count += PERFECT_CHIP_BONUS
	var drops: Array[String] = []
	for i in count:
		drops.append(roll(grade, trophy, rng))
	return drops

## One gem for a hit of this grade. PERFECT on a trophy takes the best of two trophy rolls.
static func roll(grade: HarvestTiming.Grade, trophy: bool, rng: RandomNumberGenerator) -> String:
	match grade:
		HarvestTiming.Grade.PERFECT:
			if trophy:
				return item_id(maxi(_weighted(TROPHY_ROLL_WEIGHTS, rng), _weighted(TROPHY_ROLL_WEIGHTS, rng)))
			return item_id(_weighted(PERFECT_ROLL_WEIGHTS, rng))
		HarvestTiming.Grade.GOOD:
			return item_id(_weighted(TROPHY_ROLL_WEIGHTS if trophy else ROLL_WEIGHTS, rng))
	return item_id(Tier.SHARD)

static func _weighted(weights: Dictionary, rng: RandomNumberGenerator) -> Tier:
	var total := 0
	for w in weights.values():
		total += w
	var pick := rng.randi_range(1, total)
	for tier in weights:
		pick -= weights[tier]
		if pick <= 0:
			return tier
	return Tier.SHARD

static func item_id(tier: Tier) -> String:
	return TIERS[tier]["item_id"]

static func tier_of(id: String) -> int:
	for tier in TIERS:
		if TIERS[tier]["item_id"] == id:
			return tier
	return -1

static func is_gem(id: String) -> bool:
	return tier_of(id) >= 0

static func _field(id: String, key: String, fallback: Variant) -> Variant:
	var tier := tier_of(id)
	return TIERS[tier][key] if tier >= 0 else fallback

static func value_of(id: String) -> int:
	return _field(id, "value", 0)

static func space_of(id: String) -> int:
	return _field(id, "space", 1)

static func size_of(id: String) -> float:
	return _field(id, "size", 2.0)

static func display_name(id: String) -> String:
	return _field(id, "display_name", id.capitalize())

static func color_of(id: String) -> Color:
	match tier_of(id):
		Tier.SHARD: return Colors.GEM_SHARD
		Tier.GEM: return Colors.GEM_GEM
		Tier.CRYSTAL: return Colors.GEM_CRYSTAL
		Tier.ARTIFACT: return Colors.GEM_ARTIFACT
	return Colors.PRIMARY

## Highest-tier id in a list ("" when empty).
static func best_of(ids: Array) -> String:
	var best := ""
	for id in ids:
		if tier_of(id) > tier_of(best):
			best = id
	return best

## Credits a set of {item_id: quantity} is worth. Non-gem ids count for nothing.
static func hold_value(items: Dictionary) -> int:
	var total := 0
	for id in items:
		total += value_of(id) * int(items[id])
	return total
