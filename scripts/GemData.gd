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
const WRECK_SHARE := 0.7  # of the hold left floating where the ship blew up

## An ore seam is harvested exactly like scrap, but scrap is the trickle you live on and
## a seam is the payday: its rolls skew to the top tiers and every hit breaks off more.
## Rich seams (moons) roll better still, and take RICH_HITS to work through.
const ORE_ROLL_WEIGHTS := {Tier.SHARD: 25, Tier.GEM: 50, Tier.CRYSTAL: 23, Tier.ARTIFACT: 2}
const RICH_ROLL_WEIGHTS := {Tier.GEM: 45, Tier.CRYSTAL: 45, Tier.ARTIFACT: 10}
const ORE_CHIP_MIN := 2
const ORE_CHIP_MAX := 4
const ORE_BREAK_MIN := 6
const ORE_BREAK_MAX := 9
const ORE_PERFECT_CHIP_BONUS := 1
const ORE_PERFECT_BREAK_BONUS := 2

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

## Item ids broken off an ore seam by one hit. `final` is the hit that empties the seam
## and throws the big burst. PERFECT adds a gem and bumps the best one a tier; botched
## timing (LATE / OVERLOAD) only cracks off shards.
static func ore_drops(grade: HarvestTiming.Grade, final: bool, rich: bool, rng: RandomNumberGenerator) -> Array[String]:
	var perfect := grade == HarvestTiming.Grade.PERFECT
	var count: int
	if final:
		count = rng.randi_range(ORE_BREAK_MIN, ORE_BREAK_MAX) + (ORE_PERFECT_BREAK_BONUS if perfect else 0)
	else:
		count = rng.randi_range(ORE_CHIP_MIN, ORE_CHIP_MAX) + (ORE_PERFECT_CHIP_BONUS if perfect else 0)
	var drops: Array[String] = []
	for i in count:
		drops.append(ore_roll(grade, rich, rng))
	return bump_best(drops) if perfect else drops

## One gem from an ore seam. PERFECT on a rich seam takes the best of two rolls.
static func ore_roll(grade: HarvestTiming.Grade, rich: bool, rng: RandomNumberGenerator) -> String:
	if grade == HarvestTiming.Grade.LATE or grade == HarvestTiming.Grade.OVERLOAD:
		return item_id(Tier.SHARD)
	var weights := RICH_ROLL_WEIGHTS if rich else ORE_ROLL_WEIGHTS
	if grade == HarvestTiming.Grade.PERFECT and rich:
		return item_id(maxi(_weighted(weights, rng), _weighted(weights, rng)))
	return item_id(_weighted(weights, rng))

## Lifts the best gem in `ids` one tier (a PERFECT hit's bonus on a seam).
static func bump_best(ids: Array[String]) -> Array[String]:
	if ids.is_empty():
		return ids
	var best := 0
	for i in ids.size():
		if tier_of(ids[i]) > tier_of(ids[best]):
			best = i
	ids[best] = item_id(mini(tier_of(ids[best]) + 1, Tier.ARTIFACT) as Tier)
	return ids

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

## Item ids left at a wreck: WRECK_SHARE of each gem tier in the hold, rounded.
static func wreck_drops(items: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id in items:
		if is_gem(id):
			for i in roundi(int(items[id]) * WRECK_SHARE):
				ids.append(id)
	return ids

## Credits a set of {item_id: quantity} is worth. Non-gem ids count for nothing.
static func hold_value(items: Dictionary) -> int:
	var total := 0
	for id in items:
		total += value_of(id) * int(items[id])
	return total
