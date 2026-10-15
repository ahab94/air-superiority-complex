// Stealth camo: the jet bends whatever is behind it, like heat-haze glass,
// with only a faint shimmering outline and a ripple of scanlines to give it
// away. Used for fighters hidden by an AWACS and for the phantom ace.
// It reads the already-drawn screen (hint_screen_texture) and offsets the
// lookup by the surface's normal, which is what makes it look refractive.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 edge_col : source_color = vec3(0.65, 0.9, 1.0);
uniform float edge = 1.0;      // outline strength

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec2 wobble = vec2(sin(TIME * 3.1 + lpos.z * 7.0), cos(TIME * 2.3 + lpos.x * 6.0)) * 0.004;
	vec2 bend = NORMAL.xy * 0.025;
	vec3 behind = textureLod(screen_tex, SCREEN_UV + bend + wobble, 1.0).rgb;
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	float scan = smoothstep(0.93, 1.0, sin(lpos.z * 14.0 - TIME * 7.0) * 0.5 + 0.5);
	ALBEDO = behind * 0.97 + edge_col * (rim * 0.55 + scan * 0.12) * edge;
}
