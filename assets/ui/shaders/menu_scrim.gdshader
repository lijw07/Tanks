shader_type canvas_item;
render_mode unshaded;

void fragment() {
	float left_shade = mix(0.77, 0.04, smoothstep(0.0, 0.80, UV.x));
	float lower_shade = 0.42 * smoothstep(0.48, 1.0, UV.y);
	float edge = pow(length((UV - vec2(0.5)) * vec2(1.1, 0.8)), 2.0) * 0.35;
	COLOR = vec4(0.025, 0.040, 0.046, clamp(left_shade + lower_shade + edge, 0.0, 0.88));
}
