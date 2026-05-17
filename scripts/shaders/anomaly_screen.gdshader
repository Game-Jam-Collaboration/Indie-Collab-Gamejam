shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D viewport_texture : filter_nearest;
uniform float detail_level : hint_range(0.0, 5.0) = 0.0;
uniform float max_detail_level = 5.0;
// Match the AudioSpectrum line color (Color.GREEN with energy 6).
uniform vec3 screen_on_color : source_color = vec3(0.0, 1.0, 0.0);
uniform float screen_emission_energy : hint_range(0.0, 12.0) = 6.0;

void fragment() {
	if (detail_level < 0.05) {
		// Off: fully transparent so the AudioModule screen shows through cleanly.
		ALPHA = 0.0;
	} else {
		// Flip horizontally so the back face of the quad reads the right way round.
		vec2 sample_uv = vec2(1.0 - UV.x, UV.y);
		vec4 sampled = texture(viewport_texture, sample_uv);
		float luma = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
		// Tint everything through the audio-spectrum green, brightness driven by luminance.
		vec3 tinted = screen_on_color * luma;
		ALBEDO = tinted * 0.3;
		EMISSION = tinted * screen_emission_energy;
		// Only the angel silhouette is opaque; empty viewport background stays transparent.
		ALPHA = clamp(sampled.a * max(luma * 4.0, 0.0), 0.0, 1.0);
	}
}
