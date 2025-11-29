extends Camera2D
class_name ShipCamera

var original_zoom: Vector2 = Vector2.ONE
var zoom_tween: Tween = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func zoom_camera_in(target_zoom: Vector2) -> void:
	# Kill any existing zoom tween
	if zoom_tween:
		zoom_tween.kill()
	
	# Store original zoom if not already stored
	if original_zoom == Vector2.ONE:
		original_zoom = self.zoom
	
	# Create tween for zoom
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", target_zoom, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func zoom_camera_out() -> void:
	# Kill any existing zoom tween
	if zoom_tween:
		zoom_tween.kill()
	
	# Create tween to zoom back out
	zoom_tween = create_tween()
	
	# Zoom back to original
	zoom_tween.tween_property(self, "zoom", original_zoom, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
