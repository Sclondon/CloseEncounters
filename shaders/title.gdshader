shader_type canvas_item;
// The name on the title, blooming: its glow (the label's green outline and halo, see main.gd
// `_build_hud`) breathing brighter and dimmer, and a band of light sweeping across the letters every
// few seconds.

uniform float sweep_every = 4.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float x = FRAGCOORD.x * SCREEN_PIXEL_SIZE.x;
	float at = fract(TIME / sweep_every) * 1.8 - 0.4;
	float band = exp(-pow((x - at) * 9.0, 2.0));
	float breathe = 0.5 + 0.5 * sin(TIME * 2.4);
	c.rgb *= 1.0 + 0.25 * breathe + 0.9 * band;
	c.a *= 1.0 + 0.35 * breathe * (1.0 - c.a);
	COLOR = c;
}
