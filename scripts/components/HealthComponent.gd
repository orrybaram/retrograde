extends Node
class_name HealthComponent

signal hp_changed(current: float, max_hp: float)
signal damaged(amount: float)
signal died()

@export var max_hp: float = 100.0
## Minimum seconds between damage hits. Set to 0 to disable (continuous damage).
@export var damage_cooldown: float = 0.0

var current_hp: float

var _last_damage_time: float = -INF

func _ready() -> void:
	current_hp = max_hp

func take_damage(amount: float) -> void:
	if current_hp <= 0.0:
		return

	if damage_cooldown > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		if now - _last_damage_time < damage_cooldown:
			return
		_last_damage_time = now

	current_hp = max(0.0, current_hp - amount)
	damaged.emit(amount)
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0:
		died.emit()

func is_dead() -> bool:
	return current_hp <= 0.0

func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0.0 else 0.0

func reset() -> void:
	current_hp = max_hp
	_last_damage_time = -INF
	hp_changed.emit(current_hp, max_hp)
