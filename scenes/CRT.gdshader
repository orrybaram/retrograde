shader_type canvas_item;

// The tube over the whole picture, world and UI alike: a PVM-style scanline whose edge
// fades by how bright the pixel is — a bright beam swells to fill its line, a dark one
// thins — and bloom off the bright spots.
//
// Uniforms have no defaults: CRT.gd pushes every one from its DEFAULTS.

#include "res://scenes/bloom.gdshaderinc"

uniform sampler2D screen_tex: hint_screen_texture, filter_nearest;
// The same frame, mipmapped: each level down is a wider blur for the bloom to read.
uniform sampler2D screen_blur: hint_screen_texture, filter_linear_mipmap;

uniform float scanlines: hint_range(0.0, 1.0);
uniform float line_height;              // screen px per scanline, beam and gap together
uniform bool glow;
uniform float glow_strength;
uniform float glow_threshold;           // how bright before it blooms

void fragment() {
	vec2 texel = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// Scanline: distance from the line's centre, against a beam that widens with light.
	// A line is never thinner than 2 px — under that there'd be no edge to fade. Measured
	// from the pixel's top edge, not its centre: centred, a 2 px line's two rows sit at
	// equal distances from the middle, dim equally, and the line vanishes into a flat
	// darkening.
	float line_y = (SCREEN_UV.y / texel.y - 0.5) / max(line_height, 2.0);
	float luma = dot(c, vec3(0.30, 0.59, 0.11));
	float dy = abs(fract(line_y) - 0.5) * 2.0;  // 0 at centre, 1 at the line edge
	float beam = mix(0.8, 1.2, luma);
	float line = 1.0 - smoothstep(beam - 0.5, beam, dy);
	// The gaps eat light, so drive the beam a little hotter to keep the frame's level.
	c *= mix(1.0, line * 1.3, scanlines);

	if (glow) {
		vec3 g = clamp(mip_bloom(screen_blur, SCREEN_UV, texel, 5, glow_threshold) / 2.5 * glow_strength, 0.0, 1.0);
		c = 1.0 - (1.0 - c) * (1.0 - g);  // screen blend: lightens, never blows out
	}

	COLOR = vec4(c, 1.0);
}
