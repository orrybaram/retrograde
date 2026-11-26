// Bloom: a frame's bright parts, read from successively blurrier mip levels and summed,
// so a light gets a tight core and a wide soft halo. Four taps a level hide the blockiness
// of a bare mip. `tex` must be a mipmapped screen texture. Shared by the CRT (the whole
// frame) and UIGlow (the UI alone).
vec3 mip_bloom(sampler2D tex, vec2 uv, vec2 texel, int levels, float threshold) {
	vec3 sum = vec3(0.0);
	for (int i = 1; i <= levels; i++) {
		float lod = float(i);
		vec2 o = texel * exp2(lod) * 0.5;
		vec3 m = (textureLod(tex, uv + vec2(o.x, o.y), lod).rgb
			+ textureLod(tex, uv + vec2(-o.x, o.y), lod).rgb
			+ textureLod(tex, uv + vec2(o.x, -o.y), lod).rgb
			+ textureLod(tex, uv + vec2(-o.x, -o.y), lod).rgb) * 0.25;
		// Blurring dilutes a small light, so wider levels let dimmer averages through.
		float cut = threshold * (1.0 - 0.13 * lod);
		sum += max(m - cut, vec3(0.0)) / max(1.0 - cut, 0.01);
	}
	return sum;
}
