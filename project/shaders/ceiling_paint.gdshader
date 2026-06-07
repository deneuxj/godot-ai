shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 paint_color : source_color = vec3(0.92, 0.92, 0.92); // Standard ceiling white
uniform float roughness_base = 0.85; // Very matte
uniform float bump_scale = 100.0; // Size of the popcorn clusters
uniform float bump_strength = 0.15; // Quite bumpy

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

// 3D random vector hash
vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// 3D Cellular / Voronoi noise
// Returns distance to the closest point
float cellular(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	
	float min_dist = 1.0;
	
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point = hash33(i + neighbor);
				vec3 diff = neighbor + point - f;
				float dist = dot(diff, diff); // squared distance
				
				if (dist < min_dist) {
					min_dist = dist;
				}
			}
		}
	}
	return min_dist;
}

// Calculates the bumpy, bubbly height of projected paint / popcorn ceiling
float get_ceiling_height(vec3 view_pos, mat4 inv_view) {
	vec3 obj_pos = (inv_view * vec4(view_pos, 1.0)).xyz;
	vec3 local_p = (rot_matrix * (obj_pos * pattern_scale)) + pattern_position;
	
	vec3 p = local_p * bump_scale;
	
	// Popcorn bumps are roughly spherical, overlapping blobs.
	// In cellular noise, distance is 0 at the center of the cell and ~1 at the edge.
	// We invert it so bumps are at the center of the cells.
	float c1 = cellular(p);
	float c2 = cellular(p + vec3(4.2, 1.3, 7.8)); // Second layer for chaotic clustering
	
	// Smooth the cellular noise to create nice bubbly, rounded bumps
	float b1 = smoothstep(0.0, 0.5, 1.0 - c1);
	float b2 = smoothstep(0.0, 0.5, 1.0 - c2);
	
	// Combine layers by taking the highest point to look like clustered droplets/plaster
	return max(b1, b2);
}

void fragment() {
	// Evaluate height at current pixel
	float h = get_ceiling_height(VERTEX, INV_VIEW_MATRIX);
	
	// Evaluate height at nearby pixels (finite difference) to calculate normals
	float eps = 0.005;
	float h_x = get_ceiling_height(VERTEX + vec3(eps, 0.0, 0.0), INV_VIEW_MATRIX);
	float h_y = get_ceiling_height(VERTEX + vec3(0.0, eps, 0.0), INV_VIEW_MATRIX);
	float h_z = get_ceiling_height(VERTEX + vec3(0.0, 0.0, eps), INV_VIEW_MATRIX);
	
	// View-space gradient (slope of the height map)
	vec3 view_grad = vec3(h_x - h, h_y - h, h_z - h) / eps;
	
	// Perturb the fragment normal
	NORMAL = normalize(NORMAL - view_grad * bump_strength);
	
	ALBEDO = paint_color;
	
	// Projected paint scatters light highly irregularly
	ROUGHNESS = clamp(roughness_base - (h * 0.15), 0.0, 1.0);
}
