shader_type canvas_item;
render_mode blend_mix;

// Procedural red vignette — zero texture samples, just smoothstep + distance.
// Driven by `intensity` from the suffocation state machine.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 vignette_color : source_color = vec3(0.85, 0.05, 0.05);
uniform float inner_radius : hint_range(0.0, 1.0) = 0.22;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.75;

void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(inner_radius, outer_radius, d);
	COLOR = vec4(vignette_color, v * intensity);
}
