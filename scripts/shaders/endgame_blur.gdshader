shader_type canvas_item;
render_mode blend_mix;

// Cross-pattern box blur with 5 taps + 2 extra taps for chromatic aberration.
// Everything else is pure math, so the worst case is <10 texture samples and
// stays cheap on web / integrated GPUs.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_amount : hint_range(0.0, 24.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.0) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 24.0) = 0.0;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.0;
uniform float red_shift : hint_range(0.0, 1.0) = 0.0;
uniform float heartbeat_strength : hint_range(0.0, 1.0) = 0.0;
uniform float heartbeat_rate : hint_range(0.1, 6.0) = 1.6;
uniform float invert_strength : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_zoom : hint_range(0.0, 0.2) = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 vignette_color : source_color = vec3(0.0, 0.0, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Heartbeat phase reused for several effects below.
	float beat_sin = sin(TIME * heartbeat_rate * 6.28318);
	float beat = 0.5 + 0.5 * beat_sin;

	// Heartbeat-driven radial pull: pixels squeeze toward center on each beat.
	// Single mul per pixel, no extra samples — adjusts where we sample blur from.
	vec2 sample_uv = SCREEN_UV;
	if (pulse_zoom > 0.0001) {
		vec2 from_center = SCREEN_UV - vec2(0.5);
		sample_uv -= from_center * pulse_zoom * beat;
	}

	vec2 px = SCREEN_PIXEL_SIZE * blur_amount;
	vec4 col = texture(screen_tex, sample_uv);
	col += texture(screen_tex, sample_uv + vec2(px.x, 0.0));
	col += texture(screen_tex, sample_uv + vec2(-px.x, 0.0));
	col += texture(screen_tex, sample_uv + vec2(0.0, px.y));
	col += texture(screen_tex, sample_uv + vec2(0.0, -px.y));
	col *= 0.2;

	if (chromatic_aberration > 0.001) {
		vec2 dir = (sample_uv - vec2(0.5)) * SCREEN_PIXEL_SIZE * chromatic_aberration;
		col.r = texture(screen_tex, sample_uv + dir).r;
		col.b = texture(screen_tex, sample_uv - dir).b;
	}

	float beat_boost = 1.0 + heartbeat_strength * beat * 0.6;

	// Slow shift toward a desaturated red tint — sick / wounded feel.
	if (red_shift > 0.001) {
		float luma = dot(col.rgb, vec3(0.299, 0.587, 0.114));
		vec3 reddish = vec3(luma * 1.25, luma * 0.55, luma * 0.5);
		col.rgb = mix(col.rgb, reddish, red_shift);
	}

	// Brief inverted-color flashes — fires on a hash that re-rolls every ~0.12s
	// so it stays well below strobe territory but still catches the eye late in
	// the ramp.
	if (invert_strength > 0.001) {
		float flash_seed = floor(TIME * 8.0);
		float flash = step(0.92, hash(vec2(flash_seed, flash_seed * 0.37)));
		col.rgb = mix(col.rgb, 1.0 - col.rgb, flash * invert_strength);
	}

	// Brightness wash toward tint.
	col.rgb = mix(col.rgb, tint, brightness);

	// Vignette with heartbeat-driven pulse.
	float d = distance(SCREEN_UV, vec2(0.5));
	float vig = smoothstep(0.32, 0.85, d) * vignette_strength * beat_boost;
	col.rgb = mix(col.rgb, vignette_color, clamp(vig, 0.0, 1.0));

	// Rolling scanline interference — slow vertical drift so it reads as
	// analog signal degradation rather than a static overlay.
	if (scanline_strength > 0.001) {
		float band = sin(SCREEN_UV.y * 620.0 + TIME * 18.0) * 0.5 + 0.5;
		col.rgb *= mix(1.0, 1.0 - band * 0.55, scanline_strength);
	}

	// Grain.
	if (grain_strength > 0.001) {
		float n = hash(SCREEN_UV * 1234.0 + vec2(floor(TIME * 30.0)));
		col.rgb += vec3(n - 0.5) * grain_strength;
	}

	COLOR = vec4(col.rgb, 1.0);
}
