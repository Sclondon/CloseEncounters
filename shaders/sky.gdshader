shader_type sky;
// A clear night over the West: deep blue going to a pale haze at the horizon, a great many stars
// (a few bright, most faint, all twinkling a little), the Milky Way across them, and a moon.

uniform vec3 top : source_color = vec3(0.01, 0.015, 0.06);
uniform vec3 low : source_color = vec3(0.1, 0.14, 0.26);
uniform vec3 moon_dir = vec3(-0.4, 0.55, -0.73);
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
	float above = mix(smoothstep(0.0, 0.25, up), 1.0, space);
	// The Milky Way: a soft band across the sky, mottled
	vec3 band_axis = normalize(vec3(0.5, 0.35, 0.8));
	float band = exp(-pow(dot(d, band_axis) * 4.0, 2.0));
	float mottle = noise(vec2(atan(d.x, d.z), d.y) * 9.0) * 0.6 + noise(vec2(atan(d.x, d.z), d.y) * 23.0) * 0.4;
	c += vec3(0.12, 0.13, 0.2) * band * mottle * above;
	float s = stars(d, 90.0, 0.08, 0.16) * 1.4 + stars(d, 180.0, 0.12, 0.2) * 0.8 + stars(d, 300.0, 0.25 + band * 0.4, 0.22) * 0.5;
	c += vec3(0.95, 0.97, 1.0) * s * above;
	float m = dot(d, normalize(moon_dir));
	c += vec3(1.0, 0.97, 0.85) * smoothstep(0.9985, 0.999, m);
	c += vec3(0.25, 0.3, 0.4) * pow(max(m, 0.0), 60.0) * 0.4;
	COLOR = c;
}