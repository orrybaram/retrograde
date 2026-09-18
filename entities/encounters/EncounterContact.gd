extends RefCounted
class_name EncounterContact

## One encounter out in the world, as the scanner sees it: whatever it put there, and
## what it reads as. A debris cluster is eight nodes but one contact — the scanner is a
## decision aid ("detour or stay on course"), and eight rows for one knot of scrap would
## drown that decision. See docs/ENCOUNTERS.md.

## What the scanner calls it. Several encounters can share a label on purpose — a clone
## wreck reads as an ordinary DERELICT, because from out here that is all it is.
var label: String = "CONTACT"
var nodes: Array[Node] = []

func _init(contact_label: String = "CONTACT") -> void:
	label = contact_label

func add(node: Node) -> void:
	nodes.append(node)

func drop(node: Node) -> void:
	nodes.erase(node)

## Live nodes still out there. Salvaging a cluster whittles this down.
func remaining() -> int:
	var live := 0
	for node in nodes:
		if is_instance_valid(node):
			live += 1
	return live

func is_alive() -> bool:
	return remaining() > 0

## The middle of what's left, which is what the scanner points at.
func position() -> Vector2:
	var sum := Vector2.ZERO
	var live := 0
	for node in nodes:
		if is_instance_valid(node) and node is Node2D:
			sum += (node as Node2D).global_position
			live += 1
	return sum / live if live > 0 else Vector2.ZERO
