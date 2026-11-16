extends Node2D
# Dragon16 "Dream Slice" — strata renderer demo.
# Projection: true top-down tilted ~8° toward the SW, so elevation is a small
# NE screen shift (LEVEL_OFF per level) and walls are mostly cap with thin
# S/W face strips. Sun from the NW; shadows fall SE, displaced by SHADOW_STEP
# per level of height difference between caster top and receiving plane.
#
# Everything drawable lives at (level, band, y):
#   level 0..5 = three floors, each with a half-level
#   band 0..5  = tile base / shadows / sprite lower / tile mid / sprite upper / tile top
# Each (level, band) layer gets a tiny center-scale parallax proportional to its
# world height, so strata shear against each other as the camera moves.

const TS := 32
const LEVELS := 6
const BANDS := 6
const LEVEL_H := 24.0                  # world height (px) per level, drives parallax
const LEVEL_OFF := Vector2(5, -5)      # screen shift per level (viewpoint SW of vertical)
const SHADOW_STEP := Vector2(7, 7)     # shadow shift per level of height difference
const SHADOW_COL := Color(0, 0, 0, 0.32)
const BAND_H := [0.0, 0.0, 2.0, 8.0, 10.0, 16.0]
const PARALLAX_K := 0.0004
const WALK_SPEED := 150.0

var rng := RandomNumberGenerator.new()
var tex := {}
var shader_mat: ShaderMaterial
var shadow_mat: ShaderMaterial
var containers := {}   # containers[level][band] -> Node2D (carries parallax+elevation)
var canvases := {}     # canvases[level][band] -> TileCanvas
var walk := {}         # walk[level] -> {Vector2i: true}
var placed := {}       # placed[level] -> {Vector2i: map char}
var proom := {}        # proom[level] -> {Vector2i: room name}
var stair_runs := []   # {level, col, top, bot, exit ("N"/"S")}
var visible_rooms := {}
var active_rooms := {}
var player_room := ""

var player_level := 0
var parent_level := -1
var player_pos := Vector2.ZERO
var current_run = null
var player_frac := 0.0
var elev_l := 0.0      # elevation in level units (float, fractional on stairs)
var body: Sprite2D
var head: Sprite2D
var shadow_s: Sprite2D
var cam: Camera2D
var torch_light: PointLight2D
var walk_time := 0.0
var moving := false
var facing := 1.0
var hud: Label

# --- screenshot harness ---
var shot_path := ""
var shot_frames := 40

class TileCanvas:
	extends Node2D
	var entries := {}  # room -> [{t: Texture2D, r: Rect2, m: Color}]
	var main_ref: Node
	func add_entry(room: String, t: Texture2D, r: Rect2, m := Color.WHITE) -> void:
		if not entries.has(room):
			entries[room] = []
		entries[room].append({"t": t, "r": r, "m": m})
	func _draw() -> void:
		for room in entries:
			if main_ref.active_rooms.has(room):
				for e in entries[room]:
					draw_texture_rect(e.t, e.r, false, e.m)

# ============================== MAPS ==============================
# Legend: . grass  b brush-light  B brush-heavy  t trunk  v canopy-overhang
#         w wall  d door  c cellar-floor  T torch  # cliff border
#         ^ stairs (climb north)  z stairs (climb south)
#         P stone platform  h house floor  L ledge  R roof

const MAPS := {
	0: [
		"################################",
		"#..............................#",
		"#..wwwwwwww....................#",
		"#..wcTccccw..........vvv.......#",
		"#..wccccccw..........vtv.......#",
		"#..wccccccw..........vvv.......#",
		"#..wwwdwwww....................#",
		"#................^.............#",
		"#................^.............#",
		"#.....bbbbb....................#",
		"#....bbBBBbb...................#",
		"#....bbBBBbb...................#",
		"#.....bbbbb....................#",
		"#..............................#",
		"#......vvv.....................#",
		"#......vtv.....................#",
		"#......vvv.....................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"################################",
	],
	1: [
		"",
		"",
		"",
		"                 ^",
		"                 ^",
		"                PPP",
		"                PPP",
	],
	2: [
		"",
		"",
		"    Pwwwwww PPPPPPP",
		"   ^Pwhhhhw PPPP",
		"   ^Pwhhhhw",
		"   PPwwdwww",
		"   PPPPPPPP",
	],
	3: [
		"  LLLz",
		"  LLLz",
		"  LLL",
	],
	4: [
		"",
		"",
		"     RRRR^R",
		"     RRRR^R",
		"     RRRRRR",
		"     RRRRRR",
	],
	5: [
		"",
		"         LL",
	],
}

const WALKABLE := "bBvcd^zPhLR."
const WALL_CHARS := "wd#"
const FLOOR_CASTERS := "PhRL^z"

func _ready() -> void:
	rng.seed = 16
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = load("res://texel_aa.gdshader")
	shadow_mat = ShaderMaterial.new()
	shadow_mat.shader = load("res://texel_aa_unshaded.gdshader")
	_make_textures()
	_build_layers()
	_build_world()
	_build_shadows()
	_add_doormats()
	_build_player()
	_build_hud()
	_setup_input()

	stair_runs = [
		{"level": 0, "col": 17, "top": 7, "bot": 8, "exit": "N"},
		{"level": 1, "col": 17, "top": 3, "bot": 4, "exit": "N"},
		{"level": 2, "col": 3, "top": 3, "bot": 4, "exit": "N"},
		{"level": 3, "col": 5, "top": 0, "bot": 1, "exit": "S"},
		{"level": 4, "col": 9, "top": 2, "bot": 3, "exit": "N"},
	]
	for run in stair_runs:
		for r in [run.top, run.bot]:
			walk[run.level][Vector2i(run.col, r)] = true
			walk[run.level + 1][Vector2i(run.col, r)] = true

	visible_rooms = {
		"OUTSIDE": ["OUTSIDE", "CWALLS", "HWALLS", "ROOFH"],
		"CELLAR_IN": ["CELLAR_IN", "CWALLS"],
		"HOUSE_IN": ["HOUSE_IN", "HWALLS"],
	}

	player_pos = Vector2(14.5 * TS, 12.5 * TS)
	player_level = 0

	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 4.0
	add_child(cam)
	cam.make_current()

	_parse_args()
	_update_room(true)
	elev_l = player_level
	_update_visuals(0.0)
	cam.position = player_pos + LEVEL_OFF * elev_l
	cam.reset_smoothing()

	if OS.get_cmdline_user_args().has("--debug-entries"):
		_debug_dump()
	if shot_path != "":
		_take_shot()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a.begins_with("--px="):
			player_pos.x = float(a.substr(5)) * TS
		elif a.begins_with("--py="):
			player_pos.y = float(a.substr(5)) * TS
		elif a.begins_with("--plevel="):
			player_level = int(a.substr(9))

func _take_shot() -> void:
	for i in shot_frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	get_tree().quit()

# ============================== TEXTURES ==============================

func _img(w: int, h: int, fill := Color(0, 0, 0, 0)) -> Image:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(fill)
	return im

func _speckle(im: Image, base: Color, amount: float, count: int) -> void:
	for i in count:
		var x := rng.randi_range(0, im.get_width() - 1)
		var y := rng.randi_range(0, im.get_height() - 1)
		var v := rng.randf_range(-amount, amount)
		im.set_pixel(x, y, Color(base.r + v, base.g + v, base.b + v, base.a))

func _blob(im: Image, cx: float, cy: float, rad: float, col: Color) -> void:
	for y in range(max(0, int(cy - rad)), min(im.get_height(), int(cy + rad) + 1)):
		for x in range(max(0, int(cx - rad)), min(im.get_width(), int(cx + rad) + 1)):
			if Vector2(x - cx, y - cy).length() <= rad:
				im.set_pixel(x, y, col)

func _mk(name: String, im: Image) -> void:
	tex[name] = ImageTexture.create_from_image(im)

func _make_textures() -> void:
	# grass
	var g := _img(TS, TS, Color(0.34, 0.52, 0.28))
	_speckle(g, Color(0.34, 0.52, 0.28), 0.05, 260)
	_mk("grass", g)
	# cellar planks
	var pl := _img(TS, TS, Color(0.38, 0.31, 0.25))
	for y in TS:
		if y % 8 == 0:
			for x in TS:
				pl.set_pixel(x, y, Color(0.28, 0.22, 0.18))
	_speckle(pl, Color(0.38, 0.31, 0.25), 0.04, 120)
	_mk("planks", pl)
	# stone platform
	var st := _img(TS, TS, Color(0.52, 0.52, 0.56))
	_speckle(st, Color(0.52, 0.52, 0.56), 0.05, 200)
	for x in TS:
		st.set_pixel(x, 0, Color(0.62, 0.62, 0.66))
		st.set_pixel(x, TS - 1, Color(0.40, 0.40, 0.44))
	_mk("stone", st)
	# roof shingles
	var ro := _img(TS, TS, Color(0.55, 0.30, 0.26))
	for y in TS:
		for x in TS:
			var row := int(y / 6)
			var shift := 4 if row % 2 == 0 else 0
			if y % 6 == 0 or (x + shift) % 8 == 0:
				ro.set_pixel(x, y, Color(0.42, 0.22, 0.19))
	_mk("roof", ro)
	# stairs
	var sr := _img(TS, TS, Color(0.55, 0.55, 0.60))
	for y in TS:
		var shade := 0.65 if (y % 8) < 4 else 0.45
		for x in TS:
			sr.set_pixel(x, y, Color(shade, shade, shade + 0.04))
	_mk("stair", sr)
	# wall cap + thin S/W face strips (near-top-down projection)
	var wc := _img(TS, TS, Color(0.64, 0.62, 0.60))
	_speckle(wc, Color(0.64, 0.62, 0.60), 0.04, 160)
	for x in TS:
		wc.set_pixel(x, 0, Color(0.74, 0.72, 0.70))
		wc.set_pixel(x, TS - 1, Color(0.50, 0.48, 0.46))
	for y in TS:
		wc.set_pixel(0, y, Color(0.74, 0.72, 0.70))
		wc.set_pixel(TS - 1, y, Color(0.50, 0.48, 0.46))
	_mk("wallcap", wc)
	var ws := _img(TS, 10, Color(0.44, 0.42, 0.40))
	for y in 10:
		for x in TS:
			if y == 0 or y == 5 or (x + (8 if y < 5 else 0)) % 16 == 0:
				ws.set_pixel(x, y, Color(0.32, 0.30, 0.29))
	_mk("wallS", ws)
	var ww := _img(10, TS, Color(0.30, 0.29, 0.28))
	for y in TS:
		if y % 8 == 0:
			for x in 10:
				ww.set_pixel(x, y, Color(0.24, 0.23, 0.22))
	_mk("wallW", ww)
	# door: S strip with dark opening + threshold hint
	var ds := Image.new()
	ds.copy_from(ws)
	for y in 10:
		for x in range(8, 24):
			ds.set_pixel(x, y, Color(0.07, 0.06, 0.09))
	_mk("doorS", ds)
	# brush stems (grass + stems)
	var bs := Image.new()
	bs.copy_from(g)
	for i in 10:
		var x := rng.randi_range(2, TS - 3)
		for y in range(rng.randi_range(10, 16), TS):
			bs.set_pixel(x, y, Color(0.20, 0.34, 0.16))
	_mk("brushbase", bs)
	# brush mid / top foliage (alpha blobs)
	var bm := _img(TS, TS)
	for i in 24:
		_blob(bm, rng.randf_range(3, TS - 3), rng.randf_range(3, TS - 3), rng.randf_range(2, 3.5), Color(0.30, 0.50, 0.22))
	_mk("brushmid", bm)
	var bt := _img(TS, TS)
	for i in 34:
		_blob(bt, rng.randf_range(2, TS - 2), rng.randf_range(2, TS - 2), rng.randf_range(2.5, 4.0), Color(0.24, 0.44, 0.18))
	for i in 10:
		_blob(bt, rng.randf_range(4, TS - 4), rng.randf_range(4, TS - 4), rng.randf_range(1.5, 2.5), Color(0.38, 0.58, 0.26))
	_mk("brushtop", bt)
	# canopy mid / top
	var cm := _img(TS, TS)
	for i in 30:
		_blob(cm, rng.randf_range(4, TS - 4), rng.randf_range(4, TS - 4), rng.randf_range(2.5, 4.5), Color(0.22, 0.42, 0.20))
	_mk("canopymid", cm)
	var ct := _img(TS, TS)
	for i in 26:
		_blob(ct, rng.randf_range(4, TS - 4), rng.randf_range(4, TS - 4), rng.randf_range(2.5, 4.0), Color(0.30, 0.52, 0.24))
	for i in 8:
		_blob(ct, rng.randf_range(6, TS - 6), rng.randf_range(6, TS - 6), rng.randf_range(1.5, 2.5), Color(0.44, 0.64, 0.30))
	_mk("canopytop", ct)
	# tree trunk seen from above: a disk
	var tr := _img(TS, TS)
	_blob(tr, 16, 16, 7, Color(0.30, 0.21, 0.14))
	_blob(tr, 15, 15, 5, Color(0.42, 0.30, 0.20))
	_mk("trunk", tr)
	# torch prop (16x24)
	var tp := _img(16, 24)
	for y in range(10, 22):
		for x in range(7, 9):
			tp.set_pixel(x, y, Color(0.40, 0.28, 0.18))
	for i in 6:
		_blob(tp, 8, 7, rng.randf_range(2, 3.5), Color(1.0, 0.65, 0.15))
	_blob(tp, 8, 6, 1.6, Color(1.0, 0.9, 0.5))
	_mk("torch", tp)
	# soft ellipse shadow for sprites
	var sh := _img(24, 12)
	for y in 12:
		for x in 24:
			var d := Vector2((x - 12) / 12.0, (y - 6) / 6.0).length()
			if d < 1.0:
				sh.set_pixel(x, y, Color(0, 0, 0, clamp(1.1 - d, 0.0, 1.0)))
	_mk("shadowblob", sh)
	# player body frames (24x24) + head (20x16)
	for f in 4:
		var b := _img(24, 24)
		var swing: int = [0, 2, 0, -2][f]
		for y in range(2, 14):
			for x in range(7, 17):
				b.set_pixel(x, y, Color(0.30, 0.45, 0.75))
		for y in range(14, 22):
			for x in range(8, 11):
				b.set_pixel(x + (swing if y > 17 else 0), y, Color(0.25, 0.22, 0.30))
			for x in range(13, 16):
				b.set_pixel(x - (swing if y > 17 else 0), y, Color(0.25, 0.22, 0.30))
		_mk("body%d" % f, b)
	var hd := _img(20, 16)
	for y in range(0, 14):
		for x in range(2, 18):
			hd.set_pixel(x, y, Color(0.98, 0.85, 0.72))
	for y in range(0, 6):
		for x in range(1, 19):
			hd.set_pixel(x, y, Color(0.45, 0.30, 0.18))
	for p in [Vector2i(6, 8), Vector2i(13, 8)]:
		hd.set_pixel(p.x, p.y, Color(0.1, 0.1, 0.15))
		hd.set_pixel(p.x, p.y + 1, Color(0.1, 0.1, 0.15))
		hd.set_pixel(p.x + 1, p.y, Color(0.25, 0.35, 0.6))
		hd.set_pixel(p.x + 1, p.y + 1, Color(0.25, 0.35, 0.6))
	_mk("head", hd)

# ============================== WORLD ==============================

func _build_layers() -> void:
	for l in LEVELS:
		containers[l] = {}
		canvases[l] = {}
		walk[l] = {}
		placed[l] = {}
		proom[l] = {}
		for b in BANDS:
			var c := Node2D.new()
			c.name = "L%dB%d" % [l, b]
			c.z_index = l * BANDS + b
			add_child(c)
			containers[l][b] = c
			var tc := TileCanvas.new()
			tc.main_ref = self
			tc.material = shadow_mat if b == 1 else shader_mat
			c.add_child(tc)
			canvases[l][b] = tc

func _room_of(level: int, cx: int, cy: int, ch: String) -> String:
	if level == 0:
		if ch == "c" or ch == "T":
			return "CELLAR_IN"
		if (ch == "w" or ch == "d") and cx >= 3 and cx <= 10 and cy >= 2 and cy <= 6:
			return "CWALLS"
	elif level == 2:
		if ch == "w" or ch == "d":
			return "HWALLS"
		if ch == "h":
			return "HOUSE_IN"
	elif level == 4:
		return "ROOFH"
	return "OUTSIDE"

func _wall(l: int, room: String, p: Vector2, s_tex: String, mod: Color) -> void:
	# near-top-down wall: cap shifted NE by its 2-level height + thin S/W face strips
	canvases[l][0].add_entry(room, tex["wallW"], Rect2(p, Vector2(10, TS)), mod)
	canvases[l][0].add_entry(room, tex[s_tex], Rect2(p + Vector2(0, 22), Vector2(TS, 10)), mod)
	canvases[l][5].add_entry(room, tex["wallcap"], Rect2(p + LEVEL_OFF * 2.0, Vector2(TS, TS)), mod)

func _build_world() -> void:
	var dark := Color(0.5, 0.47, 0.55)
	for l in MAPS:
		var rows: Array = MAPS[l]
		for cy in rows.size():
			var row: String = rows[cy]
			for cx in row.length():
				var ch := row[cx]
				if ch == " ":
					continue
				var p := Vector2(cx * TS, cy * TS)
				var t := Vector2i(cx, cy)
				var room := _room_of(l, cx, cy, ch)
				placed[l][t] = ch
				proom[l][t] = room
				var mod := dark if room == "CELLAR_IN" else Color.WHITE
				match ch:
					".":
						_tile(l, 0, room, "grass", p, mod)
					"c":
						_tile(l, 0, room, "planks", p, dark)
					"T":
						_tile(l, 0, room, "planks", p, dark)
						canvases[l][3].add_entry(room, tex["torch"], Rect2(p + Vector2(8, -2), Vector2(16, 24)))
						torch_light = PointLight2D.new()
						var grad := Gradient.new()
						grad.colors = PackedColorArray([Color(1.0, 0.75, 0.45, 1.0), Color(1.0, 0.55, 0.2, 0.0)])
						var lt := GradientTexture2D.new()
						lt.gradient = grad
						lt.fill = GradientTexture2D.FILL_RADIAL
						lt.fill_from = Vector2(0.5, 0.5)
						lt.fill_to = Vector2(0.5, 0.0)
						lt.width = 256
						lt.height = 256
						torch_light.texture = lt
						torch_light.energy = 1.3
						torch_light.range_z_min = l * BANDS
						torch_light.range_z_max = l * BANDS + 5
						torch_light.position = p + Vector2(16, 8)
						containers[l][3].add_child(torch_light)
					"w":
						_wall(l, room, p, "wallS", mod)
					"d":
						_wall(l, room, p, "doorS", mod)
					"#":
						_wall(l, room, p, "wallS", Color.WHITE)
					"b":
						_tile(l, 0, room, "brushbase", p, mod)
						canvases[l][3].add_entry(room, tex["brushmid"], Rect2(p + Vector2(1, -5), Vector2(TS, TS)), mod)
					"B":
						_tile(l, 0, room, "brushbase", p, mod)
						canvases[l][3].add_entry(room, tex["brushmid"], Rect2(p + Vector2(1, -5), Vector2(TS, TS)), mod)
						canvases[l][5].add_entry(room, tex["brushtop"], Rect2(p + Vector2(2, -10), Vector2(TS, TS)), mod)
						canvases[l][5].add_entry(room, tex["brushtop"], Rect2(p + Vector2(3, -26), Vector2(TS, TS)), mod)
					"v":
						_tile(l, 0, room, "grass", p, mod)
						canvases[l][3].add_entry(room, tex["canopymid"], Rect2(p + Vector2(2, -2), Vector2(TS, TS)), mod)
						canvases[l][5].add_entry(room, tex["canopytop"], Rect2(p + Vector2(4, -4), Vector2(TS, TS)), mod)
					"t":
						_tile(l, 0, room, "grass", p, mod)
						canvases[l][0].add_entry(room, tex["trunk"], Rect2(p, Vector2(TS, TS)), mod)
						canvases[l][3].add_entry(room, tex["canopymid"], Rect2(p + Vector2(2, -2), Vector2(TS, TS)), mod)
						canvases[l][5].add_entry(room, tex["canopytop"], Rect2(p + Vector2(4, -4), Vector2(TS, TS)), mod)
					"^", "z":
						_tile(l, 0, room, "stair", p, mod)
					"P":
						_tile(l, 0, room, "stone", p, mod)
					"h":
						_tile(l, 0, room, "planks", p, Color(1.1, 1.05, 0.95))
					"L":
						_tile(l, 0, room, "stone", p, mod)
					"R":
						_tile(l, 0, room, "roof", p, mod)
				if WALKABLE.contains(ch):
					walk[l][t] = true

func _tile(l: int, band: int, room: String, t: String, p: Vector2, mod := Color.WHITE) -> void:
	canvases[l][band].add_entry(room, tex[t], Rect2(p, Vector2(TS, TS)), mod)

func _shadow_receiver(m: int, world: Vector2) -> Vector2i:
	return Vector2i(int(floor((world.x + TS * 0.5) / TS)), int(floor((world.y + TS * 0.5) / TS)))

func _build_shadows() -> void:
	# Static cast shadows: every mask is the tile's own silhouette, modulated dark,
	# displaced SE by SHADOW_STEP per level of height difference to the receiver.
	for l in placed:
		for t in placed[l]:
			var ch: String = placed[l][t]
			var p := Vector2(t.x * TS, t.y * TS)
			if WALL_CHARS.contains(ch):
				# wall top is 2 levels above its own plane
				var off := SHADOW_STEP * 2.0
				for nt in [t + Vector2i(0, 1), t + Vector2i(1, 0), t + Vector2i(1, 1)]:
					if placed[l].has(nt) and not WALL_CHARS.contains(placed[l][nt]):
						var nroom: String = proom[l][nt]
						if nroom == "CELLAR_IN" or nroom == "HOUSE_IN":
							break  # no sun shadows inside enclosed rooms
						canvases[l][1].add_entry(nroom, tex["wallcap"], Rect2(p + off, Vector2(TS, TS)), SHADOW_COL)
						break
			elif ch == "t" or ch == "v":
				var room: String = proom[l][t]
				canvases[l][1].add_entry(room, tex["canopymid"], Rect2(p + SHADOW_STEP * 0.6, Vector2(TS, TS)), SHADOW_COL)
				canvases[l][1].add_entry(room, tex["canopytop"], Rect2(p + SHADOW_STEP * 1.1, Vector2(TS, TS)), SHADOW_COL)
			if l > 0 and FLOOR_CASTERS.contains(ch):
				# elevated floor tile: cast onto the highest lower plane beneath it
				for m in range(l - 1, -1, -1):
					var off := SHADOW_STEP * float(l - m)
					var rt := _shadow_receiver(m, p + off)
					if placed[m].has(rt):
						var rroom: String = proom[m][rt]
						if rroom == "CELLAR_IN" or rroom == "HOUSE_IN":
							break
						# shadows landing on wall tops would need to draw in the
						# cap band with the cap's visual offset — skip them here;
						# the band-1 quads overhang the caps and read as artifacts
						if WALL_CHARS.contains(placed[m][rt]):
							break
						canvases[m][1].add_entry(rroom, tex["stone"], Rect2(p + off, Vector2(TS, TS)), SHADOW_COL)
						break

func _add_doormats() -> void:
	# The upper floor overhangs ground-level doors in near-top-down projection,
	# so telegraph each door with a worn mat on the tile in front of it.
	var mat_col := Color(0.20, 0.16, 0.12, 0.85)
	canvases[0][0].add_entry("OUTSIDE", tex["stone"], Rect2(Vector2(6 * TS + 6, 7 * TS + 1), Vector2(20, 8)), mat_col)
	canvases[2][0].add_entry("OUTSIDE", tex["stone"], Rect2(Vector2(7 * TS + 6, 6 * TS + 1), Vector2(20, 8)), mat_col)

func _build_player() -> void:
	shadow_s = Sprite2D.new()
	shadow_s.material = shadow_mat
	shadow_s.texture = tex["shadowblob"]
	shadow_s.offset = Vector2(0, -2)
	body = Sprite2D.new()
	body.material = shader_mat
	body.texture = tex["body0"]
	body.offset = Vector2(0, -11)
	head = Sprite2D.new()
	head.material = shader_mat
	head.texture = tex["head"]
	head.offset = Vector2(0, -24)
	_set_parent_level(0)

func _set_parent_level(l: int) -> void:
	if l == parent_level:
		return
	parent_level = l
	for s in [shadow_s, body, head]:
		if s.get_parent() != null:
			s.get_parent().remove_child(s)
	containers[l][1].add_child(shadow_s)
	containers[l][2].add_child(body)
	containers[l][4].add_child(head)

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(8, 6)
	hud.add_theme_font_size_override("font_size", 10)
	hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	cl.add_child(hud)

func _setup_input() -> void:
	var keys := {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S}
	for action in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)

# ============================== SIM ==============================

func _tile_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / TS)), int(floor(p.y / TS)))

func _walkable_at(p: Vector2, levels: Array) -> bool:
	var t := _tile_of(p)
	for l in levels:
		if walk[l].has(t):
			return true
	return false

func _can_stand(p: Vector2, levels: Array) -> bool:
	for off in [Vector2(-6, -2), Vector2(6, -2), Vector2(-6, 4), Vector2(6, 4)]:
		if not _walkable_at(p + off, levels):
			return false
	return true

func _run_at(tile: Vector2i) -> Variant:
	for run in stair_runs:
		if tile.x == run.col and (tile.y == run.top or tile.y == run.bot):
			if player_level == run.level or player_level == run.level + 1:
				return run
	return null

func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	moving = dir.length() > 0.1
	if moving:
		if abs(dir.x) > 0.1:
			facing = sign(dir.x)
		var levels := [player_level] if current_run == null else [current_run.level, current_run.level + 1]
		var step := dir.normalized() * WALK_SPEED * delta
		var np := player_pos + Vector2(step.x, 0)
		if _can_stand(np, levels):
			player_pos = np
		np = player_pos + Vector2(0, step.y)
		if _can_stand(np, levels):
			player_pos = np
		walk_time += delta

	# stair state
	var tile := _tile_of(player_pos)
	var run = _run_at(tile)
	if run != null:
		current_run = run
		var span := 2.0 * TS
		if run.exit == "N":
			player_frac = clamp(((run.bot + 1) * TS - player_pos.y) / span, 0.0, 1.0)
		else:
			player_frac = clamp((player_pos.y - run.top * TS) / span, 0.0, 1.0)
		player_level = run.level if player_frac < 0.5 else run.level + 1
		elev_l = run.level + player_frac
	else:
		if current_run != null:
			player_level = current_run.level + 1 if player_frac > 0.5 else current_run.level
			current_run = null
		elev_l = float(player_level)

	_set_parent_level(player_level)
	_update_room(false)
	_update_visuals(delta)

	if torch_light != null:
		torch_light.energy = 1.2 + 0.15 * sin(Time.get_ticks_msec() * 0.011)

	hud.text = "WASD / arrows to move — stairs go up!   FPS %d   level %.1f" % [Engine.get_frames_per_second(), player_level / 2.0]

func _update_room(force: bool) -> void:
	var room := "OUTSIDE"
	var t := _tile_of(player_pos)
	if player_level == 0 and t.x >= 4 and t.x <= 9 and t.y >= 3 and t.y <= 6:
		room = "CELLAR_IN"
	elif player_level == 2 and t.x >= 6 and t.x <= 9 and t.y >= 3 and t.y <= 5:
		room = "HOUSE_IN"
	if room == player_room and not force:
		return
	player_room = room
	active_rooms = {}
	for r in visible_rooms[room]:
		active_rooms[r] = true
	for l in canvases:
		for b in canvases[l]:
			canvases[l][b].queue_redraw()
	if torch_light != null:
		torch_light.visible = active_rooms.has("CELLAR_IN")

func _update_visuals(delta: float) -> void:
	# player slices (positions are in floor-plane coords; containers add elevation)
	var lift := LEVEL_OFF * (elev_l - parent_level)
	body.position = player_pos + lift
	head.position = player_pos + lift
	shadow_s.position = player_pos + Vector2(3, 3)
	body.flip_h = facing < 0
	head.flip_h = facing < 0
	body.texture = tex["body%d" % (int(walk_time * 10.0) % 4 if moving else 0)]

	cam.position = player_pos + LEVEL_OFF * elev_l

	# strata parallax: scale each layer about the screen center by its height
	var c := cam.get_screen_center_position()
	for l in LEVELS:
		for b in BANDS:
			var h: float = l * LEVEL_H + BAND_H[b]
			var s: float = 1.0 + PARALLAX_K * h
			var xf := Transform2D(Vector2(s, 0), Vector2(0, s), Vector2.ZERO)
			xf.origin = c * (1.0 - s) + LEVEL_OFF * float(l) * s
			containers[l][b].transform = xf

func _debug_dump() -> void:
	var names := {}
	for n in tex:
		names[tex[n]] = n
	var probe := Rect2(Vector2(64, 32), Vector2(140, 80))
	for l in canvases:
		for b in canvases[l]:
			for room in canvases[l][b].entries:
				for e in canvases[l][b].entries[room]:
					if e.r.intersects(probe):
						print("L%d B%d room=%s tex=%s rect=%s mod=%s" % [l, b, room, names.get(e.t, "?"), e.r, e.m])
