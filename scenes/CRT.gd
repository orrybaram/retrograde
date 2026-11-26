extends CanvasLayer
class_name CRT

## The tube over the whole picture: scanlines and bloom at full res across the world and
## the UI, the screen fade (45) included and below ControlsUI (100). Its BackBufferCopy
## hands it a fresh frame: the PixelPass already read the screen this frame, and without
## one this pass would see the frame from before that, with no UI in it. The dev panel's
## LOOK section drives it.

const DEFAULTS := {
	"enabled": true, "scanlines": 0.05, "line_height": 6.0,
	"glow": true, "glow_strength": 0.6, "glow_threshold": 0.4,
}

var enabled: bool = DEFAULTS.enabled:
	set(value):
		enabled = value
		visible = value
var scanlines: float = DEFAULTS.scanlines:
	set(value):
		scanlines = clampf(value, 0.0, 1.0)
		_material.set_shader_parameter("scanlines", scanlines)
## Screen px per scanline, beam and gap together.
var line_height: float = DEFAULTS.line_height:
	set(value):
		line_height = clampf(value, 2.0, 16.0)
		_material.set_shader_parameter("line_height", line_height)
## Bloom off the bright spots — windows, stars, engines, text. Done in the shader, not a
## WorldEnvironment: 2D glow there only catches HDR colors above 1.0, and turning on
## HDR 2D re-grades the whole palette.
var glow: bool = DEFAULTS.glow:
	set(value):
		glow = value
		_material.set_shader_parameter("glow", value)
var glow_strength: float = DEFAULTS.glow_strength:
	set(value):
		glow_strength = clampf(value, 0.0, 3.0)
		_material.set_shader_parameter("glow_strength", glow_strength)
## How bright a pixel must be before it blooms. Space is near 0, cream is ~0.9.
var glow_threshold: float = DEFAULTS.glow_threshold:
	set(value):
		glow_threshold = clampf(value, 0.0, 1.0)
		_material.set_shader_parameter("glow_threshold", glow_threshold)

@onready var _material: ShaderMaterial = $Pass.material


func _ready() -> void:
	add_to_group("crt")
	visible = enabled
	scanlines = scanlines
	line_height = line_height
	glow = glow
	glow_strength = glow_strength
	glow_threshold = glow_threshold
