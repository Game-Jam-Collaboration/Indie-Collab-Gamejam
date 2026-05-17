shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;

uniform vec3 base_color : source_color = vec3(0.55, 1.0, 0.55);
uniform vec3 anomaly_color : source_color = vec3(1.0, 0.18, 0.15);
uniform float emission_energy : hint_range(0.0, 10.0) = 3.0;
uniform float miss_brightness : hint_range(0.0, 1.0) = 0.083;
uniform float miss_trail_duration = 1.0;
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
uniform float glitch_burst : hint_range(0.0, 1.0) = 0.0;

uniform float front_fade_min : hint_range(0.0, 1.0) = 0.0;
uniform float clip_min_local_y = -1.0e9;
uniform float anomaly_flash_speed = 4.0;
uniform float anomaly_alpha : hint_range(0.0, 1.0) = 0.4;
uniform float recording_progress : hint_range(0.0, 1.0) = 0.0;

varying float v_life;
varying float v_seed;
varying float v_local_y;
varying float v_arrival;
varying float v_effective_age;
varying float v_is_hit;
varying float v_is_anomaly;
varying float v_is_full_object;
varying float v_is_recording;
varying float v_arrived;
varying float v_front_fade;

void vertex() {
	float spawn_time = INSTANCE_CUSTOM.r;
	v_seed = INSTANCE_CUSTOM.g;
	v_local_y = INSTANCE_CUSTOM.b;
	float raw_kind = INSTANCE_CUSTOM.a;
	float no_anim = step(9.5, raw_kind);
	float kind = raw_kind - no_anim * 10.0;
	v_is_anomaly = step(1.5, kind) - step(2.5, kind);
	v_is_full_object = step(1.5, kind);
	v_is_recording = step(3.5, kind) - step(4.5, kind);
	v_is_hit = step(0.5, kind);
	float age = current_time - spawn_time;
	float launch_delay = mix(v_seed * max_launch_delay, 0.0, no_anim);
	v_effective_age = age - launch_delay;

	vec3 final_world = MODEL_MATRIX[3].xyz;
	vec3 final_local = final_world - lidar_origin_world;
	float dist = length(final_local);
	float travel_time = dist / max(travel_speed, 0.0001);
	float g_anim = clamp(v_effective_age / max(travel_time, 0.0001), 0.0, 1.0);
	float g = mix(g_anim, 1.0, no_anim);

	float miss_visible_fraction = 1.0;
	float effective_lifetime_anim = mix(travel_time * miss_visible_fraction, lifetime, v_is_hit);
	float effective_lifetime = mix(effective_lifetime_anim, lifetime, no_anim);
	v_life = clamp(1.0 - v_effective_age / max(effective_lifetime, 0.0001), 0.0, 1.0);

	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_pos.xyz += (g - 1.0) * final_local;
	if (glitch_burst > 0.0) {
		float gseed = floor(current_time * 18.0) + v_seed * 1234.5;
		vec3 jitter = vec3(
			fract(sin(gseed * 12.9898) * 43758.5453) - 0.5,
			fract(sin(gseed * 78.233) * 23568.5453) - 0.5,
			fract(sin(gseed * 45.164) * 13568.5453) - 0.5
		);
		world_pos.xyz += jitter * glitch_burst * 0.18;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * world_pos;

	v_arrival = exp(-(v_effective_age - travel_time) * arrival_flash_decay);
	v_arrival = clamp(v_arrival, 0.0, 1.0) * step(travel_time, v_effective_age) * v_is_hit;
	v_arrival = mix(v_arrival, 0.0, no_anim);
	v_arrived = step(travel_time, v_effective_age) * v_is_hit;
	v_arrived = mix(v_arrived, v_is_hit, no_anim);

	vec3 to_cam = CAMERA_POSITION_WORLD - lidar_origin_world;
	float to_cam_len = max(length(to_cam), 0.0001);
	vec3 cam_dir = to_cam / to_cam_len;
	float radius_world = max(length(final_local), 0.0001);
	float front_t = clamp(dot(final_local, cam_dir) / radius_world, 0.0, 1.0);
	v_front_fade = mix(1.0, front_fade_min, front_t);
}

void fragment() {
	if (v_effective_age < 0.0 || v_life <= 0.0) {
		discard;
	}
	if (v_local_y < clip_min_local_y && v_is_full_object < 0.5) {
		discard;
	}

	float band_y = mod(current_time * scan_band_speed, 1.0) * scan_band_height - scan_band_height * 0.5;
	float dy = (v_local_y - band_y) / scan_band_width;
	float band_factor = exp(-dy * dy);

	float flicker = 1.0 - flicker_strength * (0.5 + 0.5 * sin(v_seed * 31.7 + current_time * flicker_speed));

	float glitch_seed = floor(current_time * glitch_rate) + v_seed * 100.0;
	float glitch = step(glitch_chance, fract(sin(glitch_seed * 12.9898) * 43758.5453));

	float alpha = mix(v_life * flicker * glitch * v_front_fade, anomaly_alpha * v_life, v_is_full_object);
	alpha *= mix(1.0, glitch * flicker, glitch_burst);
	float hit_mult = mix(miss_brightness, 1.0, v_is_hit);
	float intensity = emission_energy * hit_mult * (1.0 + band_factor * scan_band_strength + v_arrival * arrival_flash);

	float anomaly_flash = 0.08 + 0.08 * sin(current_time * anomaly_flash_speed);
	vec3 anomaly_render_color = mix(anomaly_color, vec3(1.0), anomaly_flash);
	vec3 transitioning_color = mix(anomaly_color, base_color, recording_progress);
	vec3 hit_color = mix(base_color, anomaly_render_color, v_is_anomaly);
	hit_color = mix(hit_color, transitioning_color, v_is_recording);
	if (glitch_burst > 0.0) {
		float color_jitter = fract(sin((floor(current_time * 12.0) + v_seed * 100.0) * 91.713) * 51234.123);
		hit_color = mix(hit_color, vec3(color_jitter, 1.0 - color_jitter, 0.5 + 0.5 * sin(current_time * 30.0)), glitch_burst);
	}
	float trail_fade = clamp(v_effective_age / max(miss_trail_duration, 0.0001), 0.0, 1.0);
	vec3 miss_color = mix(base_color, vec3(1.0), trail_fade);
	vec3 color = mix(miss_color, hit_color, v_arrived);
	ALBEDO = color * intensity;
	ALPHA = alpha;
}
