shader_type canvas_item;
// The name on the title, blooming: its glow (the label's green outline and halo, see main.gd
// `_build_hud`) breathing brighter and dimmer, and a band of light sweeping across the letters every
// few seconds; and a hologram, like the buttons: fine scanlines, a flicker and now and then a glitch.

uniform float sweep_every = 4.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float x = FRAGCOORD.x * SCREEN_PIXEL_SIZE.x;
	float at = fract(TIME / sweep_every) * 1.8 - 0.4;
	float band = exp(-pow((x - at) * 9.0, 2.0));
	float breathe = 0.5 + 0.5 * sin(TIME * 2.4);
	c.rgb *= 1.0 + 0.25 * breathe + 0.9 * band;
	c.a *= 1.0 + 0.35 * breathe * (1.0 - c.a);
	// (the hologram: scanlines, a flicker, and a moment's glitch every few seconds)
	float lines = 0.78 + 0.22 * step(0.5, fract(FRAGCOORD.y / 3.0));
	float flick = 0.93 + 0.07 * sin(TIME * 23.0 + FRAGCOORD.y * 0.05);
	float glitch = step(0.97, fract(TIME * 0.31)) * 0.35;
	c.rgb *= lines * flick * (1.0 - glitch);
	c.a *= 0.92 - glitch * 0.4;
	COLOR = c;
}
