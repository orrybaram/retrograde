extends Node2D
class_name SunGlare

## Washes the view with sunlight as the camera nears the sun. Drawn in world space
## above the ship but under the HUD (which lives on its own CanvasLayer).

## Glare alpha at the sun's surface.
@export_range(0.0, 1.0) var max_alpha: float = 0.5
## Glare fades out by this many sun radii from the sun's center.
@export var reach: float = 3.5

var sun: PlanetVisual = null
var _alpha: float = 0.0
var _half_extent: float = 0.0

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX - 1
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or not is_instance_valid(sun):
		visible = false
		return
	var center := cam.get_screen_center_position()
	var alpha := PlanetVisual.glare_alpha_for(center.distance_to(sun.global_position), sun._get_radius(), reach, max_alpha)
	visible = alpha > 0.001
	if not visible:
		return
	global_position = center
	# Cover the view at any camera rotation
	var view := get_viewport_rect().size / cam.zoom
	var half_extent := view.length() * 0.5
	if absf(alpha - _alpha) > 0.002 or not is_equal_approx(half_extent, _half_extent):
		_alpha = alpha
		_half_extent = half_extent
		queue_redraw()

func _draw() -> void:
	var h := _half_extent
	draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(Colors.SUN, _alpha))
