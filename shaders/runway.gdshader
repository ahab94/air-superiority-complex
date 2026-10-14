// Asphalt runway with a dashed centreline, threshold bars and edge lines.
// UV.y runs along the runway (0 = far end, 1 = near end).
shader_type spatial;

uniform sampler2D noise_tex;

void fragment() {
	vec2 uv = UV;
	vec3 col = vec3(0.17, 0.17, 0.18) * mix(0.85, 1.1, texture(noise_tex, uv * vec2(3.0, 8.0)).r);
	float paint = 0.0;
	paint += step(abs(uv.x - 0.5), 0.012) * step(0.5, fract(uv.y * 9.0)) * step(0.12, uv.y) * step(uv.y, 0.88);
	paint += step(abs(uv.x - 0.5), 0.44) * step(0.42, abs(uv.x - 0.5)) ;
	float bars = step(0.5, fract(uv.x * 12.0)) * step(abs(uv.x - 0.5), 0.36);
	paint += bars * (step(uv.y, 0.07) + step(0.93, uv.y));
	ALBEDO = pow(mix(col, vec3(0.85), clamp(paint, 0.0, 1.0)), vec3(2.2));   // sRGB -> linear
	ROUGHNESS = 0.8;
}
