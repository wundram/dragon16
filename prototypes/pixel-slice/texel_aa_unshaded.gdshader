shader_type canvas_item;
render_mode unshaded;

// Texel-AA variant for the shadow band: shadows are darkness, so they must not
// receive 2D light (a torch lighting a shadow quad reads as a glowing ghost).
// See texel_aa.gdshader for the vcol pattern.
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
