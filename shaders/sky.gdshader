shader_type sky;
// A clear night over the West: deep blue going to a pale haze at the horizon, a great many stars
// (a few bright, most faint, all twinkling a little), the Milky Way across them, and a moon.

uniform vec3 top : source_color = vec3(0.01, 0.015, 0.06);
uniform vec3 low : source_color = vec3(0.1, 0.14, 0.26);
// (low over the horizon ahead, where the camera's picture of the sky always reaches)
uniform vec3 moon_dir = vec3(0.3, 0.17, -0.94);
uniform sampler2D moon_map : source_color, filter_linear_mipmap;
// Real constellations' stars (see scripts/constellations.gd): a direction and a brightness each
uniform vec4 named[64];
// 1 = out in space (the start of a run): stars all the way round, no haze
uniform float space = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// One layer of stars on a grid of `cells` across the sky: each cell holds at most one
float stars(vec3 d, float cells, float chance, float size) {
	vec2 uv = vec2(atan(d.x, d.z) / 6.2832 + 0.5, d.y * 0.5 + 0.5) * vec2(cells * 2.0, cells);
	vec2 cell = floor(uv);
	float h = hash(cell);
	if (h > chance) return 0.0;
	vec2 at = vec2(hash(cell + 7.0), hash(cell + 13.0)) * 0.6 + 0.2;
	float dist = length(fract(uv) - at);
	float twinkle = 0.75 + 0.25 * sin(TIME * (1.5 + h * 9.0) + h * 40.0);
	return smoothstep(size, 0.0, dist) * twinkle * (0.5 + 0.5 * hash(cell + 3.0));
}

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -0.2, 1.0);
	vec3 c = mix(mix(low, top, smoothstep(-0.05, 0.6, up)), top * 0.4, space);
	// (from a little under the true horizon up: the world curves away, and the sky the camera sees
	// over it is that low)
	float above = mix(smoothstep(-0.5, -0.25, up), 1.0, space);
	// The Milky Way: a soft band across the sky, mottled
	vec3 band_axis = normalize(vec3(0.5, 0.35, 0.8));
	float band = exp(-pow(dot(d, band_axis) * 4.0, 2.0));
	float mottle = noise(vec2(atan(d.x, d.z), d.y) * 9.0) * 0.6 + noise(vec2(atan(d.x, d.z), d.y) * 23.0) * 0.4;
	c += vec3(0.12, 0.13, 0.2) * band * mottle * above;
	float s = stars(d, 90.0, 0.08, 0.16) * 1.4 + stars(d, 180.0, 0.12, 0.2) * 0.8 + stars(d, 300.0, 0.25 + band * 0.4, 0.22) * 0.5;
	c += vec3(0.95, 0.97, 1.0) * s * above;
	// the constellations' stars, brighter and a little bigger than the rest, each with a glow: only
	// in the night sky over the world (not out in space), and the costly part only near a star
	if (space < 0.5 && above > 0.0) {
		for (int i = 0; i < 64; i++) {
			vec4 st = named[i];
			// (the stars are packed first: the first empty one is the end of them)
			if (st.w <= 0.0) break;
			float t2 = 2.0 * (1.0 - dot(d, st.xyz));
			float r = 0.0045 * (0.6 + st.w);
			float rr = r * r;
			if (t2 > rr * 30.0) continue;
			float twinkle = 0.85 + 0.15 * sin(TIME * (2.0 + float(i) * 0.37) + float(i));
			c += vec3(0.95, 0.97, 1.0) * (smoothstep(rr, 0.0, t2) * 1.6 + exp(-t2 / (rr * 9.0)) * 0.35) * st.w * twinkle * above;
		}
	}
	float m = dot(d, normalize(moon_dir));
	// the moon: NASA's map of it (textures/moon_lroc.jpg, LRO, public domain) wrapped on a ball
	// facing us, the near side to us, a little gibbous, darker toward its edge; and a glow round it
	if (m > 0.9988) {
		vec3 md = normalize(moon_dir);
		vec3 side = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
		vec3 rise = cross(side, md);
		vec2 q = vec2(dot(d, side), dot(d, rise)) / 0.049;
		float r2 = dot(q, q);
		vec3 n = vec3(q.x, q.y, sqrt(max(1.0 - r2, 0.0)));
		vec2 uv = vec2(0.5 + atan(n.x, n.z) / 6.2832, 0.5 - asin(clamp(n.y, -1.0, 1.0)) / 3.1416);
		vec3 ground = texture(moon_map, uv).rgb;
		float lit = clamp(dot(n, normalize(vec3(0.55, 0.2, 0.8))) * 1.15 + 0.12, 0.05, 1.0);
		vec3 face = ground * 1.25 * lit * vec3(1.0, 0.98, 0.93);
		c = mix(c, face, smoothstep(0.9988, 0.9990, m));
	}
	c += vec3(0.25, 0.3, 0.4) * pow(max(m, 0.0), 80.0) * 0.5;
	COLOR = c;
}