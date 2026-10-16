shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// The moon over Earth: a ball wrapped in NASA's map of it (textures/moon_lroc.jpg, LRO, public
// domain), the near side turned to the camera (see main.gd _place_moon), lit from one side by the sun
// so it shows a little gibbous, darker toward its edge. Not bent: it hangs far off, as Earth does.

uniform sampler2D map : source_color, filter_linear_mipmap;
// The sun, in the ball's own terms
uniform vec3 sun = vec3(0.55, 0.2, 0.8);

varying vec3 n_obj;

void vertex() {
	n_obj = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(n_obj);
	vec2 uv = vec2(0.5 + atan(n.x, n.z) / 6.2832, 0.5 - asin(clamp(n.y, -1.0, 1.0)) / 3.1416);
	vec3 ground = texture(map, uv).rgb;
	float lit = clamp(dot(n, normalize(sun)) * 1.15 + 0.12, 0.04, 1.0);
	ALBEDO = ground * 1.25 * lit * vec3(1.0, 0.98, 0.93);
}
