shader_type canvas_item;

uniform vec2 resolution = vec2(600.0, 400.0);
uniform sampler2D noise_texture: filter_nearest, repeat_enable;
uniform float density: hint_range(0.0, 100.0, 0.1) = 20;
uniform float speed_x: hint_range(-100.0, 100.0, 0.1) = 20.0;
uniform float speed_y: hint_range(-100.0, 100.0, 0.1) = 0.0;
uniform float step_size: hint_range(0.0, 1.0, 0.01) = 0.01;
uniform float layers: hint_range(1.0, 10.0, 0.1) = 2.0;
uniform float color_saturation: hint_range(0.0, 1.0, 0.01) = 0.5;

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
		float star_mask = step(step_size, star_intensity);
		
		// Generate random color per star using offset noise samples
		float r = texture(noise_texture, sample_coords + vec2(0.31, 0.17)).r;
		float g = texture(noise_texture, sample_coords + vec2(0.47, 0.83)).r;
		float b = texture(noise_texture, sample_coords + vec2(0.79, 0.53)).r;
		vec3 random_color = vec3(r, g, b);
		
		// Mix between white and random color based on saturation
		vec3 final_color = mix(vec3(1.0), random_color, color_saturation);
		
		star_color += star_mask * brightness * final_color;
	}
	
	COLOR = vec4(star_color, 1.0);
}
