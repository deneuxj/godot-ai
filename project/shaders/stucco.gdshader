shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.9, 0.87, 0.8);
uniform float rough_scale = 150.0;
uniform float trowel_scale = 12.0;
uniform float rough_strength : hint_range(0.0, 0.01) = 0.002;
uniform float trowel_strength : hint_range(0.0, 0.01) = 0.002;
uniform float turbulence_strength : hint_range(0.0, 1.0) = 0.5;
uniform float turbulence_frequency : hint_range(0.1, 20.0) = 1.0;
uniform float blend_weight : hint_range(0.0, 1.0) = 0.7;

varying vec3 local_pos;
varying vec3 v_normal_model;
varying vec3 v_tangent;
varying vec3 v_bitangent;

void vertex() {
	local_pos = VERTEX;
		
	// Derive tangents in local space for surface-aligned sampling
	v_normal_model = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 up = abs(v_normal_model.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	v_tangent = normalize(cross(up, v_normal_model));
	v_bitangent = cross(v_normal_model, v_tangent);
}

// Hash function for float inputs
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// Hash function for vec3 inputs
float hash_vec3(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    
    float n = i.x + i.y * 57.0 + 113.0 * i.z;
    return mix(
        mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
            mix(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
        mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
            mix(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
}

// Improved FBM with better octave distribution for stucco
float fbm(vec3 x) {
    float v = 0.0;
    float a = 0.5;
    vec3 shift = vec3(100.0);
    for (int i = 0; i < 6; ++i) {
        v += a * noise(x);
        x = x * 2.0 + shift;
        a *= 0.5;
    }
    return v;
}

// Worley-like noise for grain texture
float grain(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    float min_dist = 1.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                float point = hash_vec3(i + neighbor);
                point = fract(point * 0.5) * 2.0 - 1.0;
                vec3 diff = neighbor + vec3(point) - f;
                min_dist = min(min_dist, length(diff));
            }
        }
    }
    return 1.0 - min_dist;
}

vec3 get_distorted_pos(vec3 p) {
	// Use multiple noise layers for organic turbulence
	vec3 distorted = p;
	distorted += (noise(p * turbulence_frequency * vec3(1.3, 1.1, 1.0)) - 0.5) * turbulence_strength * 0.5;
	distorted += (noise(p * turbulence_frequency * vec3(0.9, 1.2, 1.1)) - 0.5) * turbulence_strength * 0.3;
	return distorted;
}

// Calculates the procedural height map for stucco with improved grain
float get_stucco_height(vec3 p) {	
	// Apply turbulence warping before sampling
	vec3 distorted = get_distorted_pos(p);
	
	// Use multiple noise layers for realistic stucco texture
	float trowel = fbm(distorted * trowel_scale) * trowel_strength;
	float grit = grain(distorted * rough_scale) * rough_strength;
	
	// Combine with better blending
	return mix(grit, trowel, blend_weight);
}

void fragment() {
	// Evaluate height at current pixel with multiple samples for anti-banding
	float h_center = get_stucco_height(local_pos);
	
	// Use smaller eps to avoid banding from coarse sampling
	vec2 eps = vec2(0.01, 0.01); // Reduced from 0.03 for finer gradient accuracy
	
	// Sample height at multiple neighboring points and use average gradient
	float h_t_p = get_stucco_height(local_pos + v_tangent * eps.x);
	float h_t_m = get_stucco_height(local_pos - v_tangent * eps.x);
	float h_b_p = get_stucco_height(local_pos + v_bitangent * eps.y);
	float h_b_m = get_stucco_height(local_pos - v_bitangent * eps.y);
	
	// Compute normal from height variation from neighbouring points
	vec2 slope = vec2((h_t_p - h_t_m) / (2.0 * eps.x),(h_b_p - h_b_m) / (2.0 * eps.y));
	// Construct the deformed tangent and bitangent vectors
	vec3 tangent_deformed = v_tangent + slope.x * v_normal_model;
	vec3 bitangent_deformed = v_bitangent + slope.y * v_normal_model;
	// The cross product of the deformed vectors gives the new normal
	vec3 model_normal = normalize(cross(tangent_deformed, bitangent_deformed));
	NORMAL = normalize((VIEW_MATRIX * vec4(model_normal, 0.0)).xyz);
	
	ALBEDO = base_color;
	
	// Stucco is quite rough, but slightly smoother on the troweled peaks
	ROUGHNESS = 0.95 - h_center * 0.15;
}