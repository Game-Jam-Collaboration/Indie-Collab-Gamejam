shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.08, 0.95, 0.18);
uniform float emission_energy : hint_range(0.0, 10.0) = 1.6;
uniform float current_time = 0.0;

uniform float scan_band_speed = 0.4;
uniform float scan_band_width = 0.3;
uniform float scan_band_strength = 2.5;
uniform float scan_band_axis_scale = 0.08;

uniform float flicker_strength = 0.35;
uniform float flicker_speed = 14.0;

uniform float glitch_chance = 0.04;
uniform float glitch_rate = 8.0;

varying vec3 v_local_pos;

void vertex() {
	v_local_pos = VERTEX;
}

void fragment() {
	float band_phase = mod(current_time * scan_band_speed, 1.0) * 2.0 - 1.0;
	float local_y_norm = v_local_pos.y / max(scan_band_axis_scale, 0.0001);
	float dy = (local_y_norm - band_phase) / max(scan_band_width, 0.0001);
	float band_factor = exp(-dy * dy);

	float seed = fract(sin(dot(v_local_pos, vec3(12.9898, 78.233, 37.719))) * 43758.5453);

	float flicker = 1.0 - flicker_strength * (0.5 + 0.5 * sin(seed * 31.7 + current_time * flicker_speed));

	float glitch_seed = floor(current_time * glitch_rate) + seed * 100.0;
	float glitch = step(glitch_chance, fract(sin(glitch_seed * 12.9898) * 43758.5453));

	float intensity = emission_energy * (1.0 + band_factor * scan_band_strength);
	float alpha = flicker * glitch;

	ALBEDO = base_color * intensity;
	ALPHA = alpha;
}
