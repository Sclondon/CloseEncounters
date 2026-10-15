shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
// A puff of cloud in the night sky (see Clouds): moonlit on top and dark blue-grey underneath,
// see-through and soft at its edges, bent with the world. How much of it shows comes in its
// instance colour's alpha.

#include "res://shaders/bend.gdshaderinc"

uniform vec3 lit : source_color = vec3(0.62, 0.68, 0.84);
uniform vec3 shade : source_color = vec3(0.2, 0.24, 0.36);

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ALBEDO = mix(shade, lit, smoothstep(-0.4, 0.8, n.y));
	ALPHA = COLOR.a * 0.6 * smoothstep(0.0, 0.55, abs(dot(NORMAL, VIEW)));
}
