// Afterburner: an additive, flickering cone that fades from white-hot at the
// nozzle to orange at the tip. Values above 1 make the bloom (glow) kick in.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float length = 1.0;
uniform float power = 1.0;
varying float along;

void vertex() {
	along = clamp(0.5 + VERTEX.y / length, 0.0, 1.0);
	float wobble = 1.0 + 0.18 * sin(TIME * 63.0 + VERTEX.y * 9.0);
	VERTEX.xz *= wobble;
}

void fragment() {
	float flick = 0.8 + 0.2 * sin(TIME * 47.0) * sin(TIME * 29.0 + 1.3);
	vec3 hot = vec3(3.6, 3.0, 2.4);
	vec3 cool = vec3(2.6, 0.9, 0.2);
	ALBEDO = mix(hot, cool, along) * (1.0 - along) * flick * power;
}
