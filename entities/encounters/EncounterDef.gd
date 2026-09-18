extends Resource
class_name EncounterDef

## One kind of deep-space encounter, as data. Placement rules live here; the thing
## itself is built by a subclass. Adding a new encounter type is a new subclass plus a
## .tres — EncounterField never changes. See docs/ENCOUNTERS.md.
##
## Generation is split in two so that the world stays reproducible:
##   plan()  rolls every random choice and returns one entry per node, in a stable order
##   build() turns one entry into a live node and rolls nothing
## The field skips entries the player has already harvested, which it can only do if the
## order is fixed before anything is spawned.

@export var id: StringName = &""

## What the scanner calls this. Encounters may deliberately share one: a clone wreck
## reads as an ordinary DERELICT, because that is all the scanner can tell.
@export var contact_label: String = "CONTACT"

## Relative odds against the other defs eligible at the same distance from the sun.
@export_range(0.0, 100.0) var weight: float = 1.0

## At most this many may ever exist in one game (0 = no limit). A budgeted encounter is
## claimed by the first places the player actually flies near, and never turns up again
## once the budget is gone — for the things that should be a shock, not a fixture.
@export var budget: int = 0

## The band of distances from the sun where this can appear. The five-planet tone
## gradient in docs/DESIGN.md falls out of these: a def banded past MV-1's orbit is a
## military-era encounter without having to say so.
@export var min_radius: float = 0.0
@export var max_radius: float = 0.0  # 0 = out to the edge of the system

func fits(radius: float) -> bool:
	if radius < min_radius:
		return false
	return max_radius <= 0.0 or radius <= max_radius

## One dictionary per node this encounter would place, in a stable order. All randomness
## happens here, drawn from `rng` (the cell's seeded generator — never RNG.rng).
## `origin` is where in the cell the encounter was placed.
func plan(_rng: RandomNumberGenerator, _origin: Vector2) -> Array[Dictionary]:
	return []

## Turn one plan entry into a live node parented under `field`, or null to place nothing.
## Must not draw from any RNG: everything was decided in plan().
func build(_field: Node2D, _entry: Dictionary) -> Node:
	return null

## Hand a node built by this def back. Pooled nodes go back to the pool; anything else
## is freed. Subclasses that build unpooled nodes override this.
func release(node: Node) -> void:
	if node is OrbitalNode:
		ResourceNodePool.return_instance(node)
	elif is_instance_valid(node):
		node.queue_free()
