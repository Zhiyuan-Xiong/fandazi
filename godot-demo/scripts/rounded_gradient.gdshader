shader_type canvas_item;
uniform vec2 rect_size = vec2(393.0, 852.0);
uniform vec4 radii = vec4(0.0);
void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	float r = p.y < 0.0 ? (p.x < 0.0 ? radii.x : radii.y) : (p.x < 0.0 ? radii.w : radii.z);
	r = min(r, min(rect_size.x, rect_size.y) * 0.5);
	vec2 q = abs(p) - rect_size * 0.5 + vec2(r);
	float distance = min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - smoothstep(-0.65, 0.65, distance);
}
