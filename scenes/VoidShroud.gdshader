shader_type canvas_item;

// The Void, drawn over everything: an aperture of dark that closes in from the
// rim, dead-carrier static, and rolling signal tears once the instruments start
// giving up. Alpha only — the world underneath is what gets eaten.

uniform float shroud: hint_range(0.0, 1.0, 0.01) = 0.0;  // how far gone the sky is
uniform float dread: hint_range(0.0, 1.0, 0.01) = 0.0;   // how deep into the Void the ship is (VoidZone.shroud)
uniform vec2 half_extent = vec2(0.5, 0.5);  // (0.5 * aspect, 0.5), so the aperture stays round
uniform vec4 void_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// 0 at the middle of the screen, 1 at the corners.
	float d = length((UV - 0.5) * half_extent * 2.0) / length(half_extent);

	// The rim goes first and the middle holds, so there's something to steer by
	// almost to the end — then the aperture collapses all at once and there isn't.
	float close = pow(shroud, 1.8);
	float dark = smoothstep(mix(1.25, -0.15, close), mix(2.1, 0.1, close), d);

	// It breathes, so the edge never sits still enough to read as a vignette.
	dark += (0.025 * sin(TIME * 0.7) + 0.02 * sin(TIME * 1.9 + d * 6.0)) * shroud;

	// Static, thickest where the instruments are failing.
	dark += (hash(UV * 900.0 + fract(TIME) * 77.0) - 0.4) * dread * dread * 0.18;

	// A tear rolls down the picture once the carrier starts breaking up.
	float roll = fract(UV.y * 2.0 - TIME * 0.35);
	dark += smoothstep(0.98, 1.0, roll) * step(0.55, dread) * dread * 0.7;

	// Nothing at all until the ship is actually out there.
	dark *= smoothstep(0.0, 0.08, shroud);

	COLOR = vec4(void_color.rgb, clamp(dark, 0.0, 1.0));
}
