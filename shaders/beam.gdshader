shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// The tractor beam: a cone of green light from the saucer's belly to the ground, brightest along
// its edges, with bright scanlines racing up it, faint enough to see through. Two of them, one just
// inside the other (`core` for the inner, quicker). `power` fades it in and out.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.55, 1.0, 0.65);
uniform float power = 1.0;
uniform float core = 0.0;
// The CARNIVORB's beam: bands of every colour of the rainbow running up it, round it and on through
uniform float rainbow = 0.0;

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float up = UV.y;
	float speed = core > 0.5 ? 14.0 : 9.0;
	float lines = pow(0.5 + 0.5 * sin(up * (core > 0.5 ? 22.0 : 34.0) + TIME * speed), 8.0);
	float a = (0.1 + 0.5 * pow(edge, 3.0) + 0.6 * lines) * power;
	vec3 c = mix(tint, hue(fract(up * 1.6 - TIME * 0.45 + UV.x * 1.0)) * 1.15, rainbow);
	ALBEDO = c * a * mix(1.0, 0.5, up) * (core > 0.5 ? 0.35 : 0.6);
}
