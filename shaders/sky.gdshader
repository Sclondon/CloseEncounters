shader_type sky;
// The night sky: NASA's map of the whole sky's stars and the Milky Way (the same everywhere, its
// brightest stars twinkling), over Earth the deep blue of the night and a haze at the horizon
// laid on it, and a moon.

uniform vec3 top : source_color = vec3(0.01, 0.015, 0.06);
uniform vec3 low : source_color = vec3(0.1, 0.14, 0.26);
// (low over the horizon ahead, where the camera's picture of the sky always reaches)
uniform vec3 moon_dir = vec3(0.3, 0.17, -0.94);
// How much of the moon shows (it comes up out of the dark on the way down to Earth)
uniform float moon_fade = 1.0;
uniform sampler2D moon_map : source_color, filter_linear_mipmap;
// The whole sky's stars (NASA's Deep Star Maps), and how bright they are drawn
uniform sampler2D star_map : source_color, filter_linear, repeat_enable;
uniform float star_gain = 1.4;
// The stars turned to stand over the world as wanted (the Big Dipper over the fields: see main.gd
// _hang_sky)
uniform mat3 sky_turn = mat3(1.0);
// The best-known bright stars drawn crisp over the map, for their figures to read (see main.gd
// BRIGHT_STARS): a direction in the map's own terms and how bright, each
uniform vec4 bright_stars[40];
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

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -0.2, 1.0);
	// The stars: NASA's map of the whole sky (textures/starmap_nasa.jpg, the Deep Star Maps, public
	// domain), the Milky Way and every real constellation in it, the same sky everywhere, from the
	// moon, in space and over Earth; the brightest of its stars twinkling
	vec3 e = sky_turn * d;
	vec2 uv = vec2(0.5 - atan(e.x, -e.z) / 6.2832, 0.5 - asin(clamp(e.y, -1.0, 1.0)) / 3.1416);
	// (darkened toward black between the stars: the map's faint glow of the whole sky taken down, its
	// stars and the Milky Way kept)
	vec3 field = pow(texture(star_map, uv).rgb, vec3(2.2)) * 2.6;
	float bright = max(field.r, max(field.g, field.b));
	float twinkle = 1.0 + smoothstep(0.35, 0.9, bright) * 0.45 * sin(TIME * (2.0 + hash(floor(uv * 2048.0)) * 7.0) + hash(floor(uv * 2048.0) + 3.0) * 40.0);
	// (the bright stars brighter still, for the constellations to read at a glance)
	vec3 c = field * (star_gain + smoothstep(0.08, 0.6, bright) * 6.0) * twinkle;
	// the bright stars, crisp points with a little glow, twinkling, in the same turned sky
	for (int i = 0; i < 40; i++) {
		vec4 st = bright_stars[i];
		if (st.w <= 0.0) break;
		float t2 = 2.0 * (1.0 - dot(e, st.xyz));
		float r = 0.0055 * (0.6 + st.w);
		float rr = r * r;
		if (t2 > rr * 25.0) continue;
		float tw = 0.8 + 0.2 * sin(TIME * (2.3 + float(i) * 0.41) + float(i) * 1.7);
		c += vec3(0.95, 0.97, 1.0) * (smoothstep(rr, rr * 0.15, t2) * 3.0 + exp(-t2 / (rr * 5.0)) * 0.6) * st.w * tw;
	}
	// over Earth, the night's deep blue and a haze at the horizon laid over the stars (less of it
	// out in space); faded in and out with the rest, never cut
	vec3 night = mix(low, top, smoothstep(-0.05, 0.6, up));
	c += night * (1.0 - space) * 0.45;
	c = mix(c, night, smoothstep(0.25, -0.35, up) * (1.0 - space) * 0.7);
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
		c = mix(c, face, smoothstep(0.9988, 0.9990, m) * moon_fade);
	}
	c += vec3(0.25, 0.3, 0.4) * pow(max(m, 0.0), 80.0) * 0.5 * moon_fade;
	COLOR = c;
}