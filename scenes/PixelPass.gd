extends CanvasLayer
class_name PixelPass

## The world re-drawn as chunky pixel art, after Animal Well's final pass. Sits between
## the world (0) and the UI CanvasLayer (2), so only the world pixelates; the CRT over
## everything adds scanlines and bloom. The dev panel's LOOK section drives it.

## Viewport px per art pixel. All divide 1280x720 evenly, so cells stay square and whole.
## 1x leaves the world at full res.
const PIXEL_SIZES: Array[float] = [1.0, 2.0, 4.0, 5.0, 8.0]

const DEFAULTS := {"enabled": true, "pixel_size": 2.0, "quantize": false, "dither": 0.25}

## The opaque base colors of the Violet Signal palette, the ones quantizing snaps to.
const PALETTE: Array[Color] = [
	Colors.SPACE, Colors.NEBULA_HAZE, Colors.HULL_DARK, Colors.HULL_MID, Colors.HULL_LIGHT,
	Colors.MUSTARD_DARK, Colors.MUSTARD_PALE, Colors.MUSTARD, Colors.YELLOW,
	Colors.CREAM_SOFT, Colors.CREAM, Colors.ORANGE, Colors.RUST_RED, Colors.SAGE,
	Colors.BLUE, Colors.PURPLE,
]

var enabled: bool = DEFAULTS.enabled:
	set(value):
		enabled = value
		_sync_visible()
var pixel_size: float = DEFAULTS.pixel_size:
	set(value):
		pixel_size = value
		_material.set_shader_parameter("pixel_size", value)
		_sync_visible()
var quantize: bool = DEFAULTS.quantize:
	set(value):
		quantize = value
		_material.set_shader_parameter("quantize", value)
		_sync_visible()
var dither: float = DEFAULTS.dither:
	set(value):
		dither = clampf(value, 0.0, 1.0)
		_material.set_shader_parameter("dither", dither)

@onready var _material: ShaderMaterial = $Pass.material


func _ready() -> void:
	add_to_group("pixel_pass")
	var rgb: PackedVector3Array = []
	for color in PALETTE:
		rgb.append(Vector3(color.r, color.g, color.b))
	_material.set_shader_parameter("palette", rgb)
	_material.set_shader_parameter("palette_size", rgb.size())
	pixel_size = pixel_size
	quantize = quantize
	dither = dither


## At 1x with no palette snap the pass would copy the frame unchanged: skip the draw.
func _sync_visible() -> void:
	visible = enabled and (pixel_size > 1.0 or quantize)
