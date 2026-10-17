shader_type canvas_item;

// The UI's own look, on the CanvasGroup that holds every panel (UIGlow.gd): the screen
// texture here is just the UI drawn onto transparent, with no world to bleed in. Bloom
// is read off the group's premultiplied buffer, so empty space adds nothing and thin
// text blooms softer than a solid bar.
//
// Uniforms without defaults are pushed by UIGlow.gd.

#include "res://scenes/bloom.gdshaderinc"

uniform sampler2D screen_tex: hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float strength;
uniform float threshold = 0.2;          // how bright before it blooms
uniform int levels;                     // mip levels summed: more reaches further

// The boot screen's rolling band, on every UI surface: a faint strip of light creeping
// down the glass. Only where the UI drew, so the world under it doesn't get one, and
// only on surfaces: the dim behind a modal doesn't, the modal's panel does.
uniform vec3 band_color;                // Colors.PRIMARY
uniform float band_alpha = 0.012;
uniform float band_height = 90.0;       // viewport px
uniform float band_speed = 140.0;       // viewport px a second
uniform float view_height;
uniform float band_min_alpha;           // just over Colors.MODAL_DIM's

// A tired tube: now and then a thin strip of rows slips sideways for a moment, its red
// and blue pulling apart. Rises steeply: 0.2 is a couple of small tears a second, 1 is
// dozens of wide ones, the set close to dying.
uniform float glitch: hint_range(0.0, 1.0);
const float GLITCH_HZ = 12.0;           // how often the dice are rolled
const float GLITCH_SLOTS = 4.0;         // tears that can be live at once

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// How far this row slips this tick, in viewport px; 0 for a clean row.
float tear(float y) {
	float shift = 0.0;
	for (float s = 0.0; s < GLITCH_SLOTS; s++) {
		float t = floor(TIME * GLITCH_HZ) * GLITCH_SLOTS + s;
		if (hash(t) < 0.9 * glitch * glitch) {
			float top = hash(t + 0.31) * view_height;
			float height = 2.0 + hash(t + 0.57) * (8.0 + glitch * 24.0);
			if (y >= top && y < top + height) {
				shift = (hash(t + 0.83) - 0.5) * 2.0 * (2.0 + glitch * 14.0);
			}
		}
	}
	return shift;
}

void fragment() {
	vec2 texel = SCREEN_PIXEL_SIZE;
	// Viewport px to UV across: the width in viewport px is the height times the aspect.
	float px_x = texel.x / (view_height * texel.y);
	float shift = tear(SCREEN_UV.y * view_height);
	vec2 uv = SCREEN_UV + vec2(shift * px_x, 0.0);
	vec4 c = textureLod(screen_tex, uv, 0.0);
	if (shift != 0.0) {
		vec2 split = vec2((1.0 + glitch * 2.0) * px_x, 0.0);
		c.r = textureLod(screen_tex, uv + split, 0.0).r;
		c.b = textureLod(screen_tex, uv - split, 0.0).b;
	}

	vec3 g = mip_bloom(screen_tex, SCREEN_UV, texel, levels, threshold) * strength / 2.0;

	// Glow lands on the text and spills past it into empty space, where it brings its
	// own coverage. Back out of premultiplied for COLOR.
	vec3 rgb = c.rgb + g;
	float a = clamp(c.a + max(g.r, max(g.g, g.b)) * (1.0 - c.a), 0.0, 1.0);
	rgb = min(rgb / max(a, 0.0001), vec3(1.0));

	float y = SCREEN_UV.y * view_height;
	float roll = mod(TIME * band_speed, view_height + band_height) - band_height;
	if (y >= roll && y < roll + band_height) {
		float surface = smoothstep(band_min_alpha - 0.02, band_min_alpha, c.a);
		rgb = mix(rgb, band_color, band_alpha * surface);
	}
	COLOR = vec4(rgb, a);
}
