extends GdUnitTestSuite

## Tests for the transit scanner: that an encounter reads as one contact however many
## pieces it is made of, that it points the way the player has to turn, and that it stops
## reporting things that have been salvaged.

const DEEP := 18


func _field(table: EncounterTable) -> EncounterField:
	var field := auto_free(EncounterField.new()) as EncounterField
	field.enabled = false
	field.table = table
	add_child(field)
	return field


class ClusterDef extends EncounterDef:
	var count := 6

	func plan(rng: RandomNumberGenerator, origin: Vector2) -> Array[Dictionary]:
		var entries: Array[Dictionary] = []
		for i in count:
			entries.append({"pos": origin + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * 200.0})
		return entries

	func build(field: Node2D, entry: Dictionary) -> Node:
		var node := Node2D.new()
		node.global_position = entry["pos"]
		field.add_child(node)
		return node


func _table(label: String, count: int, per_cell: int = 1) -> EncounterTable:
	var def := ClusterDef.new()
	def.id = &"cluster"
	def.contact_label = label
	def.count = count
	var table := EncounterTable.new()
	table.entries = [def]
	table.min_per_cell = per_cell
	table.max_per_cell = per_cell
	return table


# --- Contacts ----------------------------------------------------------------

func test_a_cluster_of_many_pieces_is_one_contact() -> void:
	# Eight rows for one knot of scrap would drown the decision the scanner exists for.
	var field := _field(_table("DEBRIS", 8))
	var cell := Vector2i(DEEP, 2)
	var contacts := field._generate(cell)
	field._cells[cell] = contacts

	assert_int(contacts.size()).is_equal(1)
	assert_int(contacts[0].remaining()).is_equal(8)
	assert_str(contacts[0].label).is_equal("DEBRIS")
	assert_int(field.node_count()).is_equal(8)


func test_a_contact_sits_in_the_middle_of_what_is_left() -> void:
	var contact := EncounterContact.new("DEBRIS")
	var field := _field(_table("DEBRIS", 1))
	for offset in [Vector2(-100, 0), Vector2(100, 0), Vector2(0, 300)]:
		var node := Node2D.new()
		field.add_child(node)
		node.global_position = offset
		contact.add(node)

	assert_vector(contact.position()).is_equal_approx(Vector2(0, 100), Vector2.ONE)

	# Salvage one and the contact re-centres on the rest
	var taken := contact.nodes[2]
	contact.drop(taken)
	taken.queue_free()
	assert_int(contact.remaining()).is_equal(2)
	assert_vector(contact.position()).is_equal_approx(Vector2.ZERO, Vector2.ONE)


func test_an_emptied_contact_stops_reporting() -> void:
	var contact := EncounterContact.new("DEBRIS")
	assert_bool(contact.is_alive()).is_false()

	var field := _field(_table("DEBRIS", 1))
	var node := Node2D.new()
	field.add_child(node)
	contact.add(node)
	assert_bool(contact.is_alive()).is_true()

	contact.drop(node)
	node.queue_free()
	assert_bool(contact.is_alive()).is_false()


func test_only_what_is_within_reach_is_reported_and_nearest_comes_first() -> void:
	var field := _field(_table("DEBRIS", 2, 2))
	var origin := field.cell_centre(Vector2i(DEEP, 2))
	field._cells[Vector2i(DEEP, 2)] = field._generate(Vector2i(DEEP, 2))

	var near := field.contacts_in_range(origin, ScannerPanel.RANGE)
	assert_int(near.size()).is_greater(0)
	var previous := -1.0
	for contact in near:
		var d := contact.position().distance_to(origin)
		assert_float(d).is_less_equal(ScannerPanel.RANGE)
		assert_float(d).is_greater_equal(previous)
		previous = d

	# A long way off, the same space is silent
	assert_array(field.contacts_in_range(origin + Vector2(80000, 0), ScannerPanel.RANGE)).is_empty()


# --- The readout -------------------------------------------------------------

func test_bearing_is_which_way_the_player_has_to_turn() -> void:
	# Ship's nose is +X. Negative is to port, positive to starboard, 0 dead ahead.
	assert_float(ScannerPanel.bearing_to(0.0, Vector2(100, 0))).is_equal_approx(0.0, 0.01)
	assert_float(ScannerPanel.bearing_to(0.0, Vector2(0, 100))).is_equal_approx(90.0, 0.01)
	assert_float(ScannerPanel.bearing_to(0.0, Vector2(0, -100))).is_equal_approx(-90.0, 0.01)
	# Flying the other way, the same contact is behind you — and reported as one turn,
	# never as 270 degrees the long way round
	assert_float(absf(ScannerPanel.bearing_to(PI, Vector2(100, 0)))).is_equal_approx(180.0, 0.01)
	for heading in [-3.0, -1.0, 0.0, 1.0, 3.0]:
		for angle in [-3.0, -0.5, 0.5, 2.0]:
			var bearing := ScannerPanel.bearing_to(heading, Vector2.RIGHT.rotated(angle) * 500.0)
			assert_float(bearing).is_between(-180.0, 180.0)


func test_a_row_says_what_it_is_which_way_and_how_far() -> void:
	var row := ScannerPanel.format_row("DEBRIS", -34.2, 4210.0)
	assert_str(row).contains("DEBRIS")
	assert_str(row).contains("-034°")
	assert_str(row).contains("4.2 km")
	# Dead ahead is signed too, so the column never jitters in width
	assert_str(ScannerPanel.format_row("DERELICT", 0.0, 800.0)).contains("+000°")
	assert_str(ScannerPanel.format_row("DERELICT", 0.0, 800.0)).contains("800 m")


func test_rows_line_up_down_the_panel() -> void:
	var rows := [
		ScannerPanel.format_row("DEBRIS", -5.0, 120.0),
		ScannerPanel.format_row("CONTAINER", 174.0, 9400.0),
		ScannerPanel.format_row("DERELICT", 90.0, 1000.0),
	]
	var width: int = rows[0].length()
	for row in rows:
		assert_int(row.length()).is_equal(width)


# --- What the scanner can and can't tell -------------------------------------

func test_a_clone_wreck_reads_as_an_ordinary_derelict() -> void:
	# You detour for routine salvage and find your own ship. The scanner must not spoil it.
	var clone: EncounterDef = load("res://entities/encounters/defs/clone_wreck.tres")
	var plain: EncounterDef = load("res://entities/encounters/defs/small_derelict.tres")
	assert_str(clone.contact_label).is_equal(plain.contact_label)
	assert_str(clone.contact_label).is_equal("DERELICT")


func test_every_shipped_encounter_says_what_it_is() -> void:
	var table: EncounterTable = load("res://entities/encounters/tables/deep_space.tres")
	for def in table.entries:
		assert_str(def.contact_label).is_not_equal("CONTACT")
		assert_str(def.contact_label).is_equal(def.contact_label.to_upper())


func test_the_scanner_reaches_as_far_as_the_minimap_draws() -> void:
	# The list and the minimap must agree about what is out there.
	add_child(auto_free(load("res://ui/minimap/Minimap.tscn").instantiate()))
	var minimap := Minimap.get_instance(get_tree())
	assert_object(minimap).is_not_null()
	assert_float(ScannerPanel.RANGE).is_equal(minimap.world_range)
