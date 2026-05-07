shader_type canvas_item;

uniform vec4 color:source_color = vec4(0.4, 0.7, 0.15, 1);
uniform float radius: hint_range(0.02, 0.45) = 0.12;

void fragment() {
    if (distance(UV, vec2(0.5, 0.5)) > radius) {
        discard;
    }
	
	COLOR = color;
}