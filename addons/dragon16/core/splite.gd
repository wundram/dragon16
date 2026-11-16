class_name Splite
extends Resource
## A sprite whose frames are SplatClouds.

@export var id: StringName = &""
@export var fps: float = 10.0
@export var hitbox: AABB = AABB(Vector3(-0.2, 0.0, -0.2), Vector3(0.4, 0.7, 0.4))
@export var shadow_hull: AABB = AABB(Vector3(-0.22, 0.0, -0.18), Vector3(0.44, 0.04, 0.36))
@export var cast_model: SplatTile.CastModel = SplatTile.CastModel.BLOB
@export var receive_shadow: bool = false
@export var cast_height: float = 0.72
## clip name -> Array[SplatCloud]
@export var clips: Dictionary = {}


func frame_count(clip: StringName = &"idle") -> int:
	var frames: Array = clips.get(clip, [])
	return frames.size()


func frame(clip: StringName, index: int) -> SplatCloud:
	var frames: Array = clips.get(clip, [])
	if frames.is_empty():
		return null
	return frames[index % frames.size()]
