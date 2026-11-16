class_name TourBeats
extends RefCounted
## Living feature reel. When a visible engine feature ships, add a beat.
##
## Required keys: id, title, body, x, z, level
## Optional: hold (seconds), pan (east-west walk distance, default 2.4),
##           dir (+1 east / −1 west). Every beat walks so the 3D reads.

static func all() -> Array[Dictionary]:
	return [
		{
			"id": "intro",
			"title": "Dragon16  ·  splat-tile engine",
			"body": "Locked top-down camera. Tiles and sprites are volumetric Gaussian clouds. This reel walks every feature that exists today, then quits.",
			"x": 8.0, "z": 11.0, "level": 0, "hold": 4.4, "pan": 3.2,
		},
		{
			"id": "parallax",
			"title": "Perspective parallax",
			"body": "Close camera, wide lens — not ortho. Canopies, wall caps, and the walkway slide against the ground as you walk. That shear is the 3D.",
			"x": 8.0, "z": 10.4, "level": 0, "hold": 4.6, "pan": 3.6,
		},
		{
			"id": "splat-tiles",
			"title": "Splat tiles",
			"body": "Grass is a cloud of Gaussians, not a flat sprite. Soft volume with a gameplay bounding box.",
			"x": 8.0, "z": 11.0, "level": 0, "pan": 3.2,
		},
		{
			"id": "brush",
			"title": "Volume, not a layer",
			"body": "Heavy brush is a taller cloud. A splite standing in it occupies the same matter — the old 2D “sink” bands fall out of the volume.",
			"x": 6.0, "z": 10.2, "level": 0, "pan": 2.6,
		},
		{
			"id": "mesh-surfaces",
			"title": "Mesh surfaces",
			"body": "Walls and floors are ordinary polygons. They write the depth buffer so splats and the player can occlude against them.",
			"x": 8.0, "z": 7.2, "level": 0, "pan": 2.8,
		},
		{
			"id": "hybrid",
			"title": "Hybrid tile",
			"body": "Stone is a mesh slab plus splat dressing. The hull casts the shadow; the cloud is the surface grit. Same authoring unit, two draw paths.",
			"x": 10.0, "z": 8.0, "level": 0, "pan": 2.2,
		},
		{
			"id": "drop-shadows",
			"title": "Drop shadows",
			"body": "4pm sun, not noon. Each tile and splite has a cheap cast model — hull or blob — projected along that off-axis light. Height stretches the drop east. Self-shadow is a per-splat bent-normal.",
			"x": 8.0, "z": 7.4, "level": 0, "pan": 3.0,
		},
		{
			"id": "splite",
			"title": "Splite",
			"body": "A sprite whose frames are splat clouds. Walk cycle = four clouds at 10 fps. Motion is still smooth at display refresh.",
			"x": 8.0, "z": 9.0, "level": 0, "pan": 3.0,
		},
		{
			"id": "cutaway",
			"title": "Cut-away",
			"body": "The walkway is between the camera and the player, so the engine discards a dollhouse hole. The lid is gone from the depth buffer too — the player is not drawn on top.",
			"x": 11.0, "z": 2.0, "level": 0, "pan": 2.6,
		},
		{
			"id": "verticality",
			"title": "Verticality",
			"body": "Same world, higher level. The garden shrinks by perspective; the tile asset does not change. Stairs interpolate elevation.",
			"x": 11.2, "z": 2.5, "level": 2, "pan": 2.4,
		},
		{
			"id": "room-outside",
			"title": "Room visibility  ·  outside",
			"body": "The cellar is sealed. It is not rendered. Its torch does not exist. Light is knowledge.",
			"x": 4.6, "z": 6.6, "level": 0, "pan": 2.4,
		},
		{
			"id": "room-inside",
			"title": "Room visibility  ·  inside",
			"body": "Step through the door and only this room is submitted. The torch is real now. The garden is gone.",
			"x": 4.5, "z": 4.0, "level": 0, "pan": 1.6,
		},
		{
			"id": "distortion",
			"title": "Distortion field",
			"body": "Nearby Gaussians are warped in world space — swirl, heat, breathe. A 2D pixel sprite cannot occupy a twisted volume. A splat can.",
			"x": 13.0, "z": 10.0, "level": 0, "pan": 2.2,
		},
		{
			"id": "end",
			"title": "That’s everything shipping today",
			"body": "Add a beat in demos/tour/beats.gd when the next visible feature lands. Exiting.",
			"x": 8.0, "z": 11.0, "level": 0, "hold": 2.4, "pan": 2.4,
		},
	]
