extends Node
class_name NodeUtils

static func find_parent_of_type(node: Node, type_script: Script) -> Node:
	var n := node.get_parent()
	while n:
		if n.get_script() == type_script:
			return n
		n = n.get_parent()
	return null
