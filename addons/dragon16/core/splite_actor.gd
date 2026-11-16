@tool
class_name SpliteActor
extends Node3D
## Places a Splite in the world and advances its clip.

@export var splite: Splite
@export var clip: StringName = &"idle"
@export var playing: bool = false

var facing := 1.0
var _time := 0.0
var _hull: MeshInstance3D


func _ready() -> void:
	_hull = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.32, 0.08, 0.32)
	_hull.mesh = box
	_hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_hull.position = Vector3(0.0, 0.04, 0.0)
	add_child(_hull)


func _process(delta: float) -> void:
	if playing:
		_time += delta
	else:
		_time = 0.0


func current_cloud() -> SplatCloud:
	if splite == null:
		return null
	var use_clip := clip if playing else &"idle"
	if splite.frame_count(use_clip) == 0:
		use_clip = &"idle"
	var fps := maxf(splite.fps, 0.01)
	var idx := int(_time * fps)
	return splite.frame(use_clip, idx)


func current_xform() -> Transform3D:
	var b := Basis.IDENTITY
	if facing < 0.0:
		b = Basis.from_euler(Vector3(0.0, PI, 0.0))
	return Transform3D(b, global_position)
