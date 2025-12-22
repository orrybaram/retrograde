extends Node
class_name NodeUtils

static func find_parent_of_type(node: Node, type_script: Script) -> Node:
	var n := node.get_parent()
	while n:
		if n.get_script() == type_script:
			return n
		n = n.get_parent()
	return null

static func find_parent_class(node: Node, class_name_type: String) -> Node:
	# Helper to find parent by class_name string
	# This is a workaround since we can't pass class_name directly to find_parent_of_type
	var n := node.get_parent()
	while n:
		if n.get_script():
			var script = n.get_script()
			# Check if the script's class_name matches
			if script.has_method("get") and script.get("class_name") == class_name_type:
				return n
		n = n.get_parent()
	return null
