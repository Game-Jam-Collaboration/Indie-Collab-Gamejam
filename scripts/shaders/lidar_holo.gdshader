shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.55, 1.0, 0.55);
uniform float emission_energy : hint_range(0.0, 10.0) = 3.0;
uniform float current_time = 0.0;
uniform float lifetime = 5.0;

uniform vec3 lidar_origin_world = vec3(0.0);
uniform float travel_speed = 3.0;
uniform float max_launch_delay = 0.5;
uniform float arrival_flash = 1.4;
uniform float arrival_flash_decay = 6.0;

uniform float scan_band_speed = 0.4;
uniform float scan_band_height = 1.0;
uniform float scan_band_width = 0.05;
uniform float scan_band_strength = 1.8;

uniform float flicker_strength = 0.35;
uniform float flicker_speed = 14.0;

uniform float glitch_chance = 0.04;
uniform float glitch_rate = 8.0;

varying float v_life;
varying float v_seed;
varying float v_local_y;
varying float v_arrival;
varying float v_effective_age;

void vertex() {
	float spawn_time = INSTANCE_CUSTOM.r;
	v_seed = INSTANCE_CUSTOM.g;
	v_local_y = INSTANCE_CUSTOM.b;
	float age = current_time - spawn_time;
	float launch_delay = v_seed * max_launch_delay;
	v_effective_age = age - launch_delay;
	v_life = clamp(1.0 - v_effective_age / lifetime, 0.0, 1.0);

	vec3 final_world = MODEL_MATRIX[3].xyz;
	vec3 final_local = final_world - lidar_origin_world;
	float dist = length(final_local);
	float travel_time = dist / max(travel_speed, 0.0001);
	float g = clamp(v_effective_age / max(travel_time, 0.0001), 0.0, 1.0);

	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_pos.xyz += (g - 1.0) * final_local;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * world_pos;

	v_arrival = exp(-(v_effective_age - travel_time) * arrival_flash_decay);
	v_arrival = clamp(v_arrival, 0.0, 1.0) * step(travel_time, v_effective_age);
}

void fragment() {
	if (v_effective_age < 0.0 || v_life <= 0.0) {
		discard;
	}

	float band_y = mod(current_time * scan_band_speed, 1.0) * scan_band_height - scan_band_height * 0.5;
	float dy = (v_local_y - band_y) / scan_band_width;
	float band_factor = exp(-dy * dy);

	float flicker = 1.0 - flicker_strength * (0.5 + 0.5 * sin(v_seed * 31.7 + current_time * flicker_speed));

	float glitch_seed = floor(current_time * glitch_rate) + v_seed * 100.0;
	float glitch = step(glitch_chance, fract(sin(glitch_seed * 12.9898) * 43758.5453));

	float alpha = v_life * flicker * glitch;
	float intensity = emission_energy * (1.0 + band_factor * scan_band_strength + v_arrival * arrival_flash);

	ALBEDO = base_color * intensity;
	ALPHA = alpha;
}
