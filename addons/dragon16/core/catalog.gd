class_name SplatCatalog
extends RefCounted
## Procedural placeholder tiles and the player splite. Replace per-id later.


static func tiles() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 16
	return {
		"grass": _grass(rng),
		"brush": _brush(rng, false),
		"brush_heavy": _brush(rng, true),
		"stone": _stone(rng),
		"planks": _planks(rng),
		"roof": _roof(rng),
		"wall": _wall(rng),
		"door": _door(rng),
		"stair": _stair(rng),
		"trunk": _trunk(rng),
		"canopy": _canopy(rng),
	}


static func player_splite() -> Splite:
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	var s := Splite.new()
	s.id = &"player"
	s.fps = 10.0
	s.hitbox = AABB(Vector3(-0.18, 0.0, -0.18), Vector3(0.36, 0.72, 0.36))
	var idle := _figure(rng, 0.0)
	s.clips = {
		&"idle": [idle],
		&"walk": [_figure(rng, 0.10), _figure(rng, 0.0), _figure(rng, -0.10), _figure(rng, 0.0)],
	}
	return s


static func _new_tile(id: String, hull: AABB, walkable: bool, blocks: bool = false, cutaway: SplatTile.Cutaway = SplatTile.Cutaway.NEVER) -> SplatTile:
	var t := SplatTile.new()
	t.id = StringName(id)
	t.cloud = SplatCloud.new()
	t.hull = hull
	t.walkable = walkable
	t.blocks_los = blocks
	t.cutaway = cutaway
	return t


static func _blob(c: SplatCloud, rng: RandomNumberGenerator, center: Vector3, rad: float, color: Color, n: int, flatten: float, rmin: float, rmax: float, op: float = 0.82) -> void:
	for _i in n:
		var o := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if o.length_squared() > 1.0:
			o = o.normalized()
		o.y *= flatten
		var col := color.lightened(rng.randf_range(-0.05, 0.06))
		c.add(center + o * rad, rng.randf_range(rmin, rmax), col, op)
	c.recompute_aabb()


static func _slab(c: SplatCloud, rng: RandomNumberGenerator, y: float, color: Color, radius: float = 0.31, op: float = 0.94) -> void:
	# A few big flat pancakes that fill a 1x1 cell from above.
	var offs := [Vector3(0, y, 0), Vector3(0.22, y, 0.18), Vector3(-0.2, y, 0.2), Vector3(0.2, y, -0.2), Vector3(-0.18, y, -0.18)]
	for o in offs:
		c.add(o, radius * rng.randf_range(0.92, 1.05), color.lightened(rng.randf_range(-0.04, 0.05)), op)
	c.recompute_aabb()


static func _grass(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("grass", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.08, 1)), true)
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.04, Color(0.36, 0.58, 0.30), 0.31, 0.95)
	return t


static func _brush(rng: RandomNumberGenerator, heavy: bool) -> SplatTile:
	var t := _new_tile("brush_heavy" if heavy else "brush", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.16, 1)), true)
	t.cast_model = SplatTile.CastModel.BLOB
	t.cast_height_override = 0.85 if heavy else 0.45
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.04, Color(0.32, 0.50, 0.26), 0.38, 0.92)
	_blob(t.cloud, rng, Vector3(0, 0.32 if heavy else 0.20, 0), 0.36, Color(0.28, 0.54, 0.24), 10 if heavy else 6, 0.45, 0.14, 0.22, 0.78)
	if heavy:
		_blob(t.cloud, rng, Vector3(0, 0.62, 0), 0.28, Color(0.22, 0.44, 0.18), 8, 0.4, 0.13, 0.20, 0.72)
	return t


static func _stone(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("stone", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.18, 1)), true, false, SplatTile.Cutaway.IF_ABOVE)
	t.surface_visible = true
	t.surface_color = Color(0.56, 0.56, 0.60)
	t.cast_model = SplatTile.CastModel.HULL
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.12, Color(0.62, 0.62, 0.66), 0.28, 0.75)
	return t


static func _planks(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("planks", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.10, 1)), true)
	t.surface_visible = true
	t.surface_color = Color(0.42, 0.30, 0.22)
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.06, Color(0.50, 0.36, 0.26), 0.26, 0.7)
	return t


static func _roof(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("roof", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.20, 1)), true, false, SplatTile.Cutaway.IF_ABOVE)
	t.surface_visible = true
	t.surface_color = Color(0.72, 0.30, 0.26)
	t.cast_model = SplatTile.CastModel.HULL
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.14, Color(0.80, 0.36, 0.30), 0.28, 0.75)
	return t


static func _wall(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("wall", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 1.15, 1)), false, true, SplatTile.Cutaway.IF_ABOVE)
	t.surface_visible = true
	t.surface_color = Color(0.78, 0.75, 0.70)
	t.cast_model = SplatTile.CastModel.HULL
	t.receive_shadow = false
	_slab(t.cloud, rng, 1.16, Color(0.88, 0.85, 0.78), 0.28, 0.7)
	_blob(t.cloud, rng, Vector3(0, 0.45, 0.42), 0.22, Color(0.58, 0.54, 0.48), 5, 0.7, 0.08, 0.13, 0.75)
	_blob(t.cloud, rng, Vector3(-0.42, 0.45, 0), 0.22, Color(0.50, 0.47, 0.42), 5, 0.7, 0.08, 0.13, 0.75)
	return t


static func _door(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("door", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 1.15, 1)), true, false, SplatTile.Cutaway.IF_ABOVE)
	t.surface_visible = true
	t.surface_color = Color(0.70, 0.66, 0.60)
	t.cast_model = SplatTile.CastModel.HULL
	t.receive_shadow = false
	_slab(t.cloud, rng, 1.16, Color(0.86, 0.83, 0.76), 0.28, 0.7)
	_blob(t.cloud, rng, Vector3(0, 0.4, 0.42), 0.18, Color(0.16, 0.10, 0.08), 4, 0.6, 0.07, 0.11, 0.8)
	return t


static func _stair(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("stair", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.18, 1)), true, false, SplatTile.Cutaway.IF_ABOVE)
	t.surface_visible = true
	t.surface_color = Color(0.58, 0.58, 0.62)
	t.cast_model = SplatTile.CastModel.HULL
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.10, Color(0.64, 0.64, 0.68), 0.28, 0.75)
	return t


static func _trunk(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("trunk", AABB(Vector3(-0.28, 0.0, -0.28), Vector3(0.56, 0.7, 0.56)), true)
	t.cast_model = SplatTile.CastModel.BLOB
	t.cast_height_override = 0.7
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.04, Color(0.36, 0.58, 0.30), 0.38, 0.94)
	_blob(t.cloud, rng, Vector3(0, 0.22, 0), 0.16, Color(0.40, 0.26, 0.16), 7, 0.7, 0.10, 0.15, 0.92)
	return t


static func _canopy(rng: RandomNumberGenerator) -> SplatTile:
	var t := _new_tile("canopy", AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1, 0.12, 1)), true, false, SplatTile.Cutaway.IF_OCCLUDES)
	t.cutaway_top = 1.05
	t.cast_model = SplatTile.CastModel.BLOB
	t.cast_height_override = 1.05
	t.receive_shadow = true
	_slab(t.cloud, rng, 0.04, Color(0.36, 0.58, 0.30), 0.38, 0.9)
	_blob(t.cloud, rng, Vector3(0, 0.78, 0), 0.48, Color(0.24, 0.50, 0.22), 12, 0.4, 0.16, 0.24, 0.74)
	return t


static func _figure(rng: RandomNumberGenerator, swing: float) -> SplatCloud:
	var c := SplatCloud.new()
	c.add(Vector3(0, 0.50, 0), 0.28, Color(0.18, 0.40, 0.90), 0.98)
	c.add(Vector3(-0.14, 0.16, swing), 0.13, Color(0.16, 0.14, 0.22), 0.96)
	c.add(Vector3(0.14, 0.16, -swing), 0.13, Color(0.16, 0.14, 0.22), 0.96)
	c.add(Vector3(0, 0.88, 0), 0.22, Color(0.98, 0.84, 0.72), 0.98)
	c.add(Vector3(0, 1.04, 0.02), 0.18, Color(0.34, 0.20, 0.12), 0.96)
	c.recompute_aabb()
	return c
