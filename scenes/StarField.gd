extends CanvasLayer
class_name StarField

## Parallax sensitivity - how much ship movement affects star offset
@export var parallax_scale: float = 0.00005

## How fast the sky dies going in, and comes back coming out. The void takes the
## stars faster than it gives them back.
@export var fade_out_speed: float = 0.45
@export var fade_in_speed: float = 0.9

var _ship: RigidBody2D = null
var _material: ShaderMaterial = null
var _accumulated_offset: Vector2 = Vector2.ZERO
var _star_fade: float = 1.0

@onready var _color_rect: ColorRect = $ColorRect


func _ready() -> void:
	# Get the shader material from the ColorRect
	if _color_rect and _color_rect.material is ShaderMaterial:
		_material = _color_rect.material as ShaderMaterial
		_material.set_shader_parameter("space_color", Colors.SPACE_BG)
		_material.set_shader_parameter("nebula_color", Colors.NEBULA)
		_material.set_shader_parameter("star_color_warm", Colors.STAR)
		_material.set_shader_parameter("star_color_cool", Colors.NAV)
	
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
	_star_fade = 1.0
	if _material:
		_material.set_shader_parameter("speed_x", 0.0)
		_material.set_shader_parameter("speed_y", 0.0)
		_material.set_shader_parameter("star_fade", 1.0)


func _process(delta: float) -> void:
	if not _material:
		return

	_update_void_fade(delta)

	if not _ship:
		_find_ship()
		return

	# Accumulate offset based on ship velocity over time
	# This creates continuous scrolling while moving
	_accumulated_offset += _ship.linear_velocity * delta * parallax_scale * -1.0
	
	_material.set_shader_parameter("speed_x", -_accumulated_offset.x)
	_material.set_shader_parameter("speed_y", -_accumulated_offset.y)


## The void puts the stars out. Eased rather than snapped so crossing the edge
## reads as the sky draining, not as a light switch.
func _update_void_fade(delta: float) -> void:
	var target := 1.0 - VoidZone.shroud
	var speed := fade_out_speed if target < _star_fade else fade_in_speed
	_star_fade = move_toward(_star_fade, target, speed * delta)
	_material.set_shader_parameter("star_fade", _star_fade)
