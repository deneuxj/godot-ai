shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color1 : source_color = vec3(0.45, 0.25, 0.1);
uniform vec3 color2 : source_color = vec3(0.2, 0.1, 0.03);
uniform float ring_scale = 15.0;
uniform float ring_detail = 2.0;
uniform float distortion = 0.15;
uniform float grain_scale = 40.0;
uniform float roughness_base = 0.8;

// Easy-to-edit transform properties
uniform vec3 pattern_position = vec3(0.0);
uniform vec3 pattern_rotation = vec3(0.0); // In degrees
uniform vec3 pattern_scale = vec3(1.0);

varying vec3 local_pos;

void vertex() {
	// Convert degrees to radians and compute rotation matrices (YXZ order)
	vec3 rad = radians(pattern_rotation);
	vec2 x = vec2(cos(rad.x), sin(rad.x));
	vec2 y = vec2(cos(rad.y), sin(rad.y));
	vec2 z = vec2(cos(rad.z), sin(rad.z));
	
	mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, x.x, x.y), vec3(0.0, -x.y, x.x));
	mat3 ry = mat3(vec3(y.x, 0.0, -y.y), vec3(0.0, 1.0, 0.0), vec3(y.y, 0.0, y.x));
	mat3 rz = mat3(vec3(z.x, z.y, 0.0), vec3(-z.y, z.x, 0.0), vec3(0.0, 0.0, 1.0));
	mat3 rot = rz * rx * ry;
	
	local_pos = (rot * (VERTEX * pattern_scale)) + pattern_position;
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
	// Base coordinates, scaled to create stretching along the Y axis
	// Wood grain usually stretches along the trunk
	vec3 p = local_pos * vec3(1.0, 0.1, 1.0); 
	
	// Add noise distortion to make rings irregular
	float n = fbm(p * 3.0) * distortion;
	
	// Distance from the center (Z/X plane implies the trunk is along the Y axis)
	float dist = length(local_pos.xz) + n;
	
	// Calculate wood rings using a pattern that creates sharp edges
	float rings = fract(dist * ring_scale + fbm(local_pos * ring_detail));
	rings = smoothstep(0.0, 0.8, rings) - smoothstep(0.8, 1.0, rings);
	
	// Fine grain detail
	float grain = fbm(local_pos * vec3(grain_scale, grain_scale * 0.05, grain_scale));
	
	// Mix colors based on rings and grain
	float mix_factor = clamp(rings * 0.7 + grain * 0.3, 0.0, 1.0);
	vec3 albedo = mix(color1, color2, mix_factor);
	
	ALBEDO = albedo;
	ROUGHNESS = clamp(roughness_base + grain * 0.2, 0.0, 1.0);
}
