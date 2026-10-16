shader_type canvas_item;
// A hologram picture flickering a little, a bright band running down it now and then
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float band = smoothstep(0.08, 0.0, abs(UV.y - fract(TIME * 0.35)));
	float flicker = 0.88 + 0.12 * sin(TIME * 37.0 + UV.y * 9.0);
	COLOR = vec4(c.rgb * (flicker + band * 0.6), c.a * (flicker + band * 0.3));
}
