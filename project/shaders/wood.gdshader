shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color1 : source_color = vec3(0.45, 0.25, 0.1);
uniform vec3 color2 : source_color = vec3(0.2, 0.1, 0.03);
uniform float ring_scale = 15.0;
uniform float ring_detail = 2.0;
uniform float distortion = 0.15;
uniform float grain_scale = 40.0;
uniform float roughness_base = 0.8;

// Parquet properties
uniform float plank_length = 2.0;
uniform float plank_width = 0.2;
uniform int interleave = 3;
uniform float plank_angle = 0.0; // In degrees

varying vec3 local_pos;

void vertex() {
	local_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Pseudo-random hash for noise
float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// 3D Value Noise
float noise(vec3 x) {
	vec3 p = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	
	return mix(mix(mix(hash(p + vec3(0.0, 0.0, 0.0)), 
					   hash(p + vec3(1.0, 0.0, 0.0)), f.x),
				   mix(hash(p + vec3(0.0, 1.0, 0.0)), 
					   hash(p + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			   mix(mix(hash(p + vec3(0.0, 0.0, 1.0)), 
					   hash(p + vec3(1.0, 0.0, 1.0)), f.x),
				   mix(hash(p + vec3(0.0, 1.0, 1.0)), 
					   hash(p + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

// Fractal Brownian Motion
float fbm(vec3 x) {
	float v = 0.0;
	float a = 0.5;
	vec3 shift = vec3(100.0);
	for (int i = 0; i < 4; ++i) {
		v += a * noise(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// 1. Apply user rotation around Y axis
	float rad = radians(plank_angle);
	float cos_a = cos(rad);
	float sin_a = sin(rad);
	vec2 rotated_xz = vec2(
		local_pos.x * cos_a - local_pos.z * sin_a,
		local_pos.x * sin_a + local_pos.z * cos_a
	);
	vec3 floor_pos = vec3(rotated_xz.x, local_pos.y, rotated_xz.y);

	// 2. Calculate plank tiling
	// Assume planks are aligned with X for length and Z for width
	float row = floor(floor_pos.z / plank_width);
	float shift = mod(row, float(interleave)) * (plank_length / float(interleave));
	float col = floor((floor_pos.x + shift) / plank_length);
	vec2 cell_id = vec2(col, row);
	
	// 3. Create a unique 3D offset per plank
	vec3 tile_offset = vec3(
		fract(sin(dot(cell_id, vec2(12.9898, 78.233))) * 43758.5453),
		fract(sin(dot(cell_id, vec2(33.503, 55.126))) * 43758.5453),
		fract(sin(dot(cell_id, vec2(10.331, 34.123))) * 43758.5453)
	) * 100.0; // scale up offset for varied tree slice
	
	// 4. Wood grain logic
	// The tree trunk runs along the plank length (X axis).
	vec3 t_pos = floor_pos + tile_offset;

	// Stretch along the X axis
	vec3 p = t_pos * vec3(0.1, 1.0, 1.0); 
	
	// Add noise distortion to make rings irregular
	float n = fbm(p * 3.0) * distortion;
	
	// Distance from the center in the YZ plane (cross section of the tree trunk)
	float dist = length(t_pos.yz) + n;
	
	// Calculate wood rings using a pattern that creates sharp edges
	float rings = fract(dist * ring_scale + fbm(t_pos * ring_detail));
	rings = smoothstep(0.0, 0.8, rings) - smoothstep(0.8, 1.0, rings);
	
	// Fine grain detail, stretched along X
	float grain = fbm(t_pos * vec3(grain_scale * 0.05, grain_scale, grain_scale));
	
	// Mix colors based on rings and grain
	float mix_factor = clamp(rings * 0.7 + grain * 0.3, 0.0, 1.0);
	vec3 albedo = mix(color1, color2, mix_factor);
	
	ALBEDO = albedo;
	ROUGHNESS = clamp(roughness_base + grain * 0.2, 0.0, 1.0);
}
