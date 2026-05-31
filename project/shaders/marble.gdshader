shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.92, 0.92, 0.92);
uniform vec3 vein_color : source_color = vec3(0.15, 0.15, 0.18);
uniform float vein_scale = 3.0;
uniform float distortion = 3.0;
uniform float contrast = 4.0;
uniform float roughness_base = 0.1;

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
	for (int i = 0; i < 5; ++i) {
		v += a * noise(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Domain warping for organic, swirling veins
	vec3 q = vec3(fbm(local_pos + vec3(0.0, 0.0, 0.0)),
				  fbm(local_pos + vec3(5.2, 1.3, 2.8)),
				  fbm(local_pos + vec3(2.4, 9.2, 5.1)));
				  
	vec3 r = vec3(fbm(local_pos + distortion * q + vec3(1.7, 9.2, 2.4)),
				  fbm(local_pos + distortion * q + vec3(8.3, 2.8, 6.1)),
				  fbm(local_pos + distortion * q + vec3(3.9, 4.5, 8.2)));

	// Base FBM with warped coordinates
	float n = fbm(local_pos * vein_scale + distortion * r);
	
	// Create the marble veins using a sine wave
	// Using abs() on a sine wave creates the classic sharp "dips" for veins
	float marble = abs(sin(local_pos.x * vein_scale + n * 10.0));
	
	// Sharpen the veins to make them thin and crisp
	marble = pow(marble, contrast);
	
	// Mix colors: 0 represents the dark vein, 1 represents the base white marble
	vec3 albedo = mix(vein_color, base_color, marble);
	
	ALBEDO = albedo;
	ROUGHNESS = roughness_base;
	
	// Optional: add a tiny bit of clearcoat if your environment supports it
	// CLEARCOAT = 1.0;
	// CLEARCOAT_ROUGHNESS = 0.05;
}
