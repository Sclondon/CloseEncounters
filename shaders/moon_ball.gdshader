shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// The moon over Earth: a ball wrapped in NASA's map of it (textures/moon_lroc.jpg, LRO, public
// domain), the near side turned to the camera (see main.gd _place_moon), a full moon: lit from behind the
// camera by the sun, a little darker toward its edge. Not bent: it hangs far off, as Earth does.

uniform sampler2D map : source_color, filter_linear_mipmap;
// The sun, in the ball's own terms
uniform vec3 sun = vec3(0.0, 0.05, 1.0);

varying vec3 n_obj;

void vertex() {
	n_obj = normalize(VERTEX);
}

void fragment() {
	vec3 n = normalize(n_obj);
	vec2 uv = vec2(0.5 + atan(n.x, n.z) / 6.2832, 0.5 - asin(clamp(n.y, -1.0, 1.0)) / 3.1416);
	vec3 ground = texture(map, uv).rgb;
	float lit = clamp(0.62 + 0.45 * dot(n, normalize(sun)), 0.3, 1.0);
	ALBEDO = ground * 1.25 * lit * vec3(1.0, 0.98, 0.93);
}
