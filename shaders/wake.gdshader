// A ship's wake on the sea: two foam arms in a V plus churned water down
// the middle, fading behind the stern. UV.y = 0 at the stern.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D noise_tex;
uniform float spread = 0.32;
uniform float strength = 0.55;

void fragment() {
	float y = UV.y;
	float x = (UV.x - 0.5) * 2.0;
	float arm_x = spread * y * 2.0 + 0.04;
	float arms = exp(-pow((abs(x) - arm_x) / (0.025 + 0.05 * y), 2.0));
	float centre = exp(-pow(x / (0.04 + 0.12 * y), 2.0));
	float n = texture(noise_tex, UV * vec2(2.0, 5.0) + vec2(0.0, -TIME * 0.15)).r;
	float a = (arms * 0.6 + centre * 0.9) * pow(1.0 - y, 1.5) * (0.5 + 0.9 * n);
	ALBEDO = vec3(0.85, 0.9, 0.95);
	ALPHA = clamp(a * strength, 0.0, 0.9);
}
