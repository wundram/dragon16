shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_default, cull_disabled, shadows_disabled, unshaded, skip_vertex_transform;

// Camera-facing isotropic Gaussian.
// INSTANCE_CUSTOM = (radius, opacity, cut_policy, hull_top).
// Tests the scene depth buffer (meshes write it); does not write depth
// so soft kernels cannot bury the player.

uniform float softness : hint_range(1.0, 8.0) = 4.0;
uniform float saturate : hint_range(0.0, 2.0) = 1.08;
uniform float lift : hint_range(0.0, 0.4) = 0.02;
uniform vec3 cutaway_origin = vec3(0.0);
uniform float cutaway_inner = 1.3;
uniform float cutaway_outer = 2.6;

varying float v_opacity;
varying float v_policy;
varying float v_hull_top;
varying vec3 v_world;

void vertex() {
	float radius = max(INSTANCE_CUSTOM.r, 0.001);
	v_opacity = INSTANCE_CUSTOM.g;
	v_policy = INSTANCE_CUSTOM.b;
	v_hull_top = INSTANCE_CUSTOM.a;
	vec4 world = MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	vec3 cam_x = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 cam_y = normalize(INV_VIEW_MATRIX[1].xyz);
	world.xyz += (cam_x * VERTEX.x + cam_y * VERTEX.y) * radius;
	v_world = world.xyz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * world;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		discard;
	}
	float cut = 0.0;
	if (v_policy > 0.5) {
		float above = step(cutaway_origin.y + 0.25, v_hull_top);
		float d = length(v_world.xz - cutaway_origin.xz);
		float ring = 1.0 - smoothstep(cutaway_inner, cutaway_outer, d);
		cut = above * ring;
	}
	if (cut > 0.72) {
		discard;
	}
	float g = exp(-r2 * softness);
	vec3 col = COLOR.rgb;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturate) + lift;
	ALBEDO = col;
	ALPHA = g * v_opacity * COLOR.a * (1.0 - cut);
}
