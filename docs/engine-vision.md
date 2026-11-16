# Dragon16 Engine Vision
## "Nostalgic Dream 16-bit" Rendering

> Historical (July 2026). Pixel-compositor lineage that produced the
> 2D slice in `prototypes/pixel-slice/`. Current source of truth is
> `docs/splat-tile-engine.md` — same camera/rooms/shadows, splat
> primitives instead of a pixel lattice.


The goal: the game you *remember* SNES games being — multi-floor verticality with
parallax depth, buttery smooth scrolling, dynamic light, particles, and distortion —
while keeping the sharp, chunky pixel-art soul. This doc captures the rendering
architecture and the prior art it draws from.

---

## 1. The core architecture: low-res art, high-res compositor

There are two classic ways to render pixel art, and the choice defines everything:

| | A. Low-res framebuffer | B. High-res compositor (ours) |
|---|---|---|
| How | Render everything to a tiny buffer (e.g. 640×360), upscale at the end | Art stays 1x, but every sprite is composited directly onto the native-resolution buffer at float positions |
| Scrolling | Snaps to art pixels (authentic, chunky) | Subpixel smooth — true smooth scrolling |
| Rotation/scale | Ugly | Clean |
| FX (glow, distortion, particles) | Locked to art grid | Full native resolution |
| Feel | Museum-accurate retro | **The dream memory** |

We choose **B**. This is what Sea of Stars, CrossCode, and The Last Night do.
The framebuffer is the window's native (Retina) resolution — typically 2–4x the
logical art resolution. Logical view ≈ **640×360** with 32px tiles (or 480×270
with 16px tiles for a chunkier look — decide with test scenes).

### The sharpness problem and the texel-AA shader

Compositing 1x art at float positions with **nearest** filtering causes shimmer
and pixel crawl as edges pop between screen pixels. With **bilinear** it goes
blurry. The fix is the well-known "texel anti-aliasing" / "sharp bilinear" /
"fat pixel" shader: sample with bilinear filtering, but compress the blend zone
to exactly one *screen* pixel wide at each texel seam. Pixels stay razor sharp;
edges glide smoothly.

Godot canvas_item version (texture must have **Linear** filtering enabled):

```glsl
shader_type canvas_item;

void fragment() {
    vec2 size = vec2(textureSize(TEXTURE, 0));
    vec2 p = UV * size;
    vec2 seam = floor(p + 0.5);
    vec2 blend = clamp((p - seam + 0.5) / fwidth(p), 0.0, 1.0);
    COLOR = texture(TEXTURE, (seam + blend - 0.5) / size);
}
```

Lineage to study: Inigo Quilez's texture-filtering articles, t3ssel8r's YouTube
devlogs (the deepest treatment, including the calculus of why this works and
subpixel camera motion), RetroArch's `sharp-bilinear` shader family.

Practical notes:
- Apply as a shared CanvasItem material (or via a global default material).
- Atlas bleeding: bilinear sampling reads neighbor texels — enable TileSet
  **texture padding** in Godot; pad sprite sheets by 1px.
- Mipmaps off for world art.
- Non-integer zoom levels are fine with this shader — that's the point.

### Godot project settings

- Stretch mode: **`canvas_items`** (this *is* the high-res compositor mode:
  logical coordinates stay 640×360, rasterization happens at native res).
- Snap 2D transforms/vertices to pixel: **off** (we want subpixel).
- 2D HDR: **on** (enables glow/bloom in 2D).
- Physics/logic at 60 Hz; render uncapped (120 Hz on ProMotion) with physics
  interpolation (built into Godot 4.4+) so motion is smooth at any refresh rate.

---

## 2. Verticality: layered floors with parallax depth

The "impossible dream" feature — multiple walkable floors with real depth cues —
is layering plus tiny per-layer parallax:

- **One TileMapLayer (+ entity container) per floor.** Y-sort within a floor;
  floor order between them. CrossCode is the master class here: top-down maps
  with ~10 height levels, jumping between them, bridges you walk both over and
  under. Its trick: an entity at height *z* is just drawn offset upward by *z*
  and assigned to that layer's draw bucket.
- **Parallax between floors.** Wrap each floor in a `Parallax2D` with
  `scroll_scale` slightly above 1.0 per floor of height (e.g. 1.00 ground, 1.02,
  1.04...). Higher floors track the camera slightly faster → they read as
  *closer to the eye*. This is the subtle monocular depth cue that makes the
  scene feel volumetric. Keep it small; it's a dream, not Mode 7.
- **Multi-layer *tiles*** (your "tiles with subtle 3D" idea): split tall tiles
  into base + cap layers (wall body on floor N's layer, wall top on floor N+1's).
  The cap parallaxes against its own base — cliff edges and rooftops get a
  gentle 3D shear as the camera moves. Cheap, striking.
- **The extreme version — sprite stacking**: render a prop as N horizontal
  slices offset by height (pseudo-voxels). Used by NIUM and a whole GameMaker
  subculture. Optional spice for hero props (windmills, towers), not for
  everything.
- **Clouds/canopy above, chasms below** as additional parallax layers complete
  the sandwich. Drop shadows that stay on the ground layer while the dragon
  flies on an upper layer sell altitude instantly.

---

## 3. Animation strategy: what runs at what rate

The counterintuitive finding from every modern retro game: **do not animate
hand-drawn sprites at 60fps** — it stops reading as pixel art and starts
reading as Flash. The dream look is a *mix* of rates:

| Thing | Rate | How |
|---|---|---|
| Camera, entity movement | 120 Hz (display refresh) | Float positions + texel-AA compositing |
| Character/scenery sprite frames | 8–15 fps | Classic frame animation, chunky on purpose |
| Water, foliage sway, heat shimmer | Continuous | Vertex/fragment shaders on the art |
| Lighting, glow, particles, distortion | 120 Hz, native res | Godot 2D lights, GPUParticles2D, BackBufferCopy shaders |

Two sub-styles for particles — pick per effect:
- **On-grid particles** (quantize positions to the 1x art grid, big square
  pixels): Sea of Stars style, maximally cohesive.
- **Free hi-res particles** (embers, sparkles, magic): HD-2D style, dreamier.
  Mixing both is legitimate and art-directed.

### Characters: two pipelines

1. **Sprite frames** (hand/AI-made) for the player and simple NPCs. 8 directions
   max; interpolated transforms carry the smoothness.
2. **3D-to-pixel for the dragons.** This is the Dead Cells pipeline and it's a
   perfect match for the procedural dragon generator:
   - Build modular low-poly chibi dragon parts in 3D (body/head/horns/wings/tail),
     assemble per DragonData, tint via palette.
   - Render into a low-res `SubViewport` (e.g. 96×96) with an orthographic
     camera, then a post shader: palette quantization + 1px outline.
   - **Bake at load time** to sprite sheets (spin the model, capture frames per
     animation per direction) rather than running live viewports per dragon.
     Result: unlimited procedural variety, any number of animation frames
     ("just generate a huge number of frames" — automated), zero per-frame 3D
     cost during play.
   - Live-viewport rendering stays an option for the few close-ups that want
     smooth 3D motion (vet minigame, sanctuary petting).

---

## 4. Light and atmosphere (the other half of the dream)

- **Normal maps on pixel art** (Sea of Stars, Eastward, Songs of Conquest):
  paint or generate normal maps for tiles/sprites; Godot 2D lights then give
  torches, sunsets, and dragon fire real dimensionality without breaking style.
- **2D glow** via HDR: emissive pixels (fire, crystals, Night Light markings)
  bloom at native res.
- **Distortion**: heat above lava, dragon-wing wind gusts — `BackBufferCopy` +
  UV-offset shader, full res, cheap.
- **Optional final CRT whisper**: a *very* subtle scanline/mask/bloom pass
  (Sonic Mania shipped several). Memories of 16-bit games are memories of CRTs;
  even 10% strength triggers the nostalgia. Make it a toggle.

---

## 5. Prior art index

| Who | What to steal |
|---|---|
| **Octopath Traveler / HD-2D** (Square Enix) | The proof that "dream SNES" sells: sprites + DOF + bloom. Their tilt-shift is 3D; ours is layered 2D |
| **Sea of Stars** (Sabotage) | Strict pixel grid + modern dynamic lighting, normal maps, 60fps camera. Closest overall target |
| **CrossCode** (Radical Fish) | Top-down multi-floor verticality done entirely in 2D layers; jumping between heights |
| **Eastward** (Pixpil) | Custom engine, layered depth, 3D lighting on 2D art, gorgeous atmosphere |
| **Dead Cells** (Motion Twin) | 3D animations baked to pixel sprites — smooth animation + pixel look + cheap iteration |
| **The Last Night** | Pixel art composited in a hi-res HDR/PBR pipeline; parallax as spectacle |
| **t3ssel8r** (YouTube) | The texel-AA math, subpixel camera in pixel-space, realtime 3D-as-pixel-art |
| **Songs of Conquest** | Normal-mapped pixel terrain layers |
| **Sonic Mania** | Tasteful optional CRT filters |
| **Sprite stacking scene** (NIUM etc.) | Pseudo-voxel props from stacked slices |

---

## 5b. Open experiment: Gaussian-splat primitives

Wild-card idea: replace pixel images with per-asset **3D Gaussian splat clouds**
for tiles and sprites. Because the game is top-down, each cloud only needs to
look good from a narrow cone (~±30° around the vertical axis), which makes
authoring/fitting far cheaper than general 3DGS — and buys:

- Free smooth rotation around the up-axis (camera or object) — impossible for
  sprites without huge frame baking.
- True volumetric parallax: brush, canopy, fur, fire as actual fuzzy 3D matter;
  the strata system's hand-authored shear becomes real motion parallax.
- A soft, painterly, *memory-like* look — genuinely oniric, though no longer
  pixel art.

What survives the primitive swap: the (level, band, y) strata order, room
visibility, and — elegantly — the shadow-mask system: an orthographic sun-view
render of a cloud's alpha *is* its shadow mask, auto-baked per asset.

Open problems and current thinking:
- **Relighting**: vanilla 3DGS bakes lighting into SH colors. Game-practical
  approach: author/fit clouds under flat neutral light (SH ≈ albedo), derive
  per-splat normals from the flattened covariance orientation, then do standard
  Lambert against sun + point lights in the splat shader — or defer (render
  albedo/normal/depth, light in 2D). Research keywords: relightable 3D
  Gaussians, GS-IR, deferred splat shading.
- **Sorting/perf**: per-cloud sorting is fine for separated props; instanced
  tiles can share sort order; stochastic (hashed-alpha) splats skip sorting and
  their dither noise reads almost pixel-art-adjacent.
- **Engine**: Godot has no native 3DGS; community addons exist, else a compute
  renderer — this is the one place "custom engine" energy would actually pay.

**The hybrid worth testing first**: render a splat scene through the low-res
quantize/palette pass. That is literally the "real object behind a pixel veil"
percept (§ motion doctrine) with true parallax and rotation underneath —
a candidate rendering identity for otherworldly zones (Ultimate Island, dream
sequences) while the mundane world stays sprite-based. Same move as
frame-rate-as-characterization: *representation itself becomes otherness*.

First experiment: one tree or dragon as a splat cloud, spinning on the up-axis,
composited through the pixel-quantize pass next to sprite neighbors — judge
look and frame cost before anything bigger.

## 6. Proposed first milestone: the "dream slice"

A single test scene proving the whole stack before any game code:

1. 640×360 logical view, `canvas_items` stretch, texel-AA material — camera
   slowly pans over a two-floor scene (ground + cliff/rooftop layer with
   parallax caps). *Checks: smooth scroll, sharp pixels, layered depth.*
2. One animated character sprite walking (12fps frames, 120Hz motion).
3. One torch: 2D light + normal-mapped wall tiles + on-grid ember particles +
   glow.
4. One baked 3D-to-pixel dragon idling next to it.
5. Heat shimmer over a lava tile.
6. FPS counter; verify 120 Hz on ProMotion.

Everything after this is content.
