extends Node3D
## Zero-input walk through every implemented feature. Quits cleanly at the end.
##
##   Godot --path ~/dragon16 res://demos/tour/tour.tscn
##   Godot --path ~/dragon16 res://demos/tour/tour.tscn -- --hold-scale=0.25

var diorama: DemoDiorama
var tour: FeatureTour


func _ready() -> void:
	diorama = DemoDiorama.new()
	diorama.name = "Diorama"
	add_child(diorama)
	diorama.build()
	tour = FeatureTour.new()
	tour.name = "Tour"
	add_child(tour)
	# One settle frame so shaders compile before the first caption hold.
	await get_tree().process_frame
	await get_tree().process_frame
	tour.play(TourBeats.all(), _place, _scrub)


func _place(x: float, z: float, level: int, facing: float, moving: bool) -> void:
	diorama.place(x, z, level, facing)
	diorama.set_walking(moving)


func _scrub(x: float, z: float, level: int) -> void:
	diorama.slide(x, z, level)


func _process(delta: float) -> void:
	if diorama:
		diorama.tick(delta)
