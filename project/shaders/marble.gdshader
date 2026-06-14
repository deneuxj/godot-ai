shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.92, 0.92, 0.92);
uniform vec3 vein_color : source_color = vec3(0.15, 0.15, 0.18);
uniform float vein_scale = 3.0;
uniform float distortion = 3.0;
uniform float contrast = 4.0;
uniform float roughness_base = 0.1;

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
	for (int i = 0; i < 5; ++i) {
		v += a * noise(x);
		x = x * 2.0 + shift;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Calculate a grid-based seed to ensure each 0.6m x 0.6m tile is unique
	// We use the floor of (position / size) to create distinct "cells"
	vec3 tile_size = vec3(0.6, 0.6, 0.6);
	vec3 cell_id = floor(local_pos / tile_size);
	
	// Use a hash of the cell ID to provide a unique offset for each tile.
	// This ensures that even if the marble pattern is continuous in "tile space",
	// each 0.6m block has its own unique variation.
	vec3 tile_offset = vec3(
		fract(sin(dot(cell_id, vec3(12.9898, 78.233, 45.164))) * 43758.5453),
		fract(sin(dot(cell_id, vec3(33.503, 55.126, 11.921))) * 43758.5453),
		fract(sin(dot(cell_id, vec3(10.331, 34.123, 72.445))) * 43758.5453)
	);

	// Use the tiled position for all subsequent calculations
	vec3 t_pos = local_pos + tile_offset;

	// Domain warping for organic, swirling veins
	vec3 q = vec3(fbm(t_pos + vec3(0.0, 0.0, 0.0)),
				  fbm(t_pos + vec3(5.2, 1.3, 2.8)),
				  fbm(t_pos + vec3(2.4, 9.2, 5.1)));
				  
	vec3 r = vec3(fbm(t_pos + distortion * q + vec3(1.7, 9.2, 2.4)),
				  fbm(t_pos + distortion * q + vec3(8.3, 2.8, 6.1)),
				  fbm(t_pos + distortion * q + vec3(3.9, 4.5, 8.2)));

	// Base FBM with warped coordinates
	float n = fbm(t_pos * vein_scale + distortion * r);
	
	// Create the marble veins using a sine wave
	float marble = abs(sin(t_pos.x * vein_scale + n * 10.0));
	
	// Sharpen the veins to make them thin and crisp
	marble = pow(marble, contrast);
	
	// Mix colors: 0 represents the dark vein, 1 represents the base white marble
	vec3 albedo = mix(vein_color, base_color, marble);
	
	ALBEDO = albedo;
	ROUGHNESS = roughness_base;
}