extends Camera2D
class_name ShipCamera

var original_zoom: Vector2 = Vector2.ONE
var zoom_tween: Tween = null

func zoom_camera_in(target_zoom: Vector2) -> void:
	if zoom_tween:
		zoom_tween.kill()
	if original_zoom == Vector2.ONE:
		original_zoom = self.zoom
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", target_zoom, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func zoom_camera_out() -> void:
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", original_zoom, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
