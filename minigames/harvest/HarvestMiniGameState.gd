extends RefCounted
class_name HarvestMiniGameState

## Base abstract state class for harvest mini-game state machine.
## All states inherit from this class and implement the required methods.

var mini_game: HarvestMiniGame

func _init(game: HarvestMiniGame) -> void:
	mini_game = game

## Called when entering this state
func enter() -> void:
	pass

## Called when leaving this state
func exit() -> void:
	pass

## Called every frame while in this state
func process(_delta: float) -> void:
	pass

## Handle input events
func handle_input(_action: String) -> void:
	pass

## Update visual elements (scanner bars, etc.)
func update_visuals(_ui: HarvestMiniGameUI) -> void:
	pass
