shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_base : source_color = vec3(0.55, 0.55, 0.55);
uniform vec3 color_dark : source_color = vec3(0.15, 0.15, 0.15);
uniform vec3 color_light : source_color = vec3(0.85, 0.85, 0.85);
uniform vec3 color_quartz : source_color = vec3(0.8, 0.6, 0.55);

uniform float scale = 80.0;
uniform float dark_density = 0.35;
uniform float light_density = 0.25;
uniform float quartz_density = 0.15;
uniform float roughness_base = 0.3;

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

// 3D random vector hash
vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// 3D to 1D scalar hash
float hash13(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

// 3D Cellular / Voronoi noise
// Returns vec2(distance_squared, cell_value)
vec2 cellular(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	
	float min_dist = 1.0;
	float cell_val = 0.0;
	
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 neighbor = vec3(float(x), float(y), float(z));
				vec3 point = hash33(i + neighbor);
				vec3 diff = neighbor + point - f;
				float dist = dot(diff, diff); // squared distance
				
				if (dist < min_dist) {
					min_dist = dist;
					cell_val = hash13(i + neighbor);
				}
			}
		}
	}
	return vec2(min_dist, cell_val);
}

void fragment() {
	// Scale position massively for dense granite flecks
	vec3 p = local_pos * scale;
	
	// Get cellular noise data
	vec2 cell_data = cellular(p);
	float dist = cell_data.x;
	float cell_id = cell_data.y;
	
	// Start with the base matrix color
	vec3 albedo = color_base;
	
	// Map the cell ID (0.0 to 1.0) to our different mineral colors
	// using the density thresholds
	if (cell_id < quartz_density) {
		albedo = color_quartz;
	} else if (cell_id < quartz_density + dark_density) {
		albedo = color_dark;
	} else if (cell_id < quartz_density + dark_density + light_density) {
		albedo = color_light;
	}
	
	// Add some macro-level variation so it doesn't look completely uniform from afar
	vec3 p2 = local_pos * (scale * 0.1);
	float macro_noise = cellular(p2).y;
	albedo *= mix(0.85, 1.15, macro_noise);
	
	// Give the individual flecks a slight bevel/lighting effect based on distance to cell edge
	float crystal_edge = smoothstep(0.0, 1.0, dist);
	albedo *= mix(0.9, 1.0, crystal_edge);
	
	ALBEDO = albedo;
	
	// Quartz minerals are usually shinier, so we adjust roughness based on the mineral
	float is_quartz = step(cell_id, quartz_density);
	ROUGHNESS = clamp(roughness_base - (is_quartz * 0.15) + (crystal_edge * 0.1), 0.0, 1.0);
}
