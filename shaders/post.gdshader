// Film look over the 3D view (but under the HUD): a soft vignette and faint
// colour fringing toward the edges, like a real lens. (No film grain: noise
// that changes every frame reads as jitter.)
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float ca = 0.0015 * dot(d, d) * 4.0;
	vec3 c;
	c.r = texture(screen, uv + d * ca).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - d * ca).b;
	float vig = smoothstep(0.95, 0.3, length(d * vec2(1.0, 1.15)));
	COLOR = vec4(c * mix(0.78, 1.0, vig), 1.0);
}
