shader_type spatial;
// The ground, painted from where each point is (before the bend), by region (see world.gd Biome):
// `biomes` holds one texel per chunk round the saucer, and the regions blend across the edges of
// their chunks. The highways run every `road_every` both ways.

#include "res://shaders/bend.gdshaderinc"

uniform sampler2D biomes : filter_nearest;
uniform vec2 biome_corner = vec2(0.0);
uniform float chunk = 48.0;
uniform float road_every = 240.0;
// Crop circles: (x, z, radius, -) each, pressed into the crop fields only (see world.gd crop_circle)
uniform vec4 circles[24];

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec3 farm(vec2 p, float speck) {
	float field = 40.0;
	vec2 cell = floor(p / field);
	vec2 in_cell = p / field - cell;
	float h = hash(cell + 0.5);
	bool across = hash(cell + 7.5) > 0.5;
	float row = fract((across ? p.x : p.y) * 0.8);
	vec3 grass = mix(vec3(0.2, 0.36, 0.14), vec3(0.26, 0.42, 0.16), speck);
	vec3 c = grass;
	if (h < 0.3) {
		c = grass;
	} else if (h < 0.5) {
		c = mix(vec3(0.62, 0.5, 0.2), vec3(0.75, 0.62, 0.28), step(0.4, row)) * (0.92 + 0.12 * speck);
	} else if (h < 0.7) {
		c = mix(vec3(0.27, 0.17, 0.1), vec3(0.36, 0.24, 0.14), step(0.5, row)) * (0.9 + 0.15 * speck);
	} else if (h < 0.85) {
		c = mix(vec3(0.12, 0.26, 0.08), vec3(0.22, 0.38, 0.12), step(0.45, row)) * (0.9 + 0.15 * speck);
	} else {
		c = mix(vec3(0.3, 0.42, 0.18), vec3(0.36, 0.46, 0.2), speck);
	}
	// A crop circle: the crop (or the grass) laid flat in rings, pale under the moon
	{
		for (int i = 0; i < 24; i++) {
			vec4 cc = circles[i];
			if (cc.z <= 0.0) continue;
			float d = length(p - cc.xy);
			if (d < cc.z) {
				float ring = step(0.5, fract(d / cc.z * 3.0));
				float centre = 1.0 - step(cc.z * 0.18, d);
				c = mix(vec3(0.78, 0.72, 0.5), vec3(0.6, 0.55, 0.36), ring) * (0.95 + 0.1 * speck);
				c = mix(c, vec3(0.85, 0.8, 0.58), centre);
			}
		}
	}
	float border = min(min(in_cell.x, 1.0 - in_cell.x), min(in_cell.y, 1.0 - in_cell.y)) * field;
	if (border < 0.7) {
		c = vec3(0.1, 0.2, 0.08) * (0.8 + 0.4 * speck);
	}
	return c;
}

vec3 paint(int b, vec2 p, float speck) {
	float big = vnoise(p * 0.04);
	float mid = vnoise(p * 0.15);
	if (b == 1) {
		// The high plains: golden grass, sage-green in patches
		vec3 c = mix(vec3(0.5, 0.44, 0.22), vec3(0.58, 0.52, 0.28), big);
		c = mix(c, vec3(0.38, 0.42, 0.28), smoothstep(0.55, 0.75, mid) * 0.7);
		return c * (0.9 + 0.2 * speck);
	} else if (b == 2) {
		// Red desert sand, with wind streaks
		vec3 c = mix(vec3(0.6, 0.3, 0.17), vec3(0.74, 0.42, 0.24), big);
		c *= 0.94 + 0.08 * sin(p.x * 0.9 + p.y * 0.3 + mid * 6.0);
		return c * (0.92 + 0.14 * speck);
	} else if (b == 3) {
		// New Mexico: ochre earth and dark scrub
		vec3 c = mix(vec3(0.58, 0.44, 0.28), vec3(0.66, 0.52, 0.34), big);
		c = mix(c, vec3(0.26, 0.3, 0.18), step(0.93, hash(floor(p * 2.5))) * 0.8);
		return c * (0.92 + 0.14 * speck);
	} else if (b == 4) {
		// The mountains: forest floor, bare rock, and snow in the hollows
		vec3 c = mix(vec3(0.1, 0.2, 0.1), vec3(0.16, 0.26, 0.13), mid);
		c = mix(c, vec3(0.4, 0.39, 0.38), smoothstep(0.55, 0.7, big));
		c = mix(c, vec3(0.86, 0.88, 0.92), smoothstep(0.78, 0.84, vnoise(p * 0.07 + 20.0)));
		return c * (0.9 + 0.2 * speck);
	}
	return farm(p, speck);
}

int biome_of(vec2 cell) {
	ivec2 size = textureSize(biomes, 0);
	ivec2 i = clamp(ivec2(cell), ivec2(0), size - 1);
	return int(texelFetch(biomes, i, 0).r * 255.0 / 40.0 + 0.5);
}

void fragment() {
	vec2 p = world.xz;
	float speck = hash(floor(p * 3.0));
	vec2 q = (p - biome_corner) / chunk;
	vec2 i = floor(q);
	vec2 f = smoothstep(0.3, 0.7, fract(q));
	int b00 = biome_of(i);
	int b10 = biome_of(i + vec2(1, 0));
	int b01 = biome_of(i + vec2(0, 1));
	int b11 = biome_of(i + vec2(1, 1));
	vec3 c;
	if (b00 == b10 && b00 == b01 && b00 == b11) {
		c = paint(b00, p, speck);
	} else {
		// (a ragged edge between regions, not a straight one)
		f = clamp(f + (vnoise(p * 0.2) - 0.5) * 0.5, 0.0, 1.0);
		c = mix(mix(paint(b00, p, speck), paint(b10, p, speck), f.x), mix(paint(b01, p, speck), paint(b11, p, speck), f.x), f.y);
	}
	// The highways, with a dashed line down the middle
	float dx = abs(mod(p.x + road_every * 0.5, road_every) - road_every * 0.5);
	float dz = abs(mod(p.y + road_every * 0.5, road_every) - road_every * 0.5);
	if (dx < 3.0) {
		c = vec3(0.16, 0.16, 0.17) * (0.9 + 0.2 * speck);
		if (dx < 0.12 && fract(p.y * 0.25) < 0.5) c = vec3(0.85, 0.7, 0.2);
	}
	if (dz < 3.0) {
		c = vec3(0.16, 0.16, 0.17) * (0.9 + 0.2 * speck);
		if (dz < 0.12 && fract(p.x * 0.25) < 0.5) c = vec3(0.85, 0.7, 0.2);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
