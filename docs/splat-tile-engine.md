# Dragon16 — Splat-Tile Engine

Godot 4 plugin. Top-down tile RPG world model, rendered as authored
Gaussian splat volumes. Not a photoreal 3DGS viewer. Not a custom engine.

This is the source of truth. `engine-vision.md` and `dream-slice-spec.md`
are the July 2026 pixel-compositor lineage; what they *proved* is listed
in §8. The identity has moved: tiles and sprites *are* volumetric splat
clouds.

---

## 1. What this is

A 16-bit-era RPG camera and grammar (Final Fantasy VI, Ultima, terminal
Rogue) whose *pixels* have been replaced by small, authored 3D Gaussian
clouds. The viewpoint is locked almost straight down. The art is
representational and physical — toys, paint, plastic models — not a
photograph of a place.

Three primitives, one depth buffer:

| Primitive | Role | Extra data |
|---|---|---|
| **Tile** | Grid cell of scenery | AABB, optional **mesh surface**, optional splat dressing, walkability, room, cut-away policy |
| **Splite** | Sprite made of splat frames | Animation clips, hitboxes, hull |
| **Surface** | Ordinary Godot mesh | Floors, walls, water, mirrors, UI-in-world. Writes real depth. |

Splats are the *volume* — brush, canopy, paint, the character. Meshes
are the *planes* — anything that must be hard, reflective, printable,
or a depth occluder. A tile may be either, or both (stone slab mesh
with grit/moss as a cloud). They composite through the hardware
z-buffer, not through a private splat sort.

A character standing in brush is still the same matter as the foliage.
A character standing *under a balcony* is a depth problem: the balcony
is a mesh (and/or cloud) closer to the camera, and the engine cuts it
away. See §4b.

On top of that, first-class effects: particles, volumetric fog, lights,
and **spatial distortion fields** (the thing 2D pixels cannot do).

**UI and text stay out of this buffer.** HUD, menus, dialogue, and
captions are `CanvasLayer` (screen space). Floating world labels
(names, damage) are optional 3D quads that *may* depth-test; they are
not splat clouds and they are not tiles.

### What it is not

- Not photoreal capture (no phone-scan rooms as the authoring path).
- Not a general 3DGS engine. The camera never leaves a narrow cone
  around vertical, and the world scale is constant.
- Not a replacement for Godot. The plugin is the *language* (tiles,
  splites, rooms, the locked camera, the splat batch). Godot is the
  host: editor, input, lights, particles, audio, physics, export.

Community viewers such as [gdgs](https://github.com/ReconWorldLab/godot-gaussian-splatting)
solve "drop a million-splat capture into a 3D scene." Wrong problem.
We author hundreds of Gaussians per tile, instance them, and style them.
If we later steal a compute rasterizer, we steal the *inner loop*, not
the product shape.

---

## 2. Mood

Two references, neither to copy literally:

- **Clair Obscur: Expedition 33** — abstract paint as matter. High
  impact, physical, not "this is a photo of a person."
- **Zelda: Link's Awakening (Switch)** — plastic-model tilt-shift.
  Real enough to touch, small enough to be a toy. Tactile, responsive.

The graphics should feel like you are playing with objects that have
weight and volume, while still reading as *icons* of grass, a wall, a
person. Smooth, present, slightly impossible.

Style knobs on the batcher, not per-asset art direction (yet):

- `softness` — paint (soft, overlapping) ↔ plastic (tighter kernels)
- tilt-shift DOF on the camera
- shadow *hulls* (simple boxes/capsules) while the eye sees Gaussians
- optional palette / grade as a global look, not a pixel lattice

---

## 3. Camera contract (the optimization)

Everything about cost and authoring follows from a locked camera:

- **True top-down**, tilted ~8–12° toward the SW of the player's
  vertical axis. Elevation is a small NE screen shift plus real height.
- **Perspective, not ortho.** Ortho has zero motion parallax — a pan
  cannot shear. The camera sits close (~8 tiles up) with a wide lens
  (~64° FOV) so upper floors, canopies, and wall caps slide against
  the ground when you walk. That *is* the 3D. Height and FOV are the
  exaggeration knobs; stay inside a cone of about ±30° of vertical
  (no undersides, no horizon).
- **Consistent world scale.** One tile is one world unit. A roof tile
  is the same object whether you stand on it or look down from a
  higher ledge; perspective shrinks it, the asset does not.
- Multiple walkable **levels** stacked in Y. Stairs interpolate
  elevation. Verticality is real geometry, not a 2D draw-offset hack.

Because every cloud is only ever seen from above, we can:

- author / generate from a single cone (no floaters on the underside)
- use anisotropic Gaussians that are flatter than they are tall
- instance the same grass cloud a thousand times
- approximate sort (hashed alpha is legal; popping is a bug only when
  it reads as involuntary motion)

---

## 4. Data model

```
SplatCloud      packed positions, radii, colors, opacities, local AABB
SplatTile       optional cloud + optional visible mesh surface + hull
                + walkable + cutaway policy + room
Splite          named clips of SplatCloud frames + fps + hitbox + hull
SplatWorld      grid[level][cell] -> (tile, room); active room set
SplatBatch      Gaussian quads that *test* the scene depth buffer
SplatCameraRig  locked top-down follow + tilt-shift
DistortionField world-space warp applied to nearby Gaussians
```

A tile's AABB is gameplay truth (walk, occupancy, what a shadow
covers, what cut-away tests against). The cloud is allowed to
*overhang* the AABB — canopies, eaves, brush. A heavy-brush tile is a
tall cloud; a character's lower Gaussians sink into it automatically.

### What is a mesh vs a cloud

| Thing | Mesh surface | Splat cloud |
|---|---|---|
| Floors, walls, stairs, roofs | yes — hard plane, receives light/shadow | optional dressing (grit, moss, paint) |
| Grass, brush, canopy, characters | no (or shadow hull only) | yes — this *is* the matter |
| Water, mirrors | yes — a real plane, the only thing that can reflect | foam / ripples as a cloud on top |
| HUD, text, menus | CanvasLayer (not this table) | never |

Reflections are why water and mirrors cannot be splat-only. A Gaussian
cloud has no surface to bounce a ray off, and our clouds are authored
for a downward cone — a planar reflection looks *up*, at undersides we
did not author. Stylized water is a mesh plane (sky/sun spec, maybe a
Mode-7-style flip of *meshes* above it) plus a distortion field and
splat foam. Do not chase photoreal splat undersides.

The v0 hull, which started life as shadows-only, is the mesh surface
when `surface_visible` is set. Same box, now in the color pass, writing
depth. That is the hybrid: one authoring unit, two draw paths.

### Rooms and visibility

Unchanged from the pixel slice, and more important now (splats are
more expensive than blit):

- The map is partitioned into rooms (level range + cells + openings).
- Each frame the **active set** is the player's room plus rooms they
  can currently see through.
- Inactive rooms are not submitted to the batch. A torch in a sealed
  cellar does not exist until you open the door. Light is knowledge.

### Shadows

Top-down lives or dies on drop shadows. The sun has to be **off-axis**
— a 4pm WNW sun (~33° elevation), not noon. A noon map of a tall box
just stamps a dark square under the object; late afternoon stretches
the drop SE so height reads. Godot’s directional light and the
projected-drop projector share the same `sun_dir`.

We still do **not** ask Gaussians to cast into the shadow map. Splats
use the cheap cast model below. Mesh surfaces both cast and receive
the real 4pm light.

Three cheap pieces:

| Piece | Who | What |
|---|---|---|
| **Cast model** | each tile / splite frame | `none` / `hull` (rounded rect) / `blob` (ellipse). Projected along the sun onto the highest `receive_shadow` plane beneath. Offset = `sun_xz / sun_y × height`, so a roof’s shadow on the garden falls further SE than a bush’s — the old `SHADOW_STEP` rule, from real height. |
| **Receive flag** | mesh surfaces and the ground | If true, drop quads are allowed to land here. Splat dressing does not receive drops in v0 (no cheap map sample on the unshaded gaussian). |
| **Shadow vector** | each Gaussian | Local bent-normal: the direction that splat considers “open sky.” The splat shader does `lit = 0.42 + 0.58 · saturate(dot(vec, sun))`. That is self-shadow / volume, not a drop. Authored later; v0 fills it from position relative to the cloud centroid. |

Cast models stay dumb on purpose. A character is a blob. A wall is a
hull. A tree canopy is a wider blob. A baked silhouette mask is a
later `cast_model` value, not a new pipeline.

Godot directional shadows on visible hulls can stay as contact/ambient
on mesh slabs. They are not the dimensionality cue. The projected drop
is.

### 4b. Three visibility systems

They solve different questions. Do not collapse them into one flag.

| System | Question | Unit | Feel |
|---|---|---|---|
| **Room set** | Does this place exist for the player right now? | whole room | discrete, creepy, “light is knowledge” |
| **Cut-away** | Is this *between the camera and the player*? | tile / surface | dollhouse bite, continuous |
| **Z-buffer** | Is this fragment closer than what is already there? | pixel | meshes vs clouds vs the player |

**Room set** (already shipped): inactive rooms are not submitted. A
torch in a sealed cellar does not exist. Standing *outside* a house
does not draw its interior; standing *inside* does not draw its roof.

**Cut-away**: the camera looks down, so almost every upper floor, eaves,
canopy, and walkway will bury the player. Room visibility is too
coarse (you are not “in” the balcony’s room; you are under it). Per
tile:

```
never        the floor you stand on, water, ground cover
if_above     higher-level floors, roofs, walkways — fade when the
             hull *floor* is above the player and XZ is in radius
             (same-level walls do not open)
if_occludes  canopies / tall props — fade when the visual *top*
             is above the player (a same-level tree can still open)
```

Visual: a soft radius around the player that *discards* the occluder
(a real hole, so it stops writing depth) and fades the rim. Mood is
dollhouse / plastic model, not noisy dither — the upper slab lifts
away around you, like taking the lid off a toy. Popping is a bug;
the radius is a look knob.

This is a **gameplay** test first (stable, no flicker), driven from
the player position as a shader uniform. A later screen-space version
(fade any fragment closer than the player and overlapping them) can
sit on top for props that are not on the grid. Do not start there.

**Z-buffer**: meshes write depth. Splats *test* depth and, in v0, do
not write it (soft kernels writing depth eat the player — we already
hit this). Result: a wall mesh occludes garden clouds behind it; a
balcony mesh occludes the garden until cut-away discards it; the
player’s cloud composites in front of the floor they stand on.

Draw order, once, for every view including reflections later:

1. Opaque mesh surfaces (floors, walls, water plane). Depth write on.
2. Splat clouds, depth test on, depth write off, back-to-front or hashed.
3. Transparents / particles / distortion.
4. Screen-space UI.

Cut-away runs in steps 1–2 as a discard, so the hole is in the depth
buffer too. The player is not “drawn on top”; the lid is gone.

---

## 5. Renderer plan

| Stage | What | Status |
|---|---|---|
| **v0** | Mesh surfaces write depth; Gaussian quads test it; gameplay cut-away; projected drop shadows (cast model + receive flag); per-splat shadow vectors | **now** |
| **v1** | Same API, compute or hardware-raster splat backend; instanced tiles share sort keys; room + frustum cull | next |
| **v2** | Relightable authored clouds; planar water that reflects *meshes*; distortion fields in-shader | later |

v0 is deliberately naive. The API is the engine. The inner loop is
replaceable. Do not couple gameplay nodes to MultiMesh.

**Relighting.** Vanilla 3DGS stores radiance. We will not. Clouds are
authored under flat light; the splat shader does Lambert (and later a
tiny SH) against Godot's lights. Search terms if we need papers:
relightable 3D Gaussians, GS-IR, deferred splat shading.

**Sorting.** Separated props sort per-cloud. Instanced floor tiles
share an order. Stochastic hashed-alpha is allowed and, at this
stylization, often looks better than a perfect sort.

---

## 6. Effects

| Effect | How (v0 / later) |
|---|---|
| Particles | Godot GPUParticles, either on-grid (chunky) or free (dreamy) |
| Fog / godrays | Environment fog now; later a splat-aware height fog |
| Lighting | Godot Directional + Omni; hulls cast, clouds receive (v0 receive is crude) |
| **Distortion** | `DistortionField` nodes warp Gaussian *positions* in world space — swirl, heat, breathe, squash. This is the new toy. Because the primitive has a real 3D position, a field can twist a doorway, make a room inhale, or shear a whole floor without a screen-space gimmick |

Distortion is why the primitive swap is worth it. A 2D pixel sprite
cannot occupy a warped volume. A splat can.

---

## 7. Animation

Same rate mix as the pixel vision, for the same reason:

| Thing | Rate |
|---|---|
| Camera, entity motion, lights, distortion, particles | display refresh |
| Splite *frames* | 8–15 fps, on purpose |
| Otherworldly / dragons | more frames, even continuous, as characterization |

A splite frame is a whole cloud, not a texture. "Walk cycle" means
four clouds. They can be authored by sculpting, by a tiny procedural
rig, or later by baking a 3D model into Gaussians. The runtime does
not care.

---

## 8. What the pixel slice already proved

`prototypes/pixel-slice/` is a finished 2D Godot demo. Keep it. It is
the regression test for the *game* model:

1. Locked top-down with a 5–10° SW bias reads as volume once shadows exist.
2. `(level, occupancy, room)` is enough to walk a six-level diorama.
3. Room visibility is a rendering rule *and* a mood device.
4. The sink-into-brush effect is the thing people feel; bands were a
   2D stand-in for volume. Splats should make this better, not worse.
5. Involuntary motion (boil, moiré, crawling seams) is a bug. The
   texel-AA shader was the 2D fix. The 3D equivalent is stable sort +
   no per-frame re-quantization + no shimmering alpha noise unless we
   *choose* hashed-alpha as a look.

Do not port the 2D compositor. Do port the map, the rooms, the
stairs, and the camera contract.

---

## 9. Repo layout

```
addons/dragon16/          the plugin (this is "the engine")
  plugin.cfg
  core/                   resources + world + camera + actor
  render/                 batcher + gaussian shader + hulls
  effects/                distortion (later: fog helpers)
  editor/                 (empty until a tile painter exists)
demos/shared/             diorama both demos share
demos/toybox/             walkable sandbox
demos/tour/               captioned feature reel (`beats.gd` is the list)
prototypes/pixel-slice/   July 2026 2D proof (self-contained Godot project)
docs/                     this file + historical vision/spec
appendix/                 Dragon Rescue GDD (a future consumer, not the engine)
```

A game (Dragon Rescue or anything else) is a second Godot project that
enables the plugin. The toybox is the engine's unit test you can walk.

---

## 10. Near-term work

The longer sequence (names, pipeline, showcase order) is `roadmap.md`.
Immediate:

1. **One real fitted tile.** CC0 tree → cone-render → splat → import.
   Replace the procedural canopy. If that tile is wrong, fix runtime.
2. **Keep v0 honest.** Walk the sandbox. Mesh floors should feel like
   slabs. Standing under the walkway should open a dollhouse hole.
3. **One authored-looking tile.** A mesh slab + a dressing cloud with
   a hull that matches. Judge plastic vs paint with the batcher knobs.
3. **Distortion field you can stand in.** Warp both the surface and
   the dressing — water is the excuse.
4. **Then** consider a compute backend. Not before.

The creative bottleneck is real; the engine work is to make *placing
a volume in a grid* the only decision a level needs.
