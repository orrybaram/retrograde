shader_type canvas_item;

uniform vec2 resolution = vec2(600.0, 400.0);
uniform sampler2D noise_texture: filter_nearest, repeat_enable;
uniform float density: hint_range(0.0, 100.0, 0.1) = 20;
uniform float speed_x: hint_range(-100.0, 100.0, 0.001) = 0.0;
uniform float speed_y: hint_range(-100.0, 100.0, 0.001) = 0.0;
uniform float step_size: hint_range(0.0, 1.0, 0.01) = 0.01;
uniform float layers: hint_range(1.0, 16.0, 1.0) = 9.0;
uniform float color_saturation: hint_range(0.0, 1.0, 0.01) = 0.5;
// Palette (keep in sync with scripts/Colors.gd; set from StarField.gd)
uniform vec4 space_color: source_color = vec4(0.078, 0.075, 0.059, 1.0);
uniform vec4 nebula_color: source_color = vec4(0.180, 0.165, 0.125, 1.0);
uniform vec4 star_color_warm: source_color = vec4(0.949, 0.910, 0.824, 1.0);
uniform vec4 star_color_cool: source_color = vec4(0.435, 0.722, 0.824, 1.0);
uniform float nebula_strength: hint_range(0.0, 1.0, 0.01) = 0.8;
// 1.0 = the sky as it should be, 0.0 = the Void. Faint stars wink out first as
// this falls, then the survivors dim, then the olive-black itself goes to nothing.
uniform float star_fade: hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec2 uv = UV;
	uv.x *= resolution.x / resolution.y; 
	// speed_x/speed_y are an OFFSET in UV space, not a rate: StarField.gd has already
	// integrated the ship's velocity into them. Multiplying by TIME here would integrate
	// a second time, so a steady cruise kept accelerating the sky - the longer the
	// session ran, the faster the stars tore past.
	vec2 speed = vec2(speed_x, speed_y);
	vec3 star_color = vec3(0.0);
	
	for (float i = 0.0; i < layers; i++) {
		// 0.0 = the layer just off the bow, 1.0 = the far wall of the galaxy.
		float depth = i / max(layers - 1.0, 1.0);
		float shift = i * 0.2;
		// Depth is sold by how little the far layers move. The back of the field
		// crawls at a seventh of the near stars, so flying reads as crossing
		// something enormous rather than sliding a flat sheet past the window.
		float parallax_factor = 1.0 / (1.0 + depth * 6.0);
		// Far layers pack more, smaller stars into the same frame - but only a
		// little, or the back of the field turns to dust.
		float layer_scale = 1.0 + depth * 0.8;
		// Dim with distance, but never past zero - a negative layer would eat light.
		float brightness = mix(1.0, 0.10, depth);
		vec2 layer_speed = speed * parallax_factor;
		vec2 sample_coords = uv * layer_scale + shift + layer_speed;

		// Sample noise for star mask
		float noise_sample = texture(noise_texture, sample_coords).r;
		// Thin the distant layers hard: depth is meant to read as a few faint
		// pinpricks behind the near stars, not as grain over the whole window.
		float star_intensity = pow(noise_sample, density + depth * 14.0);
		// Raising the cutoff as the sky dies takes the dimmest stars out first,
		// so the field thins rather than fading as one sheet.
		float star_mask = step(step_size + (1.0 - star_fade) * (1.0 - step_size), star_intensity);

		// Generate random color per star using offset noise samples
		float r = texture(noise_texture, sample_coords + vec2(0.31, 0.17)).r;
		float g = texture(noise_texture, sample_coords + vec2(0.47, 0.83)).r;
		float b = texture(noise_texture, sample_coords + vec2(0.79, 0.53)).r;
		// Mostly warm cream stars, with the occasional blue glint
		float cool = step(0.62, r) * step(0.55, b);
		vec3 tinted = mix(star_color_warm.rgb, star_color_cool.rgb, cool);
		vec3 final_color = mix(star_color_warm.rgb, tinted, color_saturation) * (0.85 + 0.15 * g);

		star_color += star_mask * brightness * final_color;
	}
	
	// Soft haze drifting slowly with parallax, over olive-black space
	vec2 haze_uv = UV + speed * 0.05;
	float haze = 0.5 + 0.25 * sin(haze_uv.x * 3.1 + 1.3) + 0.25 * sin(haze_uv.y * 2.3 + haze_uv.x * 1.7);
	haze *= smoothstep(1.4, 0.1, distance(UV, vec2(0.75, 0.3)));
	vec3 background = mix(space_color.rgb, nebula_color.rgb, clamp(haze, 0.0, 1.0) * nebula_strength);
	COLOR = vec4((background + star_color * star_fade) * star_fade, 1.0);
}
