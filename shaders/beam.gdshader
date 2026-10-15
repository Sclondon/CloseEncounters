shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// The tractor beam: a cone of green light from the saucer's belly to the ground, brightest along
// its edges, with bright scanlines racing up it. Two of them, one inside the other (`core` for the
// inner, brighter and quicker). `power` fades it in and out.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 tint : source_color = vec3(0.55, 1.0, 0.65);
uniform float power = 1.0;
uniform float core = 0.0;
// 1 = a searchlight: brightest down its middle and at the lamp, fading all the way along to nothing
// at its far end and softly away to its edges and where it meets the ground, so no cone shows
uniform float soft = 0.0;

void fragment() {
	float edge = 1.0 - abs(dot(NORMAL, VIEW));
	float up = UV.y;
	float speed = core > 0.5 ? 14.0 : 9.0;
	float lines = pow(0.5 + 0.5 * sin(up * (core > 0.5 ? 22.0 : 34.0) + TIME * speed), 8.0);
	float a = (0.1 + 0.5 * pow(edge, 3.0) + 0.6 * lines) * power;
	ALBEDO = tint * a * mix(1.0, 0.5, up) * (core > 0.5 ? 0.7 : 1.0);
	if (soft > 0.5) {
		float middle = smoothstep(0.0, 1.0, abs(dot(NORMAL, VIEW)));
		float along = up * up;
		float ground = smoothstep(0.0, 2.5, world.y);
		ALBEDO = tint * power * middle * middle * along * ground * 0.8;
	}
}
