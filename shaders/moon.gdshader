shader_type spatial;
// The moon's ground (see scripts/moon.gd): the model's own greys, worked over by where each point
// is: broad lighter and darker patches like the seas and highlands seen from Earth, a fine grit,
// and small craters everywhere, each a dark bowl with its rim catching the sun on one side. Bent
// and snapped like everything else.

#include "res://shaders/bend.gdshaderinc"

// Where the sun is: the crater rims facing it are lit, the far sides of the bowls are in shadow
uniform vec2 sun = vec2(0.7, 0.5);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.03) * 0.25 + noise(p * 4.1) * 0.125 + noise(p * 8.3) * 0.0625;
}

// How a field of small craters `size` metres apart darkens (-) or lights (+) this point
float craters(vec2 p, float size) {
	vec2 cell = floor(p / size);
	float shade = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 c = cell + vec2(float(x), float(y));
			if (hash(c + 7.1) > 0.55) continue;
			vec2 centre = (c + vec2(hash(c), hash(c + 3.3))) * size;
			float r = size * (0.15 + 0.3 * hash(c + 5.7));
			vec2 off = p - centre;
			float d = length(off) / r;
			if (d < 1.25) {
				float side = dot(normalize(off + 0.0001), normalize(sun));
				// (the bowl, darker on the sunward wall, which faces away from the sun; the rim lit)
				float bowl = (1.0 - smoothstep(0.7, 1.0, d)) * (0.18 + 0.12 * side);
				float lip = smoothstep(0.85, 1.0, d) * (1.0 - smoothstep(1.0, 1.25, d)) * (0.1 + 0.12 * side);
				shade += lip - bowl;
			}
		}
	}
	return shade;
}

void fragment() {
	vec2 p = world.xz;
	float patches = mix(0.78, 1.12, smoothstep(0.35, 0.65, fbm(p * 0.05)));
	// (fine detail fades out where a pixel covers more ground than it: far off it only sparkles as the
	// camera moves, which read as flicker)
	float px = length(fwidth(p));
	float grit = (hash(floor(p * 10.0)) - 0.5) * 0.08 * (1.0 - smoothstep(0.04, 0.12, px)) + (fbm(p * 1.3) - 0.5) * 0.18 * (1.0 - smoothstep(0.3, 1.0, px));
	float pits = craters(p, 4.0) * (1.0 - smoothstep(0.6, 1.8, px)) + craters(p + 31.0, 1.6) * 0.7 * (1.0 - smoothstep(0.25, 0.7, px));
	ALBEDO = COLOR.rgb * clamp(patches + grit + pits, 0.35, 1.4);
	ROUGHNESS = 1.0;
	SPECULAR = 0.05;
}
