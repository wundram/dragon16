shader_type canvas_item;

// Texel anti-aliasing ("sharp bilinear"): bilinear sampling whose blend zone is
// compressed to exactly one screen pixel at each texel seam. Pixel interiors stay
// razor sharp; subpixel motion produces smooth luminance ramps instead of edge pops.
// Requires the texture to use Linear filtering.
//
// NOTE: in fragment(), COLOR arrives pre-multiplied as (vertex modulate × plain
// texture sample). We need modulate × OUR adjusted sample, so capture the raw
// vertex color in vertex() and compose explicitly.
varying vec4 vcol;

void vertex() {
	vcol = COLOR;
}

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 p = UV * size;
	vec2 seam = floor(p + 0.5);
	vec2 blend = clamp((p - seam + 0.5) / fwidth(p), 0.0, 1.0);
	COLOR = vcol * texture(TEXTURE, (seam + blend - 0.5) / size);
}
