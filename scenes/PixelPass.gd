extends CanvasLayer
class_name PixelPass

## Prototype look: re-draws the world as chunky pixel art with a PVM-style scanline,
## after Animal Well's final pass. Its layer sits between the world (0) and the UI
## CanvasLayer (2), so only the world gets pixelated. On at 1x (scanlines only) by
## default; the dev panel's LOOK section drives it.

## Viewport px per art pixel. All divide 1280x720 evenly, so cells stay square and whole.
## 1x is the CRT alone: full-res art under the scanlines.
const PIXEL_SIZES: Array[float] = [1.0, 2.0, 4.0, 5.0, 8.0]

## The opaque base colors of the Violet Signal palette, the ones quantizing snaps to.
const PALETTE: Array[Color] = [
	Colors.SPACE, Colors.NEBULA_HAZE, Colors.HULL_DARK, Colors.HULL_MID, Colors.HULL_LIGHT,
	Colors.MUSTARD_DARK, Colors.MUSTARD_PALE, Colors.MUSTARD, Colors.YELLOW,
	Colors.CREAM_SOFT, Colors.CREAM, Colors.ORANGE, Colors.RUST_RED, Colors.SAGE,
	Colors.BLUE, Colors.PURPLE,
]

var enabled := true:
	set(value):
		enabled = value
		visible = value
var pixel_size := 1.0:
	set(value):
		pixel_size = value
		_material.set_shader_parameter("pixel_size", value)
var scanlines := 0.6:
	set(value):
		scanlines = clampf(value, 0.0, 1.0)
		_material.set_shader_parameter("scanlines", scanlines)
var quantize := false:
	set(value):
		quantize = value
		_material.set_shader_parameter("quantize", value)
var dither := 0.25:
	set(value):
		dither = clampf(value, 0.0, 1.0)
		_material.set_shader_parameter("dither", dither)

## Bloom off the world's bright spots — windows, stars, engines. Done in the shader,
## not a WorldEnvironment: 2D glow there only catches HDR colors above 1.0, and turning
## on HDR 2D re-grades the whole palette.
var glow := true:
	set(value):
		glow = value
		_material.set_shader_parameter("glow", value)
var glow_strength := 0.6:
	set(value):
		glow_strength = clampf(value, 0.0, 3.0)
		_material.set_shader_parameter("glow_strength", glow_strength)
## How bright a pixel must be before it blooms. Space is near 0, cream is ~0.9.
var glow_threshold := 0.4:
	set(value):
		glow_threshold = clampf(value, 0.0, 1.0)
		_material.set_shader_parameter("glow_threshold", glow_threshold)

var _material := ShaderMaterial.new()


func _init() -> void:
	_material.shader = preload("res://scenes/PixelPass.gdshader")


func _ready() -> void:
	add_to_group("pixel_pass")
	layer = 1
	visible = enabled
	var rgb: PackedVector3Array = []
	for color in PALETTE:
		rgb.append(Vector3(color.r, color.g, color.b))
	_material.set_shader_parameter("palette", rgb)
	_material.set_shader_parameter("palette_size", rgb.size())
	pixel_size = pixel_size
	scanlines = scanlines
	quantize = quantize
	dither = dither

	glow = glow
	glow_strength = glow_strength
	glow_threshold = glow_threshold

	var rect := ColorRect.new()
	rect.name = "Pass"
	rect.material = _material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
