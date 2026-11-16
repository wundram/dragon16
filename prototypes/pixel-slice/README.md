# Dream Slice (historical 2D prototype)

July 2026 proof of the camera contract, strata, room visibility, and
cast shadows — implemented as 2D CanvasItem + texel-AA. The engine
has since moved to volumetric splat tiles; see `../../docs/splat-tile-engine.md`.
This folder is a self-contained Godot project. Open it directly:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dragon16/prototypes/pixel-slice
```


A playable proof of the "nostalgic dream 16-bit" rendering stack described in
`../docs/engine-vision.md` and `../docs/dream-slice-spec.md`. Everything —
tiles, sprites, torch glow — is procedural placeholder art generated at startup;
there are no asset files.

## Run it

Open the `slice/` folder in Godot 4 (installed at `/Applications/Godot.app`),
or from a terminal:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path ~/dragon16/slice
```

**WASD / arrow keys** to move. Stairs climb when you walk along them.

## What to look for

- **Smooth subpixel scrolling** of chunky pixels (texel-AA compositor,
  `texel_aa.gdshader`) — 120 fps on ProMotion.
- **Strata shear**: as you walk, foliage/canopy/wall-cap layers parallax
  subtly against their bases. Every (level, band) layer is scaled about the
  screen center in proportion to its world height.
- **The brush field** south of the house: light brush sinks you to the waist;
  the heavy center swallows you almost entirely.
- **Six height levels**: garden → half-landing → floor 1 walkway (with a
  balcony hole overlooking the garden) → ledge → roof → floating top ledge.
- **Room visibility**: the cellar (door on the south face of the building) is
  not rendered — and its torch casts nothing — until you step inside. Same for
  the house interior on floor 1 (its roof vanishes while you're inside).

## Screenshot harness

```sh
Godot --path . -- --shot=/tmp/out.png --frames=120 --px=13.5 --py=3.5 --plevel=2
```

`--px/--py` are tile coordinates, `--plevel` is the internal level (0–5,
two per floor). Saves the composited window buffer and quits.
