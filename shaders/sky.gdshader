shader_type sky;
// A clear night over farm country: deep blue going to a pale haze at the horizon, stars, and a moon.

uniform vec3 top : source_color = vec3(0.01, 0.02, 0.07);
uniform vec3 low : source_color = vec3(0.1, 0.14, 0.26);
uniform vec3 moon_dir = vec3(-0.4, 0.55, -0.73);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -0.2, 1.0);
	vec3 c = mix(low, top, smoothstep(-0.05, 0.6, up));
	vec2 cell = floor(vec2(atan(d.x, d.z) * 120.0, d.y * 120.0));
	float star = step(0.992, hash(cell)) * smoothstep(0.0, 0.3, up);
	c += vec3(star) * (0.5 + 0.5 * hash(cell + 3.0));
	float m = dot(d, normalize(moon_dir));
	c += vec3(1.0, 0.97, 0.85) * smoothstep(0.9985, 0.999, m);
	c += vec3(0.25, 0.3, 0.4) * pow(max(m, 0.0), 60.0) * 0.4;
	COLOR = c;
}
