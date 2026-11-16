# Dragon16

A Godot 4 plugin: **tile-based top-down RPG world, rendered as volumetric
Gaussian splats**. Tiles have a real bounding box and gameplay metadata.
"Splites" are sprites whose frames are splat clouds. They merge because
they are the same primitive.

Look target: tactile and representational — plastic-model Zelda
(Link's Awakening) and painted-matter Expedition 33 — not photorealism.

This repository is the **engine**. `appendix/Dragon_Rescue_Game_Design_Document.md`
is one possible game that would consume it.

## Run

Godot 4.7 is at `/Applications/Godot.app`. From the repo root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

WASD / arrows to move. **E** to open the cellar and take the ember.
Stairs climb when you walk along them. This garden is the one scene
we finish before any other world.

Feature tour (no input, captions, exits when done). Add a beat in
`demos/tour/beats.gd` when a visible feature ships:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://demos/tour/tour.tscn
```

Headless shot (same harness as the old 2D slice):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --shot=/tmp/toybox.png --frames=40
```

## Layout

| Path | What |
|---|---|
| `addons/dragon16/` | The plugin. This is the engine. |
| `demos/toybox/` | Walkable 3D sandbox. |
| `demos/tour/` | Captioned feature reel. Beats in `beats.gd`. |
| `demos/shared/` | Diorama both demos share. |
| `docs/splat-tile-engine.md` | Architecture (start here). |
| `docs/roadmap.md` | Names, asset pipeline, path to a showable demo. |
| `prototypes/pixel-slice/` | July 2026 2D strata/shadow proof. Self-contained Godot project. |
| `docs/engine-vision.md` | Historical pixel-compositor vision. |
| `appendix/` | Dragon Rescue GDD. |

## Status

v0: naive camera-facing Gaussian quads + shadow hulls + locked top-down
camera + room visibility + a procedural toybox. The API is the point;
the inner loop is replaceable.

Previous work (Claude Code, 2026-07-26 through 2026-07-27) proved the
camera contract, multi-level walk, room-as-visibility, and cast shadows
in 2D. That demo lives in `prototypes/pixel-slice/`.
