// Farmland seen from altitude: a patchwork of fields (cells of different
// crops), darker woods, and a sandy wavy coastline at the near edge (z = 0
// in the mesh's own coordinates; land extends toward -z).
shader_type spatial;

uniform sampler2D noise_tex;
varying vec3 lpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec2 p = lpos.xz;
	float warp = texture(noise_tex, p * 0.01).r;
	vec2 cell = floor(p * vec2(0.16, 0.11) + warp * 1.5);
	float h = hash(cell);
	vec3 crops[4] = vec3[](vec3(0.13, 0.21, 0.06), vec3(0.3, 0.32, 0.1), vec3(0.36, 0.27, 0.14), vec3(0.09, 0.17, 0.05));
	vec3 col = crops[int(h * 3.99)];
	// Hedgerows between fields.
	vec2 f = fract(p * vec2(0.16, 0.11) + warp * 1.5);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col = mix(vec3(0.1, 0.14, 0.06), col, smoothstep(0.0, 0.05, edge));
	// Woods.
	float w = texture(noise_tex, p * 0.03).r;
	col = mix(col, vec3(0.04, 0.08, 0.03), smoothstep(0.6, 0.66, w));
	// Coast: beach, then the land ends in a wavy line.
	float coast = -p.y + (texture(noise_tex, vec2(p.x * 0.02, 0.3)).r - 0.5) * 6.0;
	if (coast < 0.0) {
		discard;
	}
	col = mix(vec3(0.62, 0.56, 0.42), col, smoothstep(0.6, 2.2, coast));
	float grain = texture(noise_tex, p * 0.4).r;
	// The palette above is written as screen (sRGB) colours; lighting works
	// in linear light, so convert, or everything comes out pale.
	// Cloud shadows drift over the fields too.
	float cs = texture(noise_tex, p * 0.0045 + vec2(TIME * 0.0025, TIME * 0.001)).r;
	float shade = mix(1.0, 0.55, smoothstep(0.52, 0.68, cs));
	ALBEDO = pow(col * mix(0.85, 1.1, grain), vec3(2.2)) * shade;
	ROUGHNESS = 0.95;
}
