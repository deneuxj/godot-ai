shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.9, 0.87, 0.8);
uniform vec3 dark_color : source_color = vec3(0.75, 0.72, 0.65);
uniform float rough_scale = 60.0;
uniform float trowel_scale = 3.0;
uniform float bump_strength = 0.02;
uniform float blend_weight : hint_range(0.0, 1.0) = 0.7;

// Easy-to-edit transform properties
uniform vec3 pattern_position = vec3(0.0);
uniform vec3 pattern_rotation = vec3(0.0); // In degrees
uniform vec3 pattern_scale = vec3(1.0);

varying mat3 rot_matrix;
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
	
	// Pass the rotation matrix to the fragment shader
	rot_matrix = rz * rx * ry;
	
	// Calculate local position for stable texture mapping
	local_pos = (rot_matrix * (VERTEX * pattern_scale)) + pattern_position;
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

// Calculates the procedural height map for stucco
float get_stucco_height(vec3 p) {
	// Apply user transforms to local coordinates
	vec3 local = (rot_matrix * (p * pattern_scale)) + pattern_position;
	
	// 1. Low frequency trowel marks (smooth but irregular sweeping patterns)
	float trowel = fbm(local * trowel_scale);
	// Flatten the peaks to simulate the flat edge of a trowel
	trowel = smoothstep(0.2, 0.8, trowel);
	
	// 2. High frequency sand/grit
	float grit = noise(local * rough_scale);
	
	// Combine them using the blend weight
	return mix(grit, trowel, blend_weight);
}

void fragment() {
	// Evaluate height at current pixel
	float h = get_stucco_height(local_pos);
	
	// Evaluate height at nearby pixels (finite difference) to calculate normals
	// We use a small epsilon relative to the frequency to capture details without skipping
	float eps = 0.002;
	float h_x = get_stucco_height(local_pos + vec3(eps, 0.0, 0.0));
	float h_y = get_stucco_height(local_pos + vec3(0.0, eps, 0.0));
	float h_z = get_stucco_height(local_pos + vec3(0.0, 0.0, eps));
	
	// View-space gradient (slope of the height map)
	vec3 view_grad = vec3(h_x - h, h_y - h, h_z - h) / eps;
	
	// Perturb the fragment normal
	NORMAL = normalize(NORMAL - view_grad * bump_strength);
	
	// Add pseudo-ambient occlusion by darkening the crevices
	vec3 albedo = mix(dark_color, base_color, h);
	
	ALBEDO = albedo;
	
	// Stucco is quite rough, but slightly smoother on the troweled peaks
	ROUGHNESS = 0.95 - h * 0.15;
}