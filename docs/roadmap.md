# Roadmap

How the engine gets from “it walks” to a demo you can show. Names, asset
pipeline, and scene order live here so they do not get rediscovered.

---

## Names (do not rename until this is decided)

Three different things currently share one folder:

| Thing | Today | Publish as |
|---|---|---|
| Engine plugin | `addons/dragon16` | Needs a **descriptive package name**. “Dragon16” is the game family. “toybox” is a sandbox scene. Neither is a plugin identity. Working title can stay `dragon16` on disk. |
| Sandbox | `demos/toybox` | Fine **internal** name. Godot has a “toy” panel; this is the engineer’s playground, not the storefront. |
| Showcase | (does not exist) | One interactive style demo, then named scenes: forest, temple, cathedral, neon. |
| Game | `appendix/` Dragon Rescue | A consumer of the plugin. Keep it out of the plugin name. |

Do not invent a brand this week. When we publish, pick a name that is
the thing (`splat-tile`, `splite`, or whatever you want on the Asset
Library). Until then, say “the splat-tile plugin” in docs and keep the
folder.

---

## The showable demo (the actual goal)

Two layers, in order. Do not build four biomes before the first layer
is honest.

**Locked:** finish **this garden** as the style demo before any other
world. Forest / temple / cathedral / neon wait.

**1. Style demo (this scene).** The garden diorama: WASD, cellar door
(E), ember pickup (E), cut-away under the walkway, brush to sink into,
4pm drops, swirl field. The feature tour still reels the same map.
No second scene until this one is the thing you would show someone.

**2. Scene pack (verticality).** Same verbs, different worlds. Order
is about what the engine is good at, not tourism:

| Scene | Why this engine | When |
|---|---|---|
| Verdant forest | Canopy volume, sink, overlap, cheap trees | first showcase |
| Mountain-top temple | Stairs, stacked levels, cut-away, long 4pm drops | second |
| Cathedral | Rooms as knowledge, interior light, nave verticality | third |
| Cyberpunk neon | Relightable clouds + mesh neon. Hardest. | last |

Forest first because *volume* is the primitive we are selling. Neon
last because it needs albedo-clean splats and real lights, which the
pipeline must prove first.

---

## Asset pipeline (the real next engineering)

Photogrammetry 3DGS is the wrong default. We do not scan rooms. We
**fit a cloud to a model from a narrow top-down cone**, under flat
light, at a known tile scale.

Because we only need to *render* the source mesh, topology and LODs
do not matter. High-poly museum scans and messy Sketchfab files are
fine.

```
CC0 / CC-BY model
    → Blender: flatten lights, lock scale (1 tile = 1 m)
    → camera rig in the game cone (~70–90° elevation, azimuth as needed)
    → 40–120 EXR/PNG + JSON poses (skip COLMAP — we know the cameras)
    → gsplat / nerfstudio splatfacto (or equivalent) with those poses
    → .ply
    → importer → SplatCloud + hull AABB + shadow_vecs + optional mesh surface
    → Godot tile / splite resource
```

Rules that keep the cloud *game*-shaped:

- Neutral / flat light so color ≈ albedo (4pm is a runtime light).
- Only views the game camera will ever have. No undersides.
- Budget: hundreds of Gaussians per tile, not millions.
- One walk-cycle frame = one cloud (a splite is N fits, not 4DGS).
- Record license + URL next to every source file.

**Sources, in order:** [Poly Haven](https://polyhaven.com/) (CC0
models, textures, HDRIs), Kenney / similar CC0 packs, Sketchfab
filtered to CC0 then CC-BY (keep an `ATTRIBUTION.md`). Make only the
pieces that do not exist: the player splite, maybe one hero prop per
scene.

**What we write:** a Blender “cone render” script, a thin train
wrapper, a PLY → `SplatCloud` importer. That importer is also how
the engine stops being procedural clover.

---

## Steps

### Now — one real asset
1. Pick one CC0 tree (or statue). Do not start a forest.
2. Cone-render it. Fit one cloud. Import it. Replace the procedural
   canopy tile.
3. Walk around it in the sandbox. If it does not merge, sink, cast a
   4pm drop, or cut away, fix the **importer / runtime**, not the art.

### Next — style demo
4. One interactive scene using that tree plus a few more fitted tiles
   (floor slab, wall, stairs — mesh surfaces can stay mesh).
5. Door + one pickup or switch. Keep the tour; the style demo is
   what you *play*.
6. Player splite: either keep procedural or fit a CC0 character’s
   walk frames the same way.

### Then — first showcase scene
7. Verdant forest on the same verbs. More fitted plants, same
   player, same interactions. Verticality from canopy + a ruin or
   ridge, not a new engine.
8. Only then temple / cathedral / neon, each as a scene pack that
   consumes the plugin. Neon waits on relighting.

### Explicitly later
- Compute splat backend (after a real tile exists).
- Tile painter in the editor.
- Publishing / Asset Library (needs the name decision).
- Dragon Rescue as a game project.

---

## What not to do next

- Rename the repo before the plugin has users.
- Build four biomes with procedural clovers.
- Train general photoreal 3DGS from phone video.
- Optimize source meshes for a game renderer we are not using.
- Invent a brand, a logo, or a second engine.
