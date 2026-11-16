@tool
class_name SplatBatch
extends MultiMeshInstance3D
## v0 splat rasterizer: camera-facing Gaussian quads.
## Static tiles live on this MultiMesh; actors on a child mesh so we
## do not rebuild the world every frame.

@export var softness: float = 3.6:
	set(v):
		softness = v
		_apply_style()
@export var saturate: float = 1.08:
	set(v):
		saturate = v
		_apply_style()
@export var sun_dir: Vector3 = Vector3(-0.76, 0.54, -0.35).normalized()

var _static: Array[Dictionary] = []
var _dynamic: Array[Dictionary] = []
var _mat: ShaderMaterial
var _dyn_mm: MultiMeshInstance3D
var _static_dirty := true
var _dyn_dirty := true


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ensure_meshes()
	_apply_style()


func clear_static() -> void:
	_static.clear()
	_static_dirty = true


func clear_dynamic() -> void:
	_dynamic.clear()
	_dyn_dirty = true


func add_static_cloud(cloud: SplatCloud, xform: Transform3D, modulate: Color = Color.WHITE, policy: float = 0.0, hull_top: float = 0.0) -> void:
	if cloud == null or cloud.size() == 0:
		return
	_static.append({"cloud": cloud, "xform": xform, "mod": modulate, "policy": policy, "top": hull_top})
	_static_dirty = true


func add_dynamic_cloud(cloud: SplatCloud, xform: Transform3D, modulate: Color = Color.WHITE, policy: float = 0.0, hull_top: float = 0.0) -> void:
	if cloud == null or cloud.size() == 0:
		return
	_dynamic.append({"cloud": cloud, "xform": xform, "mod": modulate, "policy": policy, "top": hull_top})
	_dyn_dirty = true


func set_cutaway(origin: Vector3, inner: float = 1.3, outer: float = 2.6) -> void:
	_ensure_meshes()
	if _mat == null:
		return
	_mat.set_shader_parameter("cutaway_origin", origin)
	_mat.set_shader_parameter("cutaway_inner", inner)
	_mat.set_shader_parameter("cutaway_outer", outer)


func commit() -> void:
	_ensure_meshes()
	if _static_dirty:
		_upload(multimesh, _static)
		_static_dirty = false
	if _dyn_dirty:
		_upload(_dyn_mm.multimesh, _dynamic)
		_dyn_dirty = false


func _process(_delta: float) -> void:
	if _static_dirty or _dyn_dirty:
		commit()


func _upload(mm: MultiMesh, entries: Array[Dictionary]) -> void:
	var total := 0
	for e in entries:
		total += (e.cloud as SplatCloud).size()
	mm.instance_count = 0
	if total == 0:
		return
	mm.instance_count = total
	var ident := Basis.IDENTITY
	var n := 0
	for e in entries:
		var cloud: SplatCloud = e.cloud
		var xf: Transform3D = e.xform
		var mod: Color = e.mod
		var scale := xf.basis.get_scale().x
		var policy: float = e.get("policy", 0.0)
		var top: float = e.get("top", 0.0)
		var sun := sun_dir.normalized()
		var has_sv := cloud.shadow_vecs.size() == cloud.size()
		for i in cloud.size():
			var col: Color = cloud.colors[i]
			var shade := 1.0
			if has_sv:
				var sv: Vector3 = cloud.shadow_vecs[i]
				if sv.length_squared() > 0.0001:
					sv = xf.basis * sv
					shade = clampf(0.40 + 0.60 * sv.normalized().dot(sun), 0.28, 1.0)
			mm.set_instance_transform(n, Transform3D(ident, xf * cloud.positions[i]))
			mm.set_instance_color(n, Color(col.r * mod.r * shade, col.g * mod.g * shade, col.b * mod.b * shade, col.a * mod.a))
			mm.set_instance_custom_data(n, Color(cloud.radii[i] * scale, cloud.opacities[i] * mod.a, policy, top))
			n += 1


func _ensure_meshes() -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://addons/dragon16/render/gaussian.gdshader")
		_apply_style()
	if multimesh == null:
		multimesh = _make_mm()
	material_override = _mat
	if _dyn_mm == null:
		_dyn_mm = MultiMeshInstance3D.new()
		_dyn_mm.name = "Dynamic"
		_dyn_mm.multimesh = _make_mm()
		_dyn_mm.material_override = _mat
		_dyn_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_dyn_mm)


func _make_mm() -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mm.mesh = quad
	return mm


func _apply_style() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("softness", softness)
	_mat.set_shader_parameter("saturate", saturate)
