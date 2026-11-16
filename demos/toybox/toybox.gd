extends Node3D
## Interactive style demo of the garden scene. One scene, then stop.

const WALK_SPEED := 3.4

var diorama: DemoDiorama
var objective: Label
var prompt: Label
var meta: Label
var toast: Label
var toast_left := 0.0
var shot_path := ""
var shot_frames := 40


func _ready() -> void:
	diorama = DemoDiorama.new()
	diorama.name = "Diorama"
	add_child(diorama)
	diorama.build()
	_build_hud()
	_bind_keys()
	_parse_args()
	if shot_path != "":
		_take_shot()


func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var moving := dir.length() > 0.1
	diorama.set_walking(moving)
	if moving:
		if abs(dir.x) > 0.1:
			diorama.actor.facing = sign(dir.x)
		var step := dir.normalized() * WALK_SPEED * delta
		diorama.try_move(Vector3(step.x, 0, step.y))
	if Input.is_action_just_pressed("ui_accept"):
		var what := diorama.try_interact()
		if what == "door":
			_toast("The cellar is open. The torch does not exist until you step in.")
		elif what == "ember":
			_toast("Ember taken. The scene is finished — wander if you want.")
	diorama.tick(delta)
	if toast_left > 0.0:
		toast_left -= delta
		toast.visible = toast_left > 0.0
	if objective:
		objective.text = diorama.objective()
	if prompt:
		var hint := diorama.interact_hint()
		prompt.text = hint
		prompt.visible = hint != ""
	if meta:
		meta.text = "WASD move   E interact   stairs climb    %d fps   level %.1f" % [
			Engine.get_frames_per_second(), diorama.elev
		]


func _toast(msg: String) -> void:
	toast.text = msg
	toast.visible = true
	toast_left = 4.0


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	objective = Label.new()
	objective.position = Vector2(16, 12)
	objective.add_theme_font_size_override("font_size", 18)
	objective.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	layer.add_child(objective)
	prompt = Label.new()
	prompt.position = Vector2(16, 40)
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	layer.add_child(prompt)
	toast = Label.new()
	toast.position = Vector2(16, 68)
	toast.add_theme_font_size_override("font_size", 15)
	toast.add_theme_color_override("font_color", Color(0.88, 0.88, 0.86, 0.9))
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	toast.visible = false
	layer.add_child(toast)
	meta = Label.new()
	meta.position = Vector2(16, 690)
	meta.add_theme_font_size_override("font_size", 13)
	meta.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	layer.add_child(meta)


func _bind_keys() -> void:
	var keys := {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S, "ui_accept": KEY_E}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a.begins_with("--px="):
			diorama.actor.position.x = float(a.substr(5))
		elif a.begins_with("--pz="):
			diorama.actor.position.z = float(a.substr(5))
		elif a.begins_with("--plevel="):
			diorama.place(diorama.actor.position.x, diorama.actor.position.z, int(a.substr(9)))


func _take_shot() -> void:
	for i in shot_frames:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	get_tree().quit()
