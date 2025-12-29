extends CanvasLayer
class_name StarField

## Parallax sensitivity - how much ship movement affects star offset
@export var parallax_scale: float = 0.00005

var _ship: RigidBody2D = null
var _material: ShaderMaterial = null
var _accumulated_offset: Vector2 = Vector2.ZERO

@onready var _color_rect: ColorRect = $ColorRect


func _ready() -> void:
	# Get the shader material from the ColorRect
	if _color_rect and _color_rect.material is ShaderMaterial:
		_material = _color_rect.material as ShaderMaterial
	
	# Find ship on next frame (gives scene tree time to initialize)
	call_deferred("_find_ship")
	
	# Listen for ship respawn to reset parallax
	EventBus.ship_respawned.connect(_on_ship_respawned)


func _find_ship() -> void:
	# Try to find ship in the "ship" group
	var ships = get_tree().get_nodes_in_group("ship")
	if ships.size() > 0:
		_ship = ships[0] as RigidBody2D


func _on_ship_respawned() -> void:
	# Reset accumulated offset when ship respawns
	_accumulated_offset = Vector2.ZERO
	if _material:
		_material.set_shader_parameter("speed_x", 0.0)
		_material.set_shader_parameter("speed_y", 0.0)


func _process(delta: float) -> void:
	if not _material:
		return
	
	if not _ship:
		_find_ship()
		return
	
	# Accumulate offset based on ship velocity over time
	# This creates continuous scrolling while moving
	_accumulated_offset += _ship.linear_velocity * delta * parallax_scale * -1.0
	
	_material.set_shader_parameter("speed_x", -_accumulated_offset.x)
	_material.set_shader_parameter("speed_y", -_accumulated_offset.y)
