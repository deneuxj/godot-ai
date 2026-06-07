shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 paint_color : source_color = vec3(0.88, 0.87, 0.85); // A nice clean off-white
uniform float roughness_base = 0.65; // High roughness for a matte/eggshell finish
uniform float bump_scale = 120.0; // High frequency for roller texture
uniform float bump_strength = 0.015; // Very subtle

// Easy-to-edit transform properties
uniform vec3 pattern_position = vec3(0.0);
uniform vec3 pattern_rotation = vec3(0.0); // In degrees
uniform vec3 pattern_scale = vec3(1.0);

varying mat3 rot_matrix;

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
	for (int i = 0; i < 3; ++i) { // Just 3 octaves is enough for subtle paint
		v += a * noise(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

// Calculates the very subtle "orange peel" height of a painted wall
float get_wall_height(vec3 view_pos, mat4 inv_view) {
	vec3 obj_pos = (inv_view * vec4(view_pos, 1.0)).xyz;
	vec3 local_p = (rot_matrix * (obj_pos * pattern_scale)) + pattern_position;
	
	return fbm(local_p * bump_scale);
}

void fragment() {
	// Evaluate height at current pixel
	float h = get_wall_height(VERTEX, INV_VIEW_MATRIX);
	
	// Evaluate height at nearby pixels (finite difference) to calculate normals
	float eps = 0.005;
	float h_x = get_wall_height(VERTEX + vec3(eps, 0.0, 0.0), INV_VIEW_MATRIX);
	float h_y = get_wall_height(VERTEX + vec3(0.0, eps, 0.0), INV_VIEW_MATRIX);
	float h_z = get_wall_height(VERTEX + vec3(0.0, 0.0, eps), INV_VIEW_MATRIX);
	
	// View-space gradient (slope of the height map)
	vec3 view_grad = vec3(h_x - h, h_y - h, h_z - h) / eps;
	
	// Perturb the fragment normal
	NORMAL = normalize(NORMAL - view_grad * bump_strength);
	
	ALBEDO = paint_color;
	
	// Add a very subtle variation to roughness based on the texture 
	// to make it feel slightly more organic under direct light
	ROUGHNESS = clamp(roughness_base - (h * 0.05), 0.0, 1.0);
}
