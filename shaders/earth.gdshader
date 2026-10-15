shader_type spatial;
render_mode unshaded, blend_mix, cull_back;
// Earth, seen from the moon: blue oceans, green and brown land, ice at the poles, clouds drifting
// over, the sun's side lit and the night side dark but for the lights of towns, and a thin blue
// rim of air. Made from the ball's own directions (no texture). Not bent: it hangs far off.

uniform vec3 sun = vec3(0.8, 0.35, 0.5);
// How much of it shows (it fades as the ship comes down into it at the start of a run)
uniform float fade = 1.0;

varying vec3 dir;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.5 + noise(p * 2.03) * 0.25 + noise(p * 4.07) * 0.125 + noise(p * 8.1) * 0.0625;
}

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float land = fbm(dir * 2.2);
	vec3 ocean = mix(vec3(0.02, 0.1, 0.3), vec3(0.06, 0.28, 0.55), smoothstep(0.3, 0.5, land));
	vec3 ground = mix(vec3(0.2, 0.42, 0.15), vec3(0.55, 0.45, 0.28), smoothstep(0.55, 0.7, fbm(dir * 5.0)));
	float is_land = smoothstep(0.5, 0.52, land);
	vec3 c = mix(ocean, ground, is_land);
	c = mix(c, vec3(0.92, 0.95, 1.0), smoothstep(0.82, 0.88, abs(dir.y)));
	float cloud = smoothstep(0.52, 0.7, fbm(dir * 3.0 + vec3(TIME * 0.01, 0.0, 0.0)));
	c = mix(c, vec3(1.0), cloud * 0.8);
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float day = smoothstep(-0.15, 0.25, dot(world_n, normalize(sun)));
	vec3 lights = vec3(1.0, 0.8, 0.4) * step(0.94, hash(floor(dir * 160.0))) * is_land * (1.0 - cloud);
	c = c * mix(0.06, 1.0, day) + lights * (1.0 - day) * 0.8;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	c += vec3(0.3, 0.55, 1.0) * rim * (0.25 + 0.75 * day);
	ALBEDO = c;
	ALPHA = fade;
}
