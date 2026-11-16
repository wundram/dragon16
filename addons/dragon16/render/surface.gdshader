shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

// Visible tile hull. Writes depth so splat dressing and the player can test it.
// Cut-away discards a radius around the player so the hole is in the z-buffer.

uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform vec3 cutaway_origin = vec3(0.0);
uniform float cutaway_inner = 1.3;
uniform float cutaway_outer = 2.6;
instance uniform vec4 albedo : source_color = vec4(0.55, 0.55, 0.58, 1.0);
instance uniform float cut_policy = 0.0; // 0 never, 1 if_above, 2 if_occludes
instance uniform float hull_top = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float cut = 0.0;
	if (cut_policy > 0.5) {
		float above = step(cutaway_origin.y + 0.25, hull_top);
		float d = length(v_world.xz - cutaway_origin.xz);
		float ring = 1.0 - smoothstep(cutaway_inner, cutaway_outer, d);
		cut = above * ring;
	}
	if (cut > 0.72) {
		discard;
	}
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	ALPHA = albedo.a;
}
