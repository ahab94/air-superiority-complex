// The sea far below. Layers, from big to small:
//   swell (broad slow undulation), two wave normal maps, wind-streaked foam,
//   cloud shadows drifting over it, and sun glitter that twinkles.
// `scroll` is how far we've flown; it slides everything toward the bottom
// of the screen so the sea always rushes past.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.015, 0.07, 0.12);
uniform vec3 shallow : source_color = vec3(0.04, 0.17, 0.22);
uniform sampler2D wave_a : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D wave_b : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D foam_tex : filter_linear_mipmap_anisotropic;
uniform float scroll = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cloud_shadow(vec2 uv) {
	float c = texture(foam_tex, uv * 0.0045 + vec2(TIME * 0.0025, TIME * 0.001)).r;
	return mix(1.0, 0.72, smoothstep(0.55, 0.7, c));
}

void fragment() {
	vec2 uv = wpos.xz - vec2(0.0, scroll);
	vec3 swell = texture(wave_a, uv * 0.009 + vec2(TIME * 0.002, TIME * 0.003)).rgb;
	vec3 na = texture(wave_a, uv * 0.035 + vec2(TIME * 0.006, 0.0)).rgb;
	vec3 nb = texture(wave_b, uv * 0.09 + vec2(-TIME * 0.011, TIME * 0.004)).rgb;
	NORMAL_MAP = normalize(swell * 0.4 + na * 0.35 + nb * 0.35);
	NORMAL_MAP_DEPTH = 2.4;
	// Whitecaps, stretched along the wind and gated by gusts.
	float f = texture(foam_tex, uv * vec2(0.28, 0.12) + vec2(0.0, TIME * 0.01)).r;
	float gust = texture(foam_tex, uv * 0.02 + vec2(TIME * 0.004, 0.0)).r;
	float foam = smoothstep(0.8, 0.86, f) * smoothstep(0.62, 0.78, gust) * 0.5;
	float tint = texture(foam_tex, uv * 0.008).r;
	float shade = cloud_shadow(uv);
	vec3 water = mix(deep, shallow, tint * 0.8 + swell.r * 0.25);
	// Wave texture you can see from above: crests a touch lighter, troughs darker.
	float crest = (na.r + na.g - 1.0) * 0.6 + (nb.r - 0.5) * 0.5;
	water *= 0.85 + crest * 0.5;
	ALBEDO = mix(water, vec3(0.8, 0.85, 0.88), foam) * shade;
	ROUGHNESS = 0.06 + foam * 0.7;
	SPECULAR = 0.35 * shade;
	// Glitter: tiny bright points that flicker where the sun catches a wave.
	float g = texture(foam_tex, uv * 0.9 + vec2(TIME * 0.07, -TIME * 0.05)).r;
	float g2 = texture(foam_tex, uv * 1.3 + vec2(-TIME * 0.06, TIME * 0.08)).r;
	EMISSION = vec3(1.0, 0.95, 0.85) * pow(g * g2, 14.0) * 60.0 * smoothstep(0.75, 1.0, shade);
}
