class_name SplatTile
extends Resource
## One cell of scenery: optional mesh surface, optional splat dressing.

enum Cutaway { NEVER, IF_ABOVE, IF_OCCLUDES }
enum CastModel { NONE, HULL, BLOB }

@export var id: StringName = &""
@export var cloud: SplatCloud
## Gameplay / shadow / cut-away hull in tile-local space. Y is up.
@export var hull: AABB = AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 0.2, 1.0))
@export var walkable: bool = true
@export var blocks_los: bool = false
@export var cast_shadow: bool = true
@export var cast_model: CastModel = CastModel.NONE
@export var receive_shadow: bool = true
## Extra height used when the visual volume is taller than the hull (canopy).
@export var cast_height_override: float = -1.0
## Draw the hull as a real mesh (floors, walls, water). Writes depth.
@export var surface_visible: bool = false
@export var surface_color: Color = Color(0.55, 0.55, 0.58)
@export var cutaway: Cutaway = Cutaway.NEVER
## Visual top used by cut-away when the cloud overhangs the hull (canopy).
## Negative means hull.end.y.
@export var cutaway_top: float = -1.0


func cutaway_height() -> float:
	if cutaway_top >= 0.0:
		return cutaway_top
	return hull.position.y + hull.size.y


func cast_height() -> float:
	if cast_height_override >= 0.0:
		return cast_height_override
	return hull.position.y + hull.size.y
