extends CanvasGroup
class_name UIGlow

## Every UI panel, drawn into its own buffer so the UI gets a look the world doesn't: a
## soft bloom, the boot screen's rolling band on modal surfaces, and now and then a torn
## row. A pass over the whole frame can't do this; by then UI and world are one image.
##
## Controls under a CanvasGroup have three quirks, handled here:
## - Anchors under a Node2D measure against nothing, so the panels hang off one Control
##   (UI) that this sizes to the screen by hand.
## - The group only renders the rects of what it draws, and the panels don't add up to
##   the screen, so it draws an invisible full-screen rect of its own.
## - clip_children can't nest inside: clipping is a canvas group of its own, and it draws
##   as a solid white shape. Mask in a shader instead (see ScopeDisc.gdshader).

const DEFAULTS := {"text_glow": 0.2, "text_glow_size": 3, "glitch": 0.2}

## Bloom on the UI alone, apart from the CRT's.
var text_glow: float = DEFAULTS.text_glow:
	set(value):
		text_glow = clampf(value, 0.0, 4.0)
		_material.set_shader_parameter("strength", text_glow)
## Mip levels the bloom sums: each one reaches twice as far.
var text_glow_size: int = DEFAULTS.text_glow_size:
	set(value):
		text_glow_size = clampi(value, 1, 6)
		_material.set_shader_parameter("levels", text_glow_size)
## How often a strip of the UI slips sideways, red and blue apart.
var glitch: float = DEFAULTS.glitch:
	set(value):
		glitch = clampf(value, 0.0, 1.0)
		_material.set_shader_parameter("glitch", glitch)

var _material := ShaderMaterial.new()


func _init() -> void:
	_material.shader = preload("res://ui/UIGlow.gdshader")
	var band := Colors.PRIMARY
	_material.set_shader_parameter("band_color", Vector3(band.r, band.g, band.b))
	_material.set_shader_parameter("band_min_alpha", Colors.MODAL_DIM.a + 0.03)
	material = _material
	use_mipmaps = true
	# Room for the bloom to spill past the panels' edges.
	fit_margin = 64.0
	clear_margin = 64.0


## Sized before any panel's _ready, so none of them lays out against a zero rect.
func _enter_tree() -> void:
	_fit()


func _ready() -> void:
	add_to_group("ui_glow")
	text_glow = text_glow
	text_glow_size = text_glow_size
	glitch = glitch
	get_viewport().size_changed.connect(_fit)


func _draw() -> void:
	draw_rect(get_viewport_rect(), Color.TRANSPARENT)


func _fit() -> void:
	var ui := get_node("UI") as Control
	ui.position = Vector2.ZERO
	ui.size = get_viewport_rect().size
	_material.set_shader_parameter("view_height", ui.size.y)
	queue_redraw()
