// A cloud puff seen from above: a soft round blob broken up by noise, lit
// from the upper left. Many overlapping puffs make one cloud bank.
// COLOR.a (set per puff) fades puffs that bullets have chewed into.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex;
uniform float opacity = 0.92;
uniform vec3 tint : source_color = vec3(1.0);   // black for the shadow layer on the sea
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d) * 2.0;
	float n = texture(noise_tex, wpos.xz * 0.11 + UV * 0.35).r;
	float a = 1.0 - smoothstep(0.25, 1.0, r + (n - 0.5) * 0.7);
	float lit = 0.86 + 0.22 * dot(d, vec2(-0.6, -0.8)) * 2.0 + (n - 0.5) * 0.25;
	ALBEDO = vec3(0.97, 0.98, 1.0) * lit * tint;
	ALPHA = a * COLOR.a * opacity;
}
