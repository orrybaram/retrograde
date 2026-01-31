extends MinimapTarget
class_name ResourceRingMinimapTarget

## MinimapTarget for an entire resource ring/spawner.
## Draws clustered blobs based on actual resource positions and density.

var spawner: Node2D  # OrbitalRingSpawner
var _orbital_body: Node2D  # Planet or station the ring orbits
var _inner_radius: float = 0.0
var _outer_radius: float = 0.0
var _body_radius: float = 0.0

# Clustering settings
const SEGMENT_COUNT: int = 16  # Number of angular segments to divide ring into
const MIN_BLOB_SIZE: float = 1.5
const MAX_BLOB_SIZE: float = 5.0
# Cluster data
var _clusters: Array[Dictionary] = []  # [{angle: float, radius: float, count: int}]

func _init(s: Node2D, orbital_body: Node2D, body_radius: float, inner_r: float, outer_r: float) -> void:
	spawner = s
	_orbital_body = orbital_body
	_body_radius = body_radius
	_inner_radius = inner_r
	_outer_radius = outer_r

func get_minimap_position() -> Vector2:
	if _orbital_body and is_instance_valid(_orbital_body):
		return _orbital_body.global_position
	return Vector2.ZERO

func get_minimap_color() -> Color:
	return Color(0.5, 0.85, 0.5, 0.8)  # Green for resources

func get_minimap_icon() -> String:
	return "ring"

func get_minimap_size() -> float:
	return _body_radius + _outer_radius

func get_minimap_priority() -> int:
	return 5

func is_minimap_visible() -> bool:
	if not spawner or not is_instance_valid(spawner):
		return false
	if not _orbital_body or not is_instance_valid(_orbital_body):
		return false
	return spawner.remaining_resources > 0

## Update cluster data from actual resource positions
## Stores angular data (angle + radius) so positions can be recalculated relative to moving orbital body
func update_clusters() -> void:
	_clusters.clear()

	if not spawner or not is_instance_valid(spawner):
		return

	var resources: Array = spawner._spawned_resources
	if resources.is_empty():
		return

	var center = get_minimap_position()

	# Initialize segment buckets - store angle and radius for each resource
	var segments: Array[Array] = []
	for i in range(SEGMENT_COUNT):
		segments.append([])

	# Sort resources into angular segments
	for resource in resources:
		if not resource or not is_instance_valid(resource):
			continue
		if resource._is_depleted:
			continue

		# Use orbital motion's time-based position instead of global_position
		# This avoids stale positions from distant resources with reduced update rates
		var angle: float
		var radius: float

		var orbital = resource._orbital_motion
		if orbital and orbital.initialized and orbital.orbital_body and is_instance_valid(orbital.orbital_body):
			# Calculate current angle from time (same formula as OrbitalMotion.update_orbit)
			var speed_rad_per_sec = (orbital.orbital_speed / 100.0) * orbital.speed_scale
			var elapsed = Time.get_ticks_msec() / 1000.0 - orbital.orbital_start_time
			angle = fmod(orbital.initial_angle + speed_rad_per_sec * elapsed, TAU)
			radius = orbital.orbital_distance
		else:
			# Fallback to global_position for non-orbiting resources
			var offset = resource.global_position - center
			angle = atan2(offset.y, offset.x)
			radius = offset.length()

		var normalized_angle = angle
		if normalized_angle < 0:
			normalized_angle += TAU

		var segment_idx = int(normalized_angle / TAU * SEGMENT_COUNT) % SEGMENT_COUNT
		segments[segment_idx].append({
			"angle": angle,
			"radius": radius
		})

	# Create clusters from non-empty segments - store angle and radius, not absolute position
	for i in range(SEGMENT_COUNT):
		if segments[i].is_empty():
			continue

		# Calculate average angle and radius for this segment
		var avg_angle = 0.0
		var avg_radius = 0.0
		var count = segments[i].size()

		for res_data in segments[i]:
			avg_angle += res_data["angle"]
			avg_radius += res_data["radius"]

		avg_angle /= count
		avg_radius /= count

		_clusters.append({
			"angle": avg_angle,
			"radius": avg_radius,
			"count": count
		})

## Get cluster data for drawing
func get_clusters() -> Array[Dictionary]:
	update_clusters()
	return _clusters

## Get the maximum resource count in any cluster (for scaling)
func get_max_cluster_count() -> int:
	var max_count = 1
	for cluster in _clusters:
		if cluster["count"] > max_count:
			max_count = cluster["count"]
	return max_count

## Get ring data for fallback drawing
func get_ring_data() -> Dictionary:
	return {
		"center": get_minimap_position(),
		"inner_radius": _body_radius + _inner_radius,
		"outer_radius": _body_radius + _outer_radius,
		"color": get_minimap_color()
	}
