# Dream Slice — Demo Spec
## Extreme verticality + layered-strata tiles

Companion to `engine-vision.md`. This is the spec for the one-shot demo. Placeholder
programmer art (procedurally generated) — the demo proves rendering and feel, not style.

---

## 1. Motion doctrine: deliberate apparent motion only

Every moving thing on screen is either **first-order** (a sprite or camera actually
moving) or **second-order** (a designed artifact of filtering/parallax/scale that
*intentionally* tricks the eye — e.g. strata shear as the camera pans). Everything
else — pixel boil, moiré, crawling staircase edges, shimmer from bad resampling —
is **spatiotemporal aliasing** and is treated as a bug, because involuntary motion
captures the eye's attention (peripheral motion detection) and breaks the dream.

Rules that enforce this:
- One global pixel lattice per stratum; all art at 1x; no nearest-neighbor
  non-integer scaling anywhere.
- Compositing uses the texel-AA sampler (sharp interiors, one-screen-pixel-wide
  seams) so subpixel motion produces smooth luminance transitions, never edge pops.
- Strata scale factors are tiny (≤4%) and constant — their pixels are marginally
  larger, which the eye reads as *nearer*, not as *wrong-sized*.
- No realtime re-quantization of moving 3D during normal play (that's what causes
  boil); 3D→pixel content is baked to frames.

### The two legitimate pixel percepts

- **Object-locked pixels** ("made of pixels"): quantization travels with the object
  (baked sprite frames composited smoothly). Reads as a solid thing whose surface
  is pixel texture. Default for the normal world.
- **Screen-locked veil** ("real object behind a pixel screen"): a smoothly moving
  underlying image is area-sampled into a *fixed* screen lattice each frame with
  correct prefiltering. Temporal integration lets the eye reconstruct the object
  behind the lattice — the screen-door percept. Requires temporal coherence and
  proper downsampling (supersample → box/gaussian filter → quantize); without
  prefiltering it degenerates into boil. Reserved as an *otherworldly* effect
  (dream sequences, the Ultimate Island, boss reveals).

What makes fake-pixel looks read as fake instantly: inconsistent lattices — mixed
pixel sizes, rotated or misaligned grids, non-integer scales — and mushy bilinear
filtering. Consistency of the lattice is the whole fiction.

---

## 2. The strata model

Everything drawable belongs to a triple **(level, band, y)**:

- **level** `l ∈ {0, 0.5, 1, 1.5, 2, 2.5}` — three floors, each with a half-level.
  Internally levels are integers 0–5; floor spacing `H` art-pixels of screen
  elevation per level (upper levels draw offset upward by `l·H`).
- **band** — the draw-order slot within a level:

  | band | contents | nominal height above floor |
  |---|---|---|
  | 0 | tile **base** (ground, trunks, wall faces, stems) | 0 px |
  | 1 | **sprite lower** (body/feet slices of characters) | ~2 px |
  | 2 | tile **mid stratum** (low foliage, vines, railings) | ~8 px |
  | 3 | **sprite upper** (head/torso slices) | ~10 px |
  | 4 | tile **top stratum** (canopy, dense brush tops) | ~16 px |

- **y** — row sort within a band (static for tiles; sprites use their feet y).

Global draw order: ascending `(level, band, y)`.

### What this buys

- **The sink effect**: a character on a brush tile shows body over the stems
  (band 1 > 0), gets waist-hidden by mid foliage (band 2 > 1), face still visible
  (band 3 > 2) — unless the tile uses the top stratum (band 4), which hides even
  the head. Dense brush conceals; light brush reveals. Alpha blending throughout.
- **Sprites are volumetric too**: the two sprite slices sit at different strata
  heights, so characters get the same micro-parallax as the world — coarse
  sprite-stacking with two slices.
- Known simplification: within one level, all of band 4 draws over all of band 3,
  so classic N/S y-sort occlusion against tall *walls* is approximated by putting
  wall caps / canopies in upper bands. Good enough for the slice; a per-row
  interleave `(level, y, band)` is the future refinement if needed.

### Strata parallax

Each (level, band) layer is rendered scaled about the screen center by
`s = 1 + k·(l·H + band_height)` with k tuned so the topmost layer is ~3–4% larger.
As the camera pans, layers shear against each other in proportion to height —
the second-order depth cue. Implemented as a per-layer 2D transform
(`translate(center)·scale(s)·translate(−center)`), recomputed each frame from the
camera; the texel-AA sampler keeps the scaled art sharp.

---

## 2b. Projection & cast shadows

**View axis**: true top-down, tilted only 5–10° toward the **SW** of the player's
vertical axis. Consequences:

- Elevation is a *small NE screen displacement*, not a big northward shift:
  each level offsets its layer by `LEVEL_OFF ≈ (+5, −5)` px (a full floor =
  ~(10, −10)). Floors nearly coincide in screen space; depth is carried by
  parallax shear, occlusion, and shadows — not by oblique layout.
- Vertical surfaces compress to thin strips: a wall tile is mostly **cap**,
  shifted NE by its height, exposing a ~10px **south face strip** and a
  ~10px **west face strip** (the two faces a SW viewpoint sees).

**Cast shadows** are the primary 3D cue in this projection:

- Sun from the NW → shadows fall SE. Shadow displacement is
  `SHADOW_STEP ≈ (7, 7)` px **per level of height difference** between the
  caster's top and the receiving surface — so the same wall casts a short
  shadow on its own floor and a longer, shifted one when it falls to a lower
  level, exactly as real geometry would.
- **Shadow masks**: every tile/sprite type declares a mask for its shadow —
  in practice its own silhouette texture drawn with a dark modulate
  (canopy blobs cast blob shadows, wall caps cast square shadows, sprites
  cast a soft ellipse or a flattened silhouette). No separate art needed
  until real art arrives; then masks become authored alpha images.
- **Shadow band**: each level gets a band between tile-base and sprite-lower
  (band order per level is now base / shadows / sprite-lower / tile-mid /
  sprite-upper / tile-top). Shadows on a plane share that plane's parallax
  height, so they never shear against the floor they lie on.
- **Cross-level casting**: an elevated floor tile casts onto the *highest*
  lower plane that exists beneath its offset footprint; platform interiors
  are naturally hidden by the platform itself in draw order, so shadows
  emerge visually at edges — balconies, walkways, and roofs get correct
  SE-shifted drop shadows on the ground below.
- Shadows are **not** cast into interior rooms (CELLAR_IN / HOUSE_IN);
  those follow the room-visibility rule instead.

## 3. Room visibility (the rendering-as-knowledge rule)

The map is partitioned into **rooms** (a level range + tile region + adjacency
list through openings: doors, stairwells, holes, balcony edges). Each frame the
**active set** = the player's room plus rooms reachable through openings the
player can currently see through.

Only active rooms are drawn. Deliberate consequence: a bright light source in a
sealed room below you does not exist — no leak through translucent tiles, no
glow through floorboards — because that geometry is simply not rendered. Light
is knowledge; entering the room *reveals* it. (This is also the performance
model and, tuned right, a source of the creepy dream-reveal moments.)

Lights are scoped to their room's bands (z-ranges) so an active room's torch
cannot spill onto strata of other levels.

---

## 4. Demo content (one connected diorama)

- **Ground (l=0)**: garden — grass, path, brush field demonstrating the sink
  effect (light brush → waist-deep; heavy brush → fully hidden), trees with
  trunk in band 0 and canopy split across bands 2/4.
- **Half-landing (l=1)** via stairs, then **Floor 1 (l=2)**: interior room +
  an open walkway with a **hole/balcony** looking down at the garden — the
  money shot for strata parallax across three+ levels.
- **Sealed ground-floor room with a torch** under the walkway: invisible (and
  unlit) while walking above it; entering through its door activates and
  reveals it — demonstrates the visibility rule.
- **Floor 1 half-level (l=3)** ledge, then **Floor 2 / roof (l=4–5)**: highest
  vantage over everything — maximum layer count on screen.
- Player: two-slice procedural chibi; 8–12fps walk frames, 120Hz motion.
- Camera: smoothed follow, slow enough pans to *see* the strata shear.

## 5. Success criteria

1. Panning the camera produces visible, calm depth-shear between strata and
   between floors; no shimmer, boil, or moiré anywhere.
2. Walking into brush produces the sink effect through all three tile strata.
3. Standing on the walkway: sealed room below contributes nothing (no glow);
   stepping through its door reveals it with its torchlight.
4. Three levels plus a half-level visibly stacked in one screen from the roof.
5. Solid 120 fps on ProMotion at native Retina resolution.
