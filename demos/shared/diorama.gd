class_name DemoDiorama
extends Node3D
## Shared garden/house/walkway used by the playable toybox and the feature tour.
## Map changes go here so both demos stay in sync.

const MAPS := {
	0: [
		"################",
		"#..............#",
		"#.wwwwww.......#",
		"#.wcTccw...vvv.#",
		"#.wccccw...vtv.#",
		"#.wwwdww...vvv.#",
		"#..............#",
		"#.........^....#",
		"#.........^....#",
		"#...bbbb.......#",
		"#..bbBBBb......#",
		"#...bbbb.......#",
		"#..............#",
		"################",
	],
	1: [
		"",
		"",
		"",
		"",
		"",
		"          PP",
		"          PP",
		"          ^",
		"          ^",
	],
	2: [
		"",
		"",
		"  Pwwww  PPPPP",
		" ^Pwhhhw PP",
		" ^Pwhhhw",
		"  PPwdww",
		"  PPPPPPP",
	],
	3: [
		"",
		"",
		" LL",
		" LL",
	],
}

const STAIRS := [
	{"level": 0, "x": 10, "bot": 8, "top": 7, "exit": "N"},
	{"level": 1, "x": 10, "bot": 8, "top": 7, "exit": "N"},
	{"level": 2, "x": 1, "bot": 4, "top": 3, "exit": "N"},
]

var world: SplatWorld
var actor: SpliteActor
var cam: SplatCameraRig
var torch: OmniLight3D
var sun_light: DirectionalLight3D
var player_level := 0
var elev := 0.0
var current_run = null
var cellar_open := false
var ember_taken := false
var ember: MeshInstance3D

const CELLAR_DOOR := Vector3i(0, 5, 5)
const EMBER_POS := Vector3(5.0, 0.28, 3.4)


func build() -> void:
	_environment()
	_ground()
	world = SplatWorld.new()
	world.name = "World"
	add_child(world)
	world.register_tiles(SplatCatalog.tiles())
	_paint()
	for run in STAIRS:
		for z in [run.bot, run.top]:
			world.walk[Vector3i(run.level, run.x, z)] = true
			world.walk[Vector3i(run.level + 1, run.x, z)] = true

	actor = SpliteActor.new()
	actor.name = "Player"
	actor.splite = SplatCatalog.player_splite()
	actor.position = Vector3(8.0, 0.0, 11.0)
	add_child(actor)

	cam = SplatCameraRig.new()
	cam.name = "Cam"
	cam.target = actor
	add_child(cam)

	var field := DistortionField.new()
	field.name = "DreamPuddle"
	field.position = Vector3(13.0, 0.0, 10.0)
	field.mode = DistortionField.Mode.SWIRL
	field.radius = 1.7
	field.strength = 0.55
	add_child(field)
	world.fields.append(field)

	world.sun_dir = SplatWorld.AFTERNOON_SUN
	_aim_sun()
	_lock_cellar()
	_spawn_ember()
	place(8.0, 11.0, 0)
	world._rebuild_hulls()


func place(x: float, z: float, level: int, facing: float = 1.0) -> void:
	player_level = level
	elev = float(level)
	current_run = null
	actor.facing = facing
	actor.position = Vector3(x, world.floor_y(elev), z)
	_update_room()
	if cam:
		cam.snap()
	world.set_actor(actor.current_cloud(), actor.current_xform())
	world.refresh(Time.get_ticks_msec() * 0.001)


func slide(x: float, z: float, level: int) -> void:
	# Same pose update as place(), but the camera keeps following.
	player_level = level
	elev = float(level)
	current_run = null
	actor.position = Vector3(x, world.floor_y(elev), z)


func set_walking(on: bool) -> void:
	actor.playing = on
	actor.clip = &"walk" if on else &"idle"


func tick(_delta: float) -> void:
	if current_run != null:
		_update_stairs()
		actor.position.y = world.floor_y(elev)
	_update_room()
	if ember:
		ember.visible = (not ember_taken) and world.active_rooms.has("CELLAR_IN")
	world.set_actor(actor.current_cloud(), actor.current_xform())
	world.refresh(Time.get_ticks_msec() * 0.001)


func interact_hint() -> String:
	match _nearest_interact():
		"door":
			return "E   open the cellar"
		"ember":
			return "E   take the ember"
	return ""


func objective() -> String:
	if not cellar_open:
		return "Open the cellar door on the south face of the house."
	if not ember_taken:
		return "Step inside and take the ember."
	return "That’s the scene. Walk the garden, the brush, the walkway."


func try_interact() -> String:
	match _nearest_interact():
		"door":
			cellar_open = true
			world.walk[CELLAR_DOOR] = true
			return "door"
		"ember":
			ember_taken = true
			if ember:
				ember.visible = false
			return "ember"
	return ""


func _nearest_interact() -> String:
	var p := Vector2(actor.position.x, actor.position.z)
	var room := world.room_at(player_level, p)
	if not cellar_open and player_level == 0 and room != "CELLAR_IN":
		var door := Vector2(float(CELLAR_DOOR.y), float(CELLAR_DOOR.z))
		# Only from the south lawn, not through the wall from inside.
		if actor.position.z > float(CELLAR_DOOR.z) + 0.2 and p.distance_to(door) < 1.25:
			return "door"
	if not ember_taken and room == "CELLAR_IN":
		if p.distance_to(Vector2(EMBER_POS.x, EMBER_POS.z)) < 1.05:
			return "ember"
	return ""


func _lock_cellar() -> void:
	cellar_open = false
	world.walk.erase(CELLAR_DOOR)


func _spawn_ember() -> void:
	ember = MeshInstance3D.new()
	ember.name = "Ember"
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	ember.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.08)
	mat.emission_energy_multiplier = 2.4
	ember.material_override = mat
	ember.position = EMBER_POS
	ember.visible = false
	add_child(ember)


func try_move(step: Vector3) -> void:
	var levels := [player_level] if current_run == null else [current_run.level, current_run.level + 1]
	var np := actor.position + Vector3(step.x, 0, 0)
	if _can_stand(np, levels):
		actor.position = np
	np = actor.position + Vector3(0, 0, step.z)
	if _can_stand(np, levels):
		actor.position = np
	_update_stairs()
	actor.position.y = world.floor_y(elev)


func _paint() -> void:
	for level in MAPS:
		var rows: Array = MAPS[level]
		for z in rows.size():
			var row: String = rows[z]
			for x in row.length():
				var ch := row[x]
				if ch == " " or ch == "":
					continue
				var tile := _tile_for(ch)
				if tile == "":
					continue
				world.set_cell(level, x, z, tile, _room_of(level, x, z, ch))
				if ch == "T":
					torch = OmniLight3D.new()
					torch.light_color = Color(1.0, 0.72, 0.4)
					torch.light_energy = 2.4
					torch.omni_range = 4.5
					torch.shadow_enabled = true
					torch.position = world.cell_origin(level, x, z) + Vector3(0, 0.8, 0)
					world.add_child(torch)


func _tile_for(ch: String) -> String:
	match ch:
		".": return "grass"
		"b": return "brush"
		"B": return "brush_heavy"
		"t": return "trunk"
		"v": return "canopy"
		"w", "#": return "wall"
		"d": return "door"
		"c", "T": return "planks"
		"^": return "stair"
		"P", "L": return "stone"
		"h": return "planks"
		"R": return "roof"
	return ""


func _room_of(level: int, x: int, z: int, ch: String) -> String:
	if level == 0:
		if ch == "c" or ch == "T":
			return "CELLAR_IN"
		if (ch == "w" or ch == "d") and x >= 2 and x <= 7 and z >= 2 and z <= 5:
			return "CWALLS"
	elif level == 2:
		if ch == "h":
			return "HOUSE_IN"
		if ch == "w" or ch == "d":
			return "HWALLS"
	elif level == 3:
		return "ROOFH"
	return "OUTSIDE"


func _ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.2, 14.2)
	ground.mesh = plane
	ground.position = Vector3(7.5, -0.04, 6.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.44, 0.24)
	mat.roughness = 0.92
	ground.material_override = mat
	add_child(ground)


func _aim_sun() -> void:
	if sun_light == null or world == null:
		return
	var toward := world.sun_dir.normalized()
	# DirectionalLight emits along -Z; that must be the incoming ray (-toward).
	sun_light.basis = Basis.looking_at(-toward, Vector3.UP)


func _environment() -> void:
	sun_light = DirectionalLight3D.new()
	sun_light.name = "Sun"
	sun_light.light_color = Color(1.0, 0.78, 0.52)
	sun_light.light_energy = 1.35
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 56.0
	sun_light.light_angular_distance = 1.8
	add_child(sun_light)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.62, 0.82)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-18, -120, 0)
	add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.62, 0.58)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.68, 0.58)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.76, 0.80)
	env.fog_density = 0.008
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	we.environment = env
	add_child(we)


func _can_stand(pos: Vector3, levels: Array) -> bool:
	for off in [Vector2(-0.16, -0.12), Vector2(0.16, -0.12), Vector2(-0.16, 0.14), Vector2(0.16, 0.14)]:
		var ok := false
		for l in levels:
			if world.is_walkable(int(l), Vector2(pos.x + off.x, pos.z + off.y)):
				ok = true
				break
		if not ok:
			return false
	return true


func _run_at(tile: Vector2i) -> Variant:
	for run in STAIRS:
		if tile.x == run.x and (tile.y == run.bot or tile.y == run.top):
			if player_level == run.level or player_level == run.level + 1:
				return run
	return null


func _update_stairs() -> void:
	var tile := Vector2i(int(round(actor.position.x)), int(round(actor.position.z)))
	var run = _run_at(tile)
	if run != null:
		current_run = run
		var span := 2.0
		var frac: float
		if run.exit == "N":
			frac = clampf((float(run.bot) + 0.5 - actor.position.z) / span, 0.0, 1.0)
		else:
			frac = clampf((actor.position.z - (float(run.top) - 0.5)) / span, 0.0, 1.0)
		player_level = run.level if frac < 0.5 else run.level + 1
		elev = float(run.level) + frac
	else:
		if current_run != null:
			player_level = current_run.level + 1 if elev > current_run.level + 0.5 else current_run.level
			current_run = null
		elev = float(player_level)


func _update_room() -> void:
	var room := world.room_at(player_level, Vector2(actor.position.x, actor.position.z))
	var visible: Array
	match room:
		"CELLAR_IN":
			visible = ["CELLAR_IN", "CWALLS"]
		"HOUSE_IN":
			visible = ["HOUSE_IN", "HWALLS"]
		_:
			visible = ["OUTSIDE", "CWALLS", "HWALLS", "ROOFH"]
	world.set_active_rooms(visible)
	if torch:
		torch.visible = world.active_rooms.has("CELLAR_IN")
