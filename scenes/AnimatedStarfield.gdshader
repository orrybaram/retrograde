shader_type canvas_item;

uniform vec2 resolution = vec2(600.0, 400.0);
uniform sampler2D noise_texture: filter_nearest, repeat_enable;
uniform float density: hint_range(0.0, 100.0, 0.1) = 20;
uniform float speed_x: hint_range(-100.0, 100.0, 0.1) = 20.0;
uniform float speed_y: hint_range(-100.0, 100.0, 0.1) = 0.0;
uniform float step_size: hint_range(0.0, 1.0, 0.01) = 0.01;
uniform float layers: hint_range(1.0, 10.0, 0.1) = 2.0;
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
	vec2 speed = TIME * vec2(speed_x, speed_y) * 0.004;
	vec3 star_color = vec3(0.0);
	
	for (float i = 0.0; i < layers; i++) { 
		float shift = i * 0.2;
		float brightness = 1.0 - i * 0.3;
		float parallax_factor = 1.0 - i * 0.01;
		vec2 layer_speed = speed * parallax_factor;
		vec2 sample_coords = uv + shift + layer_speed;
		
		// Sample noise for star mask
		float noise_sample = texture(noise_texture, sample_coords).r;
		float star_intensity = pow(noise_sample, density);
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
	vec2 haze_uv = UV + speed * 0.15;
	float haze = 0.5 + 0.25 * sin(haze_uv.x * 3.1 + 1.3) + 0.25 * sin(haze_uv.y * 2.3 + haze_uv.x * 1.7);
	haze *= smoothstep(1.4, 0.1, distance(UV, vec2(0.75, 0.3)));
	vec3 background = mix(space_color.rgb, nebula_color.rgb, clamp(haze, 0.0, 1.0) * nebula_strength);
	COLOR = vec4((background + star_color * star_fade) * star_fade, 1.0);
}
