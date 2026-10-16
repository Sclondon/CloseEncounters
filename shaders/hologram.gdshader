shader_type spatial;
// A model drawn as a little hologram for the log (see scripts/holograms.gd): green light, brighter at
// its edges, its own shading kept faintly from its colours, in fine scanlines
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float lum = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	float lines = 0.75 + 0.25 * step(0.5, fract(FRAGCOORD.y / 3.0));
	ALBEDO = vec3(0.35, 1.0, 0.55) * (0.35 + lum * 0.9 + rim * 0.9) * lines;
	ALPHA = clamp(0.55 + rim * 0.45, 0.0, 1.0) * lines;
}
