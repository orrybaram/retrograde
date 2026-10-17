shader_type canvas_item;

// The world re-sampled as low-res pixel art, then shown the way Animal Well shows its
// 320x180 frame: a horizontal blend between neighbouring art pixels (a soft beam across
// the line), a hard snap to the row's centre vertically, and a scanline whose edge
// fades by how bright the pixel is — a bright beam swells to fill its line, a dark one
// thins. Sits between the world and the UI layers, so text stays sharp.
//
// It point-samples the full-res frame on a coarse grid rather than rendering at low
// res, so anything thinner than one art pixel can flicker as it moves. Good enough to
// judge the look; the real thing would draw the world into a small SubViewport.

uniform sampler2D screen_tex: hint_screen_texture, filter_nearest;

uniform float pixel_size = 4.0;        // viewport px per art pixel
uniform float scanlines: hint_range(0.0, 1.0) = 0.6;
uniform bool quantize = false;          // snap to the Violet Signal palette
uniform float dither: hint_range(0.0, 1.0) = 0.25;

const int MAX_PALETTE = 24;
uniform vec3 palette[MAX_PALETTE];
uniform int palette_size = 0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

vec3 nearest(vec3 c) {
	vec3 best = c;
	float best_d = 1e9;
	for (int i = 0; i < palette_size; i++) {
		// Weighted toward green, roughly how the eye ranks the channels.
		vec3 diff = (c - palette[i]) * vec3(0.30, 0.59, 0.11);
		float d = dot(diff, diff);
		if (d < best_d) {
			best_d = d;
			best = palette[i];
		}
	}
	return best;
}

// One art pixel: the full-res frame read at that cell's centre.
vec3 art(vec2 cell, vec2 texel) {
	vec3 c = texture(screen_tex, (cell + 0.5) * pixel_size * texel).rgb;
	if (quantize && palette_size > 0) {
		ivec2 b = ivec2(mod(cell, 4.0));
		float threshold = BAYER[b.y * 4 + b.x] / 16.0 - 0.5;
		// Flat space stays flat: only pixels lifted off the background get dithered.
		float lift = smoothstep(0.03, 0.12, distance(c, palette[0]));
		c = nearest(c + threshold * dither * 0.12 * lift);
	}
	return c;
}

void fragment() {
	vec2 texel = SCREEN_PIXEL_SIZE;
	vec2 a = SCREEN_UV / texel / pixel_size;  // position in art pixels

	// Horizontal: blend the two nearest cell centres. Vertical: stay on this row.
	float x = a.x - 0.5;
	float row = floor(a.y);
	vec3 left = art(vec2(floor(x), row), texel);
	vec3 right = art(vec2(floor(x) + 1.0, row), texel);
	vec3 c = mix(left, right, smoothstep(0.0, 1.0, fract(x)));

	// Scanline: distance from the row's centre, against a beam that widens with light.
	float luma = dot(c, vec3(0.30, 0.59, 0.11));
	float dy = abs(fract(a.y) - 0.5) * 2.0;     // 0 at centre, 1 at the row edge
	float beam = mix(0.8, 1.2, luma);
	float line = 1.0 - smoothstep(beam - 0.5, beam, dy);
	// The gaps eat light, so drive the beam a little hotter to keep the frame's level.
	c *= mix(1.0, line * 1.3, scanlines);

	COLOR = vec4(c, 1.0);
}
