shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
// Where the beam will fall, thrown faintly on the ground under the ship: a thin ring inside the
// beam's foot, a dashed ring turning inside it, four ticks pointing in and a dot in the middle,
// pulsing gently. `power` fades it as the beam comes on.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.6, 1.0, 0.7);
uniform float power = 1.0;

float band(float x, float at, float half_width) {
	return 1.0 - smoothstep(half_width * 0.5, half_width, abs(x - at));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float ring = band(r, 0.86, 0.035);
	float dashes = band(r, 0.6, 0.035) * step(0.0, sin(a * 8.0 + TIME * 1.5));
	float ticks = band(r, 0.72, 0.1) * max(band(abs(p.x), 0.0, 0.035), band(abs(p.y), 0.0, 0.035));
	float dot_mid = 1.0 - smoothstep(0.04, 0.08, r);
	float pool = (1.0 - smoothstep(0.0, 0.9, r)) * 0.08;
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	ALBEDO = tint * (max(max(ring, dashes), max(ticks, dot_mid)) * pulse + pool) * power * 0.4;
}
