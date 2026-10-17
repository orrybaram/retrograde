extends CanvasLayer
class_name PixelPass

## Prototype look: re-draws the world as chunky pixel art with a PVM-style scanline,
## after Animal Well's final pass. Two passes: this layer pixelates the world, between
## it (0) and the UI CanvasLayer (2); a tube layer over everything adds scanlines and
## glow at full res, so the UI gets the CRT but keeps its text sharp. Without on_ui the
## tube stays off and this pass does the lot. The dev panel's LOOK section drives it.

## Viewport px per art pixel. All divide 1280x720 evenly, so cells stay square and whole.
## 1x is the CRT alone: full-res art under the scanlines.
const PIXEL_SIZES: Array[float] = [1.0, 2.0, 4.0, 5.0, 8.0]

## The world pass sits under the UI CanvasLayer (2); the tube over everything, the screen
## fade (45) included, and below ControlsUI (100).
const WORLD_LAYER := 1
const UI_LAYER := 50

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
		_route()
## Scanlines and glow over the HUD and panels too, at full res.
var on_ui := true:
	set(value):
		on_ui = value
		_route()
var pixel_size := 2.0:
	set(value):
		pixel_size = value
		_material.set_shader_parameter("pixel_size", value)
var scanlines := 0.05:
	set(value):
		scanlines = clampf(value, 0.0, 1.0)
		_route()
## Screen px per scanline, beam and gap together.
var line_height := 6.0:
	set(value):
		line_height = clampf(value, 2.0, 16.0)
		_set_crt("line_height", line_height)
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
		_route()
var glow_strength := 0.6:
	set(value):
		glow_strength = clampf(value, 0.0, 3.0)
		_set_crt("glow_strength", glow_strength)
## How bright a pixel must be before it blooms. Space is near 0, cream is ~0.9.
var glow_threshold := 0.4:
	set(value):
		glow_threshold = clampf(value, 0.0, 1.0)
		_set_crt("glow_threshold", glow_threshold)

## Bloom on the UI alone, from its own shader on the CanvasGroup that holds every panel
## (Main's CanvasLayer/Glow). Apart from the world's glow, which can't tell text from hull.
var text_glow := 0.2:
	set(value):
		text_glow = clampf(value, 0.0, 4.0)
		_ui_glow.set_shader_parameter("strength", text_glow)
## Mip levels the UI bloom sums: each one reaches twice as far.
var text_glow_size := 3:
	set(value):
		text_glow_size = clampi(value, 1, 6)
		_ui_glow.set_shader_parameter("levels", text_glow_size)

## Now and then a thin strip of the UI slips sideways a few px, red and blue apart.
var ui_glitch := 0.2:
	set(value):
		ui_glitch = clampf(value, 0.0, 1.0)
		_ui_glow.set_shader_parameter("glitch", ui_glitch)

## The world pass: pixelates, and carries the CRT too when the tube is off.
var _material := ShaderMaterial.new()
## The tube pass: the same shader at 1x, scanlines and glow only.
var _tube_material := ShaderMaterial.new()
var _tube := CanvasLayer.new()
## The UI group's own bloom.
var _ui_glow := ShaderMaterial.new()


func _init() -> void:
	_material.shader = preload("res://scenes/PixelPass.gdshader")
	_tube_material.shader = _material.shader
	_tube_material.set_shader_parameter("pixel_size", 1.0)
	_ui_glow.shader = preload("res://scenes/UIGlow.gdshader")
	var band := Colors.PRIMARY
	_ui_glow.set_shader_parameter("band_color", Vector3(band.r, band.g, band.b))


func _ready() -> void:
	add_to_group("pixel_pass")
	layer = WORLD_LAYER
	visible = enabled
	var rgb: PackedVector3Array = []
	for color in PALETTE:
		rgb.append(Vector3(color.r, color.g, color.b))
	_material.set_shader_parameter("palette", rgb)
	_material.set_shader_parameter("palette_size", rgb.size())
	pixel_size = pixel_size
	line_height = line_height
	quantize = quantize
	dither = dither
	glow_strength = glow_strength
	glow_threshold = glow_threshold
	text_glow = text_glow
	text_glow_size = text_glow_size
	ui_glitch = ui_glitch
	var ui := get_tree().get_first_node_in_group("ui_glow") as CanvasGroup
	if ui:
		ui.material = _ui_glow
		ui.use_mipmaps = true
		# Room for the bloom to spill past the panels' edges.
		ui.fit_margin = 64.0
		ui.clear_margin = 64.0
		# A group only renders the rects of what it draws, and the panels' Controls
		# don't add up to the screen: an invisible full-screen rect keeps all of it.
		ui.draw.connect(func() -> void:
			ui.draw_rect(get_viewport().get_visible_rect(), Color.TRANSPARENT))
		# Under a Node2D, anchors measure against nothing; the panels hang off a Control
		# sized to the screen by hand instead.
		var root := ui.get_child(0) as Control
		var fit := func() -> void:
			root.position = Vector2.ZERO
			root.size = get_viewport().get_visible_rect().size
			_ui_glow.set_shader_parameter("view_height", root.size.y)
			ui.queue_redraw()
		fit.call()
		get_viewport().size_changed.connect(fit)

	add_child(_full_rect("Pass", _material))

	_tube.name = "Tube"
	_tube.layer = UI_LAYER
	# The world pass already read the screen this frame; without a fresh copy the tube
	# would see the frame from before it and the UI.
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_tube.add_child(copy)
	_tube.add_child(_full_rect("Pass", _tube_material))
	add_child(_tube)
	_route()


func _full_rect(rect_name: String, material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = rect_name
	rect.material = material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _set_crt(param: String, value: Variant) -> void:
	_material.set_shader_parameter(param, value)
	_tube_material.set_shader_parameter(param, value)


## Scanlines and glow go to whichever pass draws last: the tube when it's on, else the
## world pass. Never both, or the world would get them twice.
func _route() -> void:
	_tube.visible = enabled and on_ui
	_material.set_shader_parameter("scanlines", 0.0 if on_ui else scanlines)
	_material.set_shader_parameter("glow", glow and not on_ui)
	_tube_material.set_shader_parameter("scanlines", scanlines)
	_tube_material.set_shader_parameter("glow", glow)

