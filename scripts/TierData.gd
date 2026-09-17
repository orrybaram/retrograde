extends RefCounted
class_name TierData

## Core tier definitions and weighted roll for the tiered collection system.

enum Tier { SLAG, SCRAP, SALVAGE, COMPONENT, MIL_SPEC, ARTIFACT }

const TIERS := {
	Tier.SLAG: { "item_id": "slag", "display_name": "Slag", "weight": 1.0, "price": 1 },
	Tier.SCRAP: { "item_id": "scrap", "display_name": "Scrap", "weight": 1.0, "price": 5 },
	Tier.SALVAGE: { "item_id": "salvage", "display_name": "Salvage", "weight": 1.0, "price": 15 },
	Tier.COMPONENT: { "item_id": "component", "display_name": "Component", "weight": 1.0, "price": 40 },
	Tier.MIL_SPEC: { "item_id": "mil_spec", "display_name": "Mil-Spec", "weight": 1.0, "price": 100 },
	Tier.ARTIFACT: { "item_id": "artifact", "display_name": "Artifact", "weight": 1.0, "price": 250 },
}

# Probability weights for roll (Slag excluded — only from fail)
# Scrap 40%, Salvage 25%, Component 15%, Mil-Spec 10%, Artifact 5%
# Remaining 5% not assigned — weights are relative, so total = 95 treated as 100%
const ROLL_WEIGHTS := {
	Tier.SCRAP: 40,
	Tier.SALVAGE: 25,
	Tier.COMPONENT: 15,
	Tier.MIL_SPEC: 10,
	Tier.ARTIFACT: 5,
}

# Trophy weights: skips Slag and Scrap, biased toward upper tiers
# Salvage 35%, Component 30%, Mil-Spec 20%, Artifact 15%
const TROPHY_ROLL_WEIGHTS := {
	Tier.SALVAGE: 35,
	Tier.COMPONENT: 30,
	Tier.MIL_SPEC: 20,
	Tier.ARTIFACT: 15,
}

## Weighted random tier roll. zone_modifier is a future extension point.
static func roll_tier(rng: RandomNumberGenerator, _zone_modifier: Dictionary = {}) -> Tier:
	var total_weight := 0
	for w in ROLL_WEIGHTS.values():
		total_weight += w

	var roll := rng.randi_range(1, total_weight)
	var cumulative := 0
	for tier in ROLL_WEIGHTS.keys():
		cumulative += ROLL_WEIGHTS[tier]
		if roll <= cumulative:
			return tier

	# Fallback (should never reach here)
	return Tier.SCRAP

## Trophy tier roll — guaranteed at least Salvage, biased toward rare tiers.
## Failure still yields Slag (caller's responsibility to pass harvest_amount > 0 check).
static func roll_tier_trophy(rng: RandomNumberGenerator) -> Tier:
	var total_weight := 0
	for w in TROPHY_ROLL_WEIGHTS.values():
		total_weight += w

	var roll := rng.randi_range(1, total_weight)
	var cumulative := 0
	for tier in TROPHY_ROLL_WEIGHTS.keys():
		cumulative += TROPHY_ROLL_WEIGHTS[tier]
		if roll <= cumulative:
			return tier

	return Tier.SALVAGE

## Tier for a finished extraction. Botched timing (LATE / OVERLOAD) always yields Slag.
## PERFECT upgrades the roll: normal nodes roll as trophies, trophies take the best of two.
static func roll_for_grade(grade: HarvestTiming.Grade, is_trophy: bool, rng: RandomNumberGenerator) -> Tier:
	match grade:
		HarvestTiming.Grade.PERFECT:
			if is_trophy:
				return maxi(roll_tier_trophy(rng), roll_tier_trophy(rng)) as Tier
			return roll_tier_trophy(rng)
		HarvestTiming.Grade.GOOD:
			return roll_tier_trophy(rng) if is_trophy else roll_tier(rng)
	return Tier.SLAG

static func get_item_id(tier: Tier) -> String:
	return TIERS[tier]["item_id"]

static func get_display_name(tier: Tier) -> String:
	return TIERS[tier]["display_name"]

static func get_display_name_for_item_id(item_id: String) -> String:
	for tier_data in TIERS.values():
		if tier_data["item_id"] == item_id:
			return tier_data["display_name"]
	return item_id.capitalize()
