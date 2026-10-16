shader_type canvas_item;
// The menus' buttons as holograms (see main.gd _button): fine scanlines, a faint flicker, and a band
// of light sweeping down through them now and then, over the button's box and its text alike

void fragment() {
	float lines = 0.82 + 0.18 * step(0.5, fract(FRAGCOORD.y / 3.0));
	float flick = 0.94 + 0.06 * sin(TIME * 23.0 + FRAGCOORD.y * 0.05);
	float band = smoothstep(0.05, 0.0, abs(fract(SCREEN_UV.y * 0.7 - TIME * 0.22) - 0.5));
	COLOR.rgb = COLOR.rgb * lines * flick + vec3(0.25, 0.6, 0.3) * band * COLOR.a * 0.45;
	COLOR.a *= 0.94;
}
