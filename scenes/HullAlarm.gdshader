shader_type canvas_item;

// The hull talking back, drawn over everything: a rust vignette that breathes at the
// rim while the hull is failing, and a hard scanline tear across the picture on the
// frame you take a hit. Additive-ish alpha only — the world underneath keeps its color.

uniform float alarm: hint_range(0.0, 1.0, 0.01) = 0.0;  // how far gone the hull is
uniform float hit: hint_range(0.0, 1.0, 0.01) = 0.0;    // the decaying kick from the last wound
uniform float pulse: hint_range(0.0, 1.0, 0.01) = 0.0;  // the alarm's own heartbeat, driven from GDScript
uniform vec2 half_extent = vec2(0.5, 0.5);  // (0.5 * aspect, 0.5), so the vignette stays round
uniform vec4 alarm_color: source_color = vec4(0.65, 0.22, 0.18, 1.0);
uniform vec4 hit_color: source_color = vec4(0.91, 0.76, 0.44, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// 0 at the middle of the screen, 1 at the corners.
	float d = length((UV - 0.5) * half_extent * 2.0) / length(half_extent);

	// The vignette only ever eats the rim — the middle is where the player is flying,
	// and an alarm that blinds you is worse than the damage it is warning about.
	float reach = mix(0.88, 0.58, alarm);
	float vignette = smoothstep(reach, 1.1, d) * alarm;
	// Breathes with the same clock as the hull bar, so the whole warning is one pulse.
	vignette *= mix(0.55, 1.0, pulse);

	// A hit floods the rim harder and further in for the moment it lasts, but never
	// closes over the middle — the player is still flying through it.
	float flood = smoothstep(mix(0.95, 0.45, hit), 1.15, d) * hit;

	// Torn scanlines while the hit rings: a few bands of the picture knocked bright.
	float band = step(0.9, hash(vec2(floor(UV.y * 90.0), floor(TIME * 40.0))));
	float tear = band * hit * 0.28;

	// Grain, so the flood has some texture to it rather than reading as a red filter.
	float grain = (hash(UV * 700.0 + fract(TIME) * 31.0) - 0.5) * hit * 0.09;

	// Only part-way to the highlight: a hit should read as the hull's own rust going
	// bright, not as the screen being flashed white.
	vec3 col = mix(alarm_color.rgb, hit_color.rgb, clamp(hit, 0.0, 1.0) * 0.5);
	float a = clamp(vignette * 0.45 + flood * 0.38 + tear + grain, 0.0, 1.0);
	COLOR = vec4(col, a);
}
