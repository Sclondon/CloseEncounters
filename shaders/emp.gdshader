shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// An EMP blast: an expanding shell of crackling electricity, bright at its rim, forks of lightning
// crawling over it and flickering, the whole of it fading as it grows (`fade`, 1 to 0).

uniform vec3 tint : source_color = vec3(0.55, 0.85, 1.0);
uniform float fade = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	// (forks of lightning: thin bright lines where a churning noise crosses its middle)
	float t = TIME * 6.0 + seed;
	vec2 uv = UV * vec2(14.0, 7.0);
	float n = noise(uv + vec2(t * 0.7, -t * 0.4)) + 0.5 * noise(uv * 2.3 - vec2(t, t * 0.6));
	float arcs = 1.0 - smoothstep(0.0, 0.06, abs(n - 0.75));
	float n2 = noise(uv * 1.7 + vec2(-t * 0.5, t * 0.9));
	arcs = max(arcs, 1.0 - smoothstep(0.0, 0.05, abs(n2 - 0.5)));
	float flicker = 0.75 + 0.25 * step(0.4, hash(vec2(floor(TIME * 24.0), seed)));
	vec3 col = tint * (rim * 1.4 + 0.08) + vec3(0.85, 0.95, 1.0) * arcs * 1.6;
	ALBEDO = col * fade * flicker;
}
