extends Node
class_name HarvestMiniGame

## Simple harvest mini-game.
## First scan press opens UI, second scan press harvests all resources.

signal harvest_all(amount: int)
signal ui_opened()
signal ui_closed()

var resource_kind: String = "Scrap"
var resource_amount: int = 10
var is_open: bool = false
var input_action: String = "scan"

func _ready() -> void:
	set_process(false)

func _process(_delta: float) -> void:
	if not is_open:
		return
	
	# Check for second scan press to harvest
	if Input.is_action_just_pressed(input_action):
		harvest_all.emit(resource_amount)
		close_ui()

func open_ui(kind: String, amount: int) -> void:
	if is_open:
		return
	
	resource_kind = kind
	resource_amount = amount
	is_open = true
	set_process(true)
	ui_opened.emit()

func close_ui() -> void:
	if not is_open:
		return
	
	is_open = false
	set_process(false)
	ui_closed.emit()
