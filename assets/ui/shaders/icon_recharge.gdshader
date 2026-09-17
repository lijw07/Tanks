shader_type canvas_item;
render_mode unshaded;

uniform float recharge : hint_range(0.0, 1.0) = 1.0;
uniform bool hovered = false;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float wave = sin(UV.x * 13.0 + TIME * 5.0) * 0.012;
	float boundary = 1.0 - recharge + wave;
	float filled = smoothstep(boundary - 0.015, boundary + 0.015, UV.y);
	if (recharge >= 1.0) { filled = 1.0; }
	if (recharge <= 0.0) { filled = 0.0; }
	vec3 ready_color = hovered ? vec3(1.0, 0.94, 0.72) : vec3(0.957, 0.796, 0.424);
	vec3 body = mix(vec3(0.31, 0.41, 0.48), ready_color, filled);
	float interior = smoothstep(0.2, 0.7, source.r);
	COLOR = vec4(mix(vec3(0.063, 0.129, 0.176), body, interior), source.a);
}
