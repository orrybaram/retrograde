@tool
extends GPUParticles2D
class_name SparkleParticles

const TROPHY_COLOR = Colors.YELLOW

@export var is_trophy: bool = false:
	set(value):
		is_trophy = value
		if is_node_ready():
			_apply_state()

var _original_mat: ParticleProcessMaterial = null
var _original_amount: int = 0

func _ready() -> void:
	_original_mat = process_material as ParticleProcessMaterial
	_original_amount = amount
	_apply_state()

func _apply_state() -> void:
	if _original_mat == null:
		return
	if is_trophy:
		var mat = _original_mat.duplicate() as ParticleProcessMaterial
		mat.color = TROPHY_COLOR
		process_material = mat
		process_material.scale_max = 15
		process_material.scale_min = 10
	else:
		process_material = _original_mat
		amount = _original_amount
