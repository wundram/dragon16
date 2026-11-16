@tool
class_name SplatWorld
extends Node3D
## Grid of splat tiles across height levels, plus room visibility.

@export var level_height: float = 1.25
@export var batch_path: NodePath
@export var softness: float = 3.4
## Points toward the sun. Default is a 4pm WNW sun (~33° elevation),
## not noon — otherwise drops collapse under the caster.
const AFTERNOON_SUN := Vector3(-0.76, 0.54, -0.35)
@export var sun_dir: Vector3 = AFTERNOON_SUN

var tiles: Dictionary = {}          # id -> SplatTile
var cells: Dictionary = {}          # Vector3i(level, x, z) -> {tile, room}
var walk: Dictionary = {}           # Vector3i -> true
var active_rooms: Dictionary = {}   # room -> true
var fields: Array[DistortionField] = []

var _batch: SplatBatch
var _drops: DropShadowBatch
var _hulls: Node3D
var _surface_mat: ShaderMaterial
var _actor_cloud: SplatCloud
var _actor_xform := Transform3D.IDENTITY
var _actor_mod := Color.WHITE
var _needs_static := true
@export var cutaway_inner: float = 1.35
@export var cutaway_outer: float = 2.7


func _ready() -> void:
	_hulls = Node3D.new()
	_hulls.name = "Hulls"
	add_child(_hulls)
	if batch_path != NodePath():
		_batch = get_node_or_null(batch_path)
	if _batch == null:
		_batch = SplatBatch.new()
		_batch.name = "Batch"
		add_child(_batch)
	_batch.softness = softness
	_batch.sun_dir = sun_dir.normalized()
	_drops = DropShadowBatch.new()
	_drops.name = "Drops"
	add_child(_drops)


func register_tiles(catalog: Dictionary) -> void:
	tiles = catalog


func set_cell(level: int, x: int, z: int, tile_id: String, room: String) -> void:
	var tile: SplatTile = tiles.get(tile_id)
	if tile == null:
		push_warning("Unknown tile '%s'" % tile_id)
		return
	var key := Vector3i(level, x, z)
	cells[key] = {"tile": tile, "room": room, "id": tile_id}
	if tile.walkable:
		walk[key] = true
	_needs_static = true


func floor_y(level: float) -> float:
	return level * level_height


func cell_origin(level: int, x: int, z: int) -> Vector3:
	return Vector3(float(x), floor_y(level), float(z))


func set_active_rooms(rooms: Array) -> void:
	var next := {}
	for r in rooms:
		next[r] = true
	if next == active_rooms:
		return
	active_rooms = next
	_needs_static = true
	_rebuild_hulls()


func set_actor(cloud: SplatCloud, xform: Transform3D, modulate: Color = Color.WHITE) -> void:
	_actor_cloud = cloud
	_actor_xform = xform
	_actor_mod = modulate


func is_walkable(level: int, xz: Vector2) -> bool:
	var key := Vector3i(level, int(round(xz.x)), int(round(xz.y)))
	return walk.has(key)


func room_at(level: int, xz: Vector2) -> String:
	var key := Vector3i(level, int(round(xz.x)), int(round(xz.y)))
	if cells.has(key):
		return cells[key].room
	return "OUTSIDE"


func refresh(time: float = 0.0) -> void:
	if _batch == null:
		return
	var head := _actor_xform.origin + Vector3(0.0, 0.72, 0.0)
	_batch.set_cutaway(head, cutaway_inner, cutaway_outer)
	_batch.sun_dir = sun_dir.normalized()
	_apply_surface_cutaway(head)
	var distort := not fields.is_empty()
	if _needs_static:
		_batch.clear_static()
		for key in cells:
			var rec: Dictionary = cells[key]
			if not active_rooms.is_empty() and not active_rooms.has(rec.room):
				continue
			var tile: SplatTile = rec.tile
			var origin: Vector3 = cell_origin(key.x, key.y, key.z)
			var xf := Transform3D(Basis.IDENTITY, origin)
			if distort and _near_field(origin):
				continue
			_batch.add_static_cloud(tile.cloud, xf, Color.WHITE, float(tile.cutaway), _cut_measure(tile, origin))
		_rebuild_hulls()
		_rebuild_static_drops()
		_needs_static = false
	_batch.clear_dynamic()
	if distort:
		for key in cells:
			var rec2: Dictionary = cells[key]
			if not active_rooms.is_empty() and not active_rooms.has(rec2.room):
				continue
			var origin2: Vector3 = cell_origin(key.x, key.y, key.z)
			if _near_field(origin2):
				var t2: SplatTile = rec2.tile
				_add_distorted(t2.cloud, Transform3D(Basis.IDENTITY, origin2), Color.WHITE, time, float(t2.cutaway), _cut_measure(t2, origin2))
	if _actor_cloud:
		if distort and _near_field(_actor_xform.origin):
			_add_distorted(_actor_cloud, _actor_xform, _actor_mod, time, 0.0, 0.0)
		else:
			_batch.add_dynamic_cloud(_actor_cloud, _actor_xform, _actor_mod)
	_update_actor_drop()
	_batch.commit()
	if _drops:
		_drops.commit()


func _cut_measure(tile: SplatTile, origin: Vector3) -> float:
	# if_above: world height of the hull floor (only higher slabs cut).
	# if_occludes: visual top, so a same-level canopy can still open.
	if tile.cutaway == SplatTile.Cutaway.IF_OCCLUDES:
		return origin.y + tile.cutaway_height()
	return origin.y + tile.hull.position.y


func _near_field(origin: Vector3) -> bool:
	for f in fields:
		var d := Vector2(origin.x - f.global_position.x, origin.z - f.global_position.z).length()
		if d < f.radius + 1.4:
			return true
	return false


func _add_distorted(cloud: SplatCloud, xf: Transform3D, mod: Color, time: float, policy: float = 0.0, hull_top: float = 0.0) -> void:
	var warped := SplatCloud.new()
	for i in cloud.size():
		var wp := xf * cloud.positions[i]
		for f in fields:
			wp = f.displace(wp, time)
		warped.add(wp, cloud.radii[i] * xf.basis.get_scale().x, cloud.colors[i], cloud.opacities[i])
	warped.recompute_aabb()
	_batch.add_dynamic_cloud(warped, Transform3D.IDENTITY, mod, policy, hull_top)


func _ensure_surface_mat() -> void:
	if _surface_mat != null:
		return
	_surface_mat = ShaderMaterial.new()
	_surface_mat.shader = load("res://addons/dragon16/render/surface.gdshader")


func _apply_surface_cutaway(head: Vector3) -> void:
	if _surface_mat == null:
		return
	_surface_mat.set_shader_parameter("cutaway_origin", head)
	_surface_mat.set_shader_parameter("cutaway_inner", cutaway_inner)
	_surface_mat.set_shader_parameter("cutaway_outer", cutaway_outer)


func _sun() -> Vector3:
	var s := sun_dir
	if s.y < 0.15:
		s.y = 0.15
	return s.normalized()


func _ground_offset(lift: float) -> Vector3:
	var s := _sun()
	return Vector3(-s.x / s.y, 0.0, -s.z / s.y) * lift


func _receiver_y(level: int, x: int, z: int) -> float:
	for m in range(level - 1, -1, -1):
		var key := Vector3i(m, x, z)
		if cells.has(key):
			var tile: SplatTile = cells[key].tile
			if tile.receive_shadow:
				return floor_y(m) + tile.hull.position.y + tile.hull.size.y
	return 0.02


func _rebuild_static_drops() -> void:
	if _drops == null:
		return
	_drops.clear_static()
	for key in cells:
		var rec: Dictionary = cells[key]
		if not active_rooms.is_empty() and not active_rooms.has(rec.room):
			continue
		var tile: SplatTile = rec.tile
		if tile.cast_model == SplatTile.CastModel.NONE:
			continue
		var origin: Vector3 = cell_origin(key.x, key.y, key.z)
		var top := origin.y + tile.cast_height()
		var rec_y := _receiver_y(key.x, key.y, key.z)
		var lift := top - rec_y
		if lift < 0.22:
			continue
		var pos := origin + _ground_offset(lift)
		pos.y = rec_y + 0.03
		var blob := tile.cast_model == SplatTile.CastModel.BLOB
		var half := Vector2(tile.hull.size.x, tile.hull.size.z) * (0.58 if blob else 0.52)
		if blob:
			half *= 1.15
		var str := clampf(0.18 + lift * 0.05, 0.22, 0.40)
		_drops.add_static(pos, half, str, blob)


func _update_actor_drop() -> void:
	if _drops == null:
		return
	_drops.clear_dynamic()
	if _actor_cloud == null:
		return
	var origin := _actor_xform.origin
	var rec_y := _receiver_y(int(round(origin.y / maxf(level_height, 0.001))), int(round(origin.x)), int(round(origin.z)))
	var lift := 0.72
	var pos := origin + _ground_offset(lift)
	pos.y = rec_y + 0.035
	_drops.add_dynamic(pos, Vector2(0.28, 0.22), 0.38, true)


func _rebuild_hulls() -> void:
	for c in _hulls.get_children():
		c.queue_free()
	_ensure_surface_mat()
	for key in cells:
		var rec: Dictionary = cells[key]
		if not active_rooms.is_empty() and not active_rooms.has(rec.room):
			continue
		var tile: SplatTile = rec.tile
		if not tile.cast_shadow and not tile.surface_visible:
			continue
		var origin: Vector3 = cell_origin(key.x, key.y, key.z)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = tile.hull.size
		mi.mesh = box
		mi.position = origin + tile.hull.get_center()
		if tile.surface_visible:
			mi.material_override = _surface_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.set_instance_shader_parameter("albedo", tile.surface_color)
			mi.set_instance_shader_parameter("cut_policy", float(tile.cutaway))
			mi.set_instance_shader_parameter("hull_top", _cut_measure(tile, origin))
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_hulls.add_child(mi)
