shader_type canvas_item;

// A Sweep read this (ReadoutShimmer): bands of light run across it, added on top of what it
// draws so even dark hull lights up. The bands are laid out in world space, so the owner and
// every child it lends this to shimmer as one thing.

uniform vec4 tint : source_color;
uniform float glow;      // 0 settled .. 1 brightest (the shimmer's envelope)
uniform float sweep;     // how far the bands have travelled, in periods
uniform float period = 36.0;
uniform vec2 dir = vec2(0.7071, -0.7071);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float phase = dot(world, dir) / period - sweep;
	float band = pow(max(cos(phase * TAU), 0.0), 6.0);
	COLOR.rgb += tint.rgb * glow * (0.25 + 0.9 * band);
}
