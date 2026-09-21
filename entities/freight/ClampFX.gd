extends Node2D
class_name ClampFX

## The clunk of Freight being clamped or let go: a small puff of smoke and a spray of tiny
## sparks at the Lug. Left in the world where it happened, drifting on a little, so a
## moving ship leaves it behind. Particles draw on their own randomness, never the shared RNG.

const SMOKE_LIFETIME := 0.7
const SPARK_LIFETIME := 0.35
## Seconds' worth of the ship's velocity the burst drifts on before settling.
const DRIFT := 0.3

## Burst at `pos` (global) in `world`, drifting with `velocity` for its first instant.
## `strength` scales how many particles fly and how hard; `density` multiplies just the count.
static func burst(world: Node, pos: Vector2, velocity := Vector2.ZERO, strength := 1.0, density := 1.0) -> ClampFX:
	var fx := ClampFX.new()
	fx.add_to_group("clamp_fx")
	world.add_child(fx)
	fx.global_position = pos
	fx.z_index = 3
	fx._emit(_smoke(strength, density))
	fx._emit(_sparks(strength, density))
	# Drift on a little with the ship, easing to a stop, so it isn't nailed to space
	fx.create_tween().tween_property(fx, "global_position", pos + velocity * DRIFT, SMOKE_LIFETIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var reap := fx.create_tween()
	reap.tween_interval(SMOKE_LIFETIME + 0.5)
	reap.tween_callback(fx.queue_free)
	return fx

func _emit(p: GPUParticles2D) -> void:
	add_child(p)
	p.emitting = true

static func _smoke(strength := 1.0, density := 1.0) -> GPUParticles2D:
	var p := _particles(int(10 * strength * density), SMOKE_LIFETIME)
	var mat := p.process_material as ParticleProcessMaterial
	mat.initial_velocity_min = 8.0 * strength
	mat.initial_velocity_max = 26.0 * strength
	mat.damping_min = 20.0
	mat.damping_max = 30.0
	mat.scale_min = 3.0
	mat.scale_max = 5.0
	mat.scale_curve = _curve(0.6, 1.4)
	mat.color_ramp = _fade(Color(Colors.HULL_LIGHT, 0.55))
	return p

static func _sparks(strength := 1.0, density := 1.0) -> GPUParticles2D:
	var p := _particles(int(14 * strength * density), SPARK_LIFETIME * sqrt(strength))
	var mat := p.process_material as ParticleProcessMaterial
	mat.initial_velocity_min = 50.0 * strength
	mat.initial_velocity_max = 120.0 * strength
	mat.damping_min = 120.0
	mat.damping_max = 180.0
	mat.scale_min = 1.0
	mat.scale_max = 1.6
	mat.color_ramp = _fade(Colors.PRIMARY, Colors.CREAM)
	return p

static func _particles(amount: int, lifetime: float) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 180.0
	mat.gravity = Vector3.ZERO
	p.process_material = mat
	return p

static func _fade(from: Color, to: Color = Color(0, 0, 0, 0)) -> GradientTexture1D:
	var end := Color(to, 0.0) if to.a > 0.0 else Color(from, 0.0)
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, end)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex

static func _curve(start: float, end: float) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 2.0
	c.add_point(Vector2(0, start))
	c.add_point(Vector2(1, end))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex
