shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// A soft glow round the moon in the sky (see main.gd _place_moon): a square behind the ball, brightest
// at the ball's edge and fading out to nothing

// The ball's edge, a fraction of the way out from the middle of the square to its side
uniform float inner = 0.333;
uniform vec3 tint : source_color = vec3(0.72, 0.78, 0.95);

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float g = r < inner ? 1.0 : pow(clamp((1.0 - r) / (1.0 - inner), 0.0, 1.0), 3.0);
	ALBEDO = tint * g * 0.45;
}
