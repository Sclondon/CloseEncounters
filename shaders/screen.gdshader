shader_type canvas_item;
// The picture the world is drawn into, blown up with hard pixels and cut down to 15-bit colour with
// the PlayStation's own 4x4 dither pattern (Cryptlins' ps1_screen), and darkened at the corners.
// `hurt` washes it red for a moment when the saucer is hit.

uniform float hurt = 0.0;

const float DITHER[16] = float[](-4.0, 0.0, -3.0, 1.0, 2.0, -2.0, 3.0, -1.0, -3.0, 1.0, -4.0, 0.0, 3.0, -1.0, 2.0, -2.0);

void fragment() {
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	vec3 c = texture(TEXTURE, (px + 0.5) * TEXTURE_PIXEL_SIZE).rgb;
	vec2 off = UV - 0.5;
	c *= 1.0 - dot(off, off) * 0.9;
	c = mix(c, vec3(c.r * 0.6 + 0.35, c.g * 0.3, c.b * 0.3), hurt * (0.4 + dot(off, off) * 2.0));
	c *= 255.0;
	c += DITHER[int(mod(px.x, 4.0)) + int(mod(px.y, 4.0)) * 4];
	c = floor(clamp(c, 0.0, 255.0) / 8.0) * 8.0 / 248.0;
	COLOR = vec4(c, 1.0);
}
