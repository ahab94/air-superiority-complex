// Painted metal for the jets: a base coat, optional two-tone camo, panel
// lines, a bit of grime, and a parody roundel on each wing.
// Patterns use the model's own coordinates, so they stick to the jet.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.6);
uniform vec3 camo_color : source_color = vec3(0.4);
uniform float camo_amount = 0.0;
uniform vec3 insignia_color : source_color = vec3(0.8, 0.1, 0.1);
uniform sampler2D noise_tex;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float n = texture(noise_tex, lpos.xz * 0.32 + vec2(0.5)).r;
	vec3 col = mix(base_color, camo_color, smoothstep(0.5, 0.56, n) * camo_amount);
	// Panel lines: thin dark seams every so often along the length and span.
	float sz = 0.5 - abs(fract(lpos.z * 1.7) - 0.5);
	float sx = 0.5 - abs(fract(lpos.x * 2.1) - 0.5);
	float seam = min(smoothstep(0.0, 0.035, sz), mix(1.0, smoothstep(0.0, 0.03, sx), step(0.3, abs(lpos.x))));
	col *= mix(0.62, 1.0, seam);
	// Roundel on top of each wing: insignia disc with a white ring.
	float d = distance(vec2(abs(lpos.x), lpos.z), vec2(1.0, 0.62));
	if (lpos.y > -0.01 && abs(lpos.x) > 0.6) {
		col = mix(col, vec3(0.92), 1.0 - smoothstep(0.17, 0.185, d));
		col = mix(col, insignia_color, 1.0 - smoothstep(0.11, 0.125, d));
	}
	float grime = texture(noise_tex, lpos.xz * 1.9 + vec2(0.3, 0.7)).r;
	ALBEDO = col * mix(0.82, 1.06, grime);
	METALLIC = 0.35;
	ROUGHNESS = 0.5 + grime * 0.2;
	// The mesh is built without caring which way each triangle winds, so make
	// every normal face the camera: on a closed shape, the side you can see
	// is always the outside.
	if (dot(NORMAL, VIEW) < 0.0) {
		NORMAL = -NORMAL;
	}
}
