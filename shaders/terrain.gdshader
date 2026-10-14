// The ground far below, for every mission that isn't over open ocean.
// One shader, several landscapes ("biome"), all made from noise:
//   1 steppe     farmland patchwork, forests, a winding river, villages
//   2 winter     snow, dark pine forest, hills, a frozen river (river_x)
//   3 desert     dunes with ripples, red mesas, dark canyon cracks
//   4 arctic     black water full of drifting ice floes
//   5 plains     a grid of irrigated fields and canals, villages, roads
//   6 jungle     dense rainforest canopy and a muddy river delta
//   7 mountains  real height: rock ridges, snowfields, green valleys
// `scroll` slides the land toward the bottom of the screen as we fly.
// The mesh is raised by height_amp, so mountains stand up toward the camera
// and move with real parallax. At night, `lights` scatters town lights.
shader_type spatial;

uniform int biome = 1;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scroll = 0.0;
uniform float height_amp = 0.0;
uniform float river_x = -9999.0;
uniform float lights = 0.0;
uniform float wetness = 0.0;     // rain darkens and glosses the ground

varying vec2 wuv;
varying float hgt;
varying vec3 wn;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float height_at(vec2 p) {
	float h = texture(noise_tex, p * 0.005).r * 0.65 + texture(noise_tex, p * 0.017 + 0.3).r * 0.28
		+ texture(detail_tex, p * 0.06).r * 0.07;
	if (biome == 7) {
		// Ridged noise: sharp crests, wide valleys.
		float r = 1.0 - abs(texture(noise_tex, p * 0.008 + 0.7).r * 2.0 - 1.0);
		h = mix(h, r * r, 0.6);
	}
	return h;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wuv = w.xz - vec2(0.0, scroll);
	hgt = height_at(wuv);
	wn = vec3(0.0, 1.0, 0.0);
	if (height_amp > 0.0) {
		VERTEX.y += (hgt - 0.45) * height_amp;
		float e = 0.6;
		float hx = height_at(wuv + vec2(e, 0.0)) - height_at(wuv - vec2(e, 0.0));
		float hz = height_at(wuv + vec2(0.0, e)) - height_at(wuv - vec2(0.0, e));
		NORMAL = normalize(vec3(-hx * height_amp, 2.0 * e, -hz * height_amp));
		wn = NORMAL;
	}
}

// An anti-aliased line: 1 where |d| < w, fading out over about one pixel,
// and never thinner than ~1.5 pixels. fwidth() tells how much d changes from
// one pixel to the next, so the edge is always exactly one pixel soft. Thin
// lines drawn without this "crawl" and flicker as the land scrolls.
float band(float d, float w) {
	float fw = max(fwidth(d), 1e-5);
	float ww = max(w, fw * 1.5);
	return 1.0 - smoothstep(ww - fw, ww + fw, abs(d));
}

// A winding river: where a slow noise crosses its midpoint.
float river(vec2 p, float width) {
	float n = texture(noise_tex, p * vec2(0.004, 0.0015) + vec2(0.31, 0.0)).r;
	return band(n - 0.5, width * 0.75);
}

// Villages: a few per area, each a cluster of small soft-edged roofs.
// `glow` gets small warm points (windows, street lamps) for night.
float settlements(vec2 p, out float roofs, out float glow) {
	vec2 cell = floor(p / 22.0);
	float town = step(0.82, hash(cell));
	vec2 c = (cell + 0.5) * 22.0 + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 8.0;
	float d = length(p - c);
	float area = town * (1.0 - smoothstep(2.5, 6.0, d));
	// Features are kept several pixels wide, with soft edges, so they don't
	// flicker as the ground scrolls.
	vec2 q = p * 0.9;
	vec2 b = floor(q);
	vec2 f = fract(q) - 0.5;
	// Each house gets its own size and offset, so a village isn't a grid.
	vec2 jitter = (vec2(hash(b + 2.3), hash(b + 8.9)) - 0.5) * 0.3;
	float size = 0.16 + hash(b + 4.4) * 0.2;
	vec2 g = abs(f - jitter);
	float house = step(0.45, hash(b)) * (1.0 - smoothstep(size, size + 0.12, max(g.x, g.y * (0.7 + hash(b + 1.7) * 0.6))));
	roofs = area * house;
	vec2 lq = p * 0.6;
	float lamp = step(0.72, hash(floor(lq) + 9.0)) * (1.0 - smoothstep(0.0, 0.3, length(fract(lq) - 0.5)));
	glow = (area * 1.2 + town * (1.0 - smoothstep(6.0, 9.0, d)) * 0.3) * lamp;
	return area;
}

void fragment() {
	vec2 p = wuv;
	float n1 = texture(noise_tex, p * 0.012).r;
	float n2 = texture(noise_tex, p * 0.045 + 0.5).r;
	float grain = texture(detail_tex, p * 0.2).r;
	vec3 col = vec3(0.3);
	float rough = 0.9;
	float emit = 0.0;
	float roofs = 0.0;

	if (biome == 1) {           // steppe
		vec2 warp = vec2(n1, n2) * 6.0;
		vec2 cell = floor((p + warp) * vec2(0.09, 0.06));
		float h = hash(cell);
		vec3 crops[5] = vec3[](vec3(0.33, 0.38, 0.15), vec3(0.48, 0.45, 0.22), vec3(0.24, 0.32, 0.12), vec3(0.55, 0.5, 0.3), vec3(0.4, 0.42, 0.2));
		col = crops[int(h * 4.99)];
		vec2 f = fract((p + warp) * vec2(0.09, 0.06));
		col *= 1.0 - 0.25 * band(min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)), 0.015);
		float forest = smoothstep(0.6, 0.7, n2);
		float trees = texture(detail_tex, p * 0.7).r;
		col = mix(col, mix(vec3(0.1, 0.18, 0.08), vec3(0.2, 0.3, 0.13), trees), forest);
		float r = river(p, 0.012);
		col = mix(col, vec3(0.12, 0.2, 0.24), r);
		rough = mix(rough, 0.15, r);
		float glow;
		settlements(p, roofs, glow);
		col = mix(col, vec3(0.62, 0.5, 0.44), roofs);
		emit = glow * lights;
	} else if (biome == 2) {    // winter
		col = mix(vec3(0.88, 0.9, 0.95), vec3(0.74, 0.79, 0.86), n1);
		// Pine forest: scattered dark tree tops, denser in the middle of a wood.
		float wood = smoothstep(0.5, 0.68, n2);
		vec2 tq = p * 1.1;
		vec2 tc = floor(tq);
		vec2 to = vec2(hash(tc + 1.3), hash(tc + 5.1)) * 0.4 + 0.3;
		float tree = step(1.0 - wood * 0.85, hash(tc)) * (1.0 - smoothstep(0.1, 0.32, length(fract(tq) - to)));
		col = mix(col, vec3(0.1, 0.16, 0.13), tree * 0.92);
		col = mix(col, col * vec3(0.86, 0.9, 0.96), tree);   // blue snow shade beside trees
		col *= 0.88 + hgt * 0.25;
		if (river_x > -9000.0) {
			float d = abs(p.x - river_x + (texture(noise_tex, vec2(0.2, p.y * 0.01)).r - 0.5) * 6.0);
			float ice = 1.0 - smoothstep(2.6, 3.4, d);
			float crack = smoothstep(0.8, 0.86, texture(detail_tex, p * 0.15).r);
			col = mix(col, mix(vec3(0.62, 0.72, 0.8), vec3(0.3, 0.4, 0.48), crack), ice);
			rough = mix(rough, 0.25, ice);
			// The far bank (the sanctuary) is a touch darker and greyer.
			col *= p.x < river_x ? 0.82 : 1.0;
		}
	} else if (biome == 3) {    // desert
		vec2 dir = normalize(vec2(1.0, 0.35));
		float dune = sin(dot(p, dir) * 0.55 + n1 * 9.0) * 0.5 + 0.5;
		float ripple = sin(dot(p, dir) * 1.6 + n2 * 4.0) * 0.5 + 0.5;
		col = mix(vec3(0.84, 0.74, 0.56), vec3(0.72, 0.6, 0.43), dune);
		col *= 0.93 + ripple * 0.07;
		float mesa = smoothstep(0.64, 0.68, hgt);
		col = mix(col, mix(vec3(0.6, 0.42, 0.3), vec3(0.7, 0.52, 0.38), grain), mesa);
		col *= 1.0 - smoothstep(0.62, 0.66, hgt) * (1.0 - mesa) * 0.35;   // cliff edges
		float canyon = band(texture(noise_tex, p * 0.006 + 0.9).r - 0.5, 0.008);
		col = mix(col, vec3(0.3, 0.2, 0.15), canyon);
		float glow;
		settlements(p, roofs, glow);
		col = mix(col, vec3(0.86, 0.8, 0.68), roofs * 0.7);
		emit = glow * lights;
	} else if (biome == 4) {    // arctic
		// Big floes with soft snowy edges, open leads of black water, brash ice.
		float field = texture(noise_tex, p * 0.008).r * 0.7 + texture(noise_tex, p * 0.03 + 0.2).r * 0.3;
		float floe = smoothstep(0.47, 0.49, field);
		float lead = band(texture(noise_tex, p * 0.01 + 0.5).r - 0.5, 0.007);
		floe *= 1.0 - lead;
		float ridge = smoothstep(0.7, 0.8, texture(detail_tex, p * 0.2).r);
		vec3 ice = mix(vec3(0.86, 0.9, 0.95), vec3(0.7, 0.78, 0.86), ridge * 0.6) * (0.92 + grain * 0.1);
		float brash = smoothstep(0.76, 0.82, texture(detail_tex, p * 0.35).r) * (1.0 - floe) * smoothstep(0.42, 0.47, field);
		col = mix(vec3(0.02, 0.06, 0.09), ice, max(floe, brash * 0.8));
		rough = mix(0.08, 0.7, floe);
	} else if (biome == 5) {    // plains
		// Small fields of uneven sizes (a warped grid), each a different crop.
		vec2 q = p + vec2(n1 - 0.5, n2 - 0.5) * 1.6;
		vec2 scale = vec2(0.22, 0.15) * (0.8 + 0.4 * texture(noise_tex, floor(q * 0.05) * 0.1).r);
		vec2 cell = floor(q * scale);
		float h = hash(cell);
		vec3 crops[5] = vec3[](vec3(0.36, 0.42, 0.18), vec3(0.58, 0.54, 0.32), vec3(0.28, 0.36, 0.16), vec3(0.52, 0.45, 0.3), vec3(0.44, 0.48, 0.24));
		col = crops[int(h * 4.99)];
		vec2 f = fract(q * scale);
		float rows = sin((h > 0.5 ? p.x : p.y) * 1.8) * 0.5 + 0.5;
		col *= 0.92 + rows * 0.08;
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		col = mix(col, vec3(0.42, 0.38, 0.3), band(edge, 0.02));
		float canal = band(fract(p.x * 0.011) - 0.5, 0.012) * step(0.4, hash(vec2(floor(p.x * 0.011), 3.0)));
		col = mix(col, vec3(0.1, 0.2, 0.24), canal);
		rough = mix(rough, 0.15, canal);
		float road = band(fract(p.y * 0.0045 + n1 * 0.3) - 0.5, 0.005);
		col = mix(col, vec3(0.5, 0.48, 0.44), road * 0.8);
		float glow;
		settlements(p, roofs, glow);
		col = mix(col, vec3(0.64, 0.52, 0.45), roofs);
		emit = glow * lights;
	} else if (biome == 6) {    // jungle
		// Canopy: overlapping tree crowns at two sizes give a bumpy, living top.
		float crowns = texture(detail_tex, p * 0.35).r * 0.65 + texture(detail_tex, p * 0.8 + 0.4).r * 0.35;
		col = mix(vec3(0.05, 0.16, 0.05), vec3(0.2, 0.36, 0.12), crowns);
		col = mix(col, vec3(0.28, 0.38, 0.14), step(0.82, crowns) * 0.6);
		col = mix(col, vec3(0.03, 0.12, 0.05), smoothstep(0.55, 0.7, n2));
		float r = max(river(p, 0.03), river(p * 1.7 + 40.0, 0.015));
		col = mix(col, vec3(0.28, 0.24, 0.14), r);
		rough = mix(rough, 0.1, r);
		float paddy = smoothstep(0.35, 0.4, river(p, 0.09)) * (1.0 - r);
		vec2 f = fract(p * 0.15);
		col = mix(col, mix(vec3(0.3, 0.42, 0.18), vec3(0.2, 0.3, 0.2), step(0.5, f.x)), paddy * 0.7);
	} else if (biome == 7) {    // mountains
		float slope = 1.0 - clamp(wn.y * 1.3 - 0.2, 0.0, 1.0);
		vec3 valley = mix(vec3(0.24, 0.3, 0.16), vec3(0.36, 0.33, 0.22), n2);
		vec3 rock = mix(vec3(0.36, 0.33, 0.31), vec3(0.24, 0.22, 0.21), grain);
		col = mix(valley, rock, smoothstep(0.35, 0.55, hgt));
		float snow = smoothstep(0.66, 0.72, hgt + grain * 0.05);
		col = mix(col, vec3(0.92, 0.94, 0.97), snow * (1.0 - slope * 0.7));
	}

	// Cloud shadows drift over everything.
	float cs = texture(noise_tex, p * 0.0045 + vec2(TIME * 0.0025, TIME * 0.001)).r;
	float shade = mix(1.0, 0.65, smoothstep(0.55, 0.7, cs));
	col *= mix(0.88, 1.08, grain);
	col = mix(col, col * 0.7, wetness);
	ALBEDO = pow(col, vec3(2.2)) * shade;     // palette is sRGB; lighting is linear
	ROUGHNESS = mix(rough, rough * 0.4, wetness);
	SPECULAR = 0.3;
	EMISSION = vec3(1.0, 0.7, 0.35) * emit * 3.0;
}
