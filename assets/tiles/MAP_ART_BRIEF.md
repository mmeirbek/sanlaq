# SAÑLAQ Map Composition Brief — Steppe Village

## Why this is a brief, not new tiles

Same situation as the character pass: no image-generation tool or MCP is
available in this environment (checked again this session). Producing "better"
flat-color rock/log/bush blobs by hand would still be programmer art wearing a
different hat, and the arena ring drawing already contains a comment stating
its jaggedness is *intentional* pixel-art styling — patching around that
without real assets would not fix the actual problem. So: full inspection,
a precise brief, and a pause, exactly per the task's own fallback instruction.

**Nothing in code, scenes, or data was touched this session** — this is
analysis + spec only.

## How the map actually works (read before touching anything)

There is no hand-placed map scene. `scenes/world/map_steppe_village.tscn` is
just a `Node2D` running [map_manager.gd](../../scripts/systems/map_manager.gd),
which procedurally builds the whole scene at `_ready()`:

- **Ground** — one `Sprite2D` tiling `assets/tiles/ground.png` (a small
  speckled-green noise tile) across the *entire* `bounds` rect
  (1800×1100, from map data `bounds_min/bounds_max`), `z_index = -10`. One flat
  texture, no variation anywhere in the world.
- **Water** — 9 hardcoded base positions, each jittered ±60px and given a
  random radius 90–130, rendered as `assets/tiles/water_blob.png` (a soft
  blue blob, the *only* half-decent asset in the set) scaled/rotated
  randomly. `z_index = 1`.
- **Rocks** (`obstacle_positions`, 12 hardcoded points) — every single one is
  the same `assets/tiles/rock.png` (a flat pale rounded rectangle with almost
  no shading — reads as a placeholder circle, not a rock), just rotated
  randomly and scaled 2.4–3.2×. `StaticBody2D`, circular collision radius 20,
  `collision_layer = 5, collision_mask = 0`.
- **Yurts** (`yurt_positions`, 7 hardcoded points) — instances of
  [yurt.tscn](../../scenes/world/yurt.tscn): one flat top-down "target" sprite
  (concentric red/gold rings + cross-beams, no visible door, no wall/roof
  value shift) plus 14 small `CollisionShape2D` circles arranged in a ring
  (`Walls`, radius 11 each) approximating a circular wall.
- **Central arena** — hand-drawn every frame in `MapManager._draw()`: nested
  flat-color circles (radius 360 out to 384) plus diamond "ornament" motifs
  and a ring whose points are deliberately snapped to a 4px grid — the code
  comment literally says this keeps a "2D pixel-art character"
  (`_draw_pixel_ring`). That directly conflicts with §11 ("no pixel art") and
  is, ironically, the most effort-intensive part of the scene.
- **Corner props** — 4 flat rectangular "rugs" with a diamond in the middle,
  drawn at the four map corners, also in `_draw()`.
- **Two files are dead weight**: `assets/tiles/grass.png` and
  `assets/tiles/water.png` (Kenney CC0 roguelike-pack single-tile fragments,
  flat single-color swatches) are not referenced anywhere in code. Don't treat
  them as a hidden quality resource — they're leftovers, arguably worth
  deleting in a later cleanup pass, not part of this brief's asset list.

## Non-negotiable technical constraints

1. **World bounds**: `Rect2((-900,-550), (1800,1100))`, from
   `data/maps/map_steppe_village.tres`. Any new ground art must tile/cover
   exactly this rect; don't hardcode a different size in code.
2. **Spatial layout is already intentional — the problem is execution, not
   layout.** Distance-from-center math on the existing arrays shows: the
   central arena (radius 360) is kept clear as the open catch/quiz space;
   every rock (radius 432–782 from center), yurt (453–741), and water blob
   (roughly 400–850, edge-jittered) lives in an outer ring between the arena
   and the map edge — i.e. "central festival ground surrounded by a scattered
   steppe village" is already the design intent. The brief below is about
   making that *read* as one composed place, not about moving the layout.
3. **Collision contract**: obstacles that should block movement use
   `collision_layer = 5, collision_mask = 0` (matches player's
   `collision_layer/mask = 5` from `player.tscn`) — any new blocking prop
   (e.g. a log) must follow this, and must NOT touch `catch area`'s layer/mask
   (separate `CircleShape2D`, radius 28, layer 0 / mask 5 on the player) or
   any role/round logic. Decorative-only props (e.g. bushes meant to be walked
   through/hidden behind per §14 "hiding opportunities") should carry no
   `StaticBody2D` at all — don't give them collision just because rocks have
   it.
4. **Constants to extend, not replace**: `GRASS_TEX`, `WATER_TEX`, `ROCK_TEX`,
   `YURT_SCENE` in `map_manager.gd` point at exact current paths — new ground
   variants, a `LOG_TEX`, and a `BUSH_TEX` should be added as new constants
   alongside these, following the same naming pattern, not by renaming
   existing ones (`data/clothing`-style resources aren't involved here, but
   `map_definition.gd`/`.tres` and `game.tscn`'s reference to
   `map_steppe_village.tscn` are — don't rename the map scene or its data
   resource).
5. **Camera is fixed-zoom, no reframing needed**: `camera_controller.gd` is a
   plain lerp-follow `Camera2D` at `zoom_level = Vector2(1,1)`, viewport
   1280×720 (landscape). At 1:1 zoom the arena (diameter ≈ 768) roughly fills
   the screen height when the player is centered in it — so **the arena is
   the hero shot** and deserves the most composition/detail budget; the outer
   steppe ring is only ever seen in partial glimpses while moving, so it can
   lean on repeated-but-varied elements rather than needing unique detail
   everywhere. Do not change camera zoom/follow logic — this is a layout
   fact to inform asset priority, not a camera task.

## Why it currently reads as "stacked shapes," specifically

Naming the actual causes so the fix targets them, not just "make it prettier":

1. **Every element type is exactly one texture, copy-rotated-scaled.** One
   rock PNG × 12, one yurt PNG × 7, one water blob × 9. Nothing varies in
   silhouette, only in transform — the eye immediately clocks the repetition.
2. **Nothing casts a ground shadow.** Rocks, yurts, and water blobs are drawn
   with no contact shadow, so they read as decals pasted onto the grass tile
   rather than objects sitting on it. This is a huge, cheap-to-fix reason
   "stacked" was the word that came to mind.
3. **No blending at edges.** The water blob's soft alpha edge sits directly on
   a hard-edged flat grass tile — no wet-sand ring, no reed tufts, no color
   transition. The arena's outer ring sits on the same flat grass with no
   transition either — a circle is just stamped on a rectangle.
4. **No clustering/relationship between objects.** Every rock, yurt, and water
   position is independent — no rock ever sits near a yurt "dooryard," no
   reeds mark a water's edge, no worn path connects a yurt to the arena.
   Real scattered-but-composed environments group elements with a reason;
   this one places them with `randf_range` jitter only.
5. **The yurt sprite has no volume.** It's a flat concentric-ring "target,"
   not a dome + wall + door — nothing about it reads as a 3D structure at a
   glance, which undercuts the "cohesive village" read entirely.
6. **The one hand-crafted centerpiece (arena rings) is deliberately jagged**,
   clashing with the soft-cartoon target style everywhere else in the project.

## Composition plan

### Zone structure (concentric, matching the existing math)

1. **Arena core (r 0–360)** — clear festival ground, existing diamond/ring
   motifs kept (they're a nice cultural touch) but re-rendered smooth
   (antialiased circles/polylines, no 4px snapping) and, ideally, with a
   subtle radial value gradient (center slightly lighter/warmer) instead of
   flat concentric bands, so it reads as a sunlit clearing, not a dartboard.
2. **Transition ring (r ≈ 360–420)** — currently nonexistent: ground jumps
   straight from "arena" texture to "flat grass." Needs a blended dirt/grass
   edge (worn-earth color bleeding into the green) so the arena looks trodden
   into the steppe rather than stamped on top of it.
3. **Outer steppe ring (r ≈ 420–780)** — where all yurts/rocks/water already
   live. This is where clustering matters most (see below): group a small
   rock or bush at each yurt's "dooryard" side (the side facing the arena,
   since that's implicitly the village's shared center), add 2–3 reed/grass
   tufts at every water blob's edge, and let a couple of worn dirt paths run
   from yurt clusters toward the arena to visually stitch the ring together.
4. **Map-corner vignettes (existing rugs/flags)** — keep as small "campsite"
   accents at the four corners past the last yurts; re-render with the same
   soft-cartoon treatment (soft fabric folds/fringe instead of a flat
   rectangle) rather than adding new corner content.

### Grounding & depth (applies to every prop type)

- Every standing object (rock, log, bush, yurt) gets a soft flat
  elliptical drop-shadow beneath it, same soft navy-gray tone
  (`#1B2A4A` at ~25% alpha), slightly offset toward the "down" side
  since the camera is top-down with implied overhead light. This alone does
  most of the work of making objects feel placed *in* the scene instead of
  stacked *on* it.
- True Y-depth ordering (an object with a higher screen-Y should draw in
  front of one with a lower screen-Y, e.g. via `y_sort_enabled` on the
  container node) so overlapping objects near the arena edge don't flatten
  into an ambiguous stack. This is a real, common cause of "flat" top-down
  scenes and is worth calling out even though it's a placement/z-order fix
  rather than a texture — flagging it here rather than changing it, per this
  session's scope.

### New element types (currently missing entirely vs. the project vision)

§14 lists stones, logs, bushes, grass, water, and yurt as the planned prop
set; only stones/water/yurt/ground exist today. Adding the missing two adds
real silhouette variety, which is most of what will stop the "one rock shape
copy-pasted" feeling:

- **Logs** — fallen trunk, elongated silhouette (reads clearly different from
  round rocks at a glance), bark texture with 2–3 tone value bands (top-lit,
  mid, shadowed underside), a cut end showing simple tree rings at one tip.
  Should block movement like rocks (same collision pattern), and works well
  laid across a "path" to create a deliberate obstacle rather than a random
  scatter point.
- **Bushes** — soft rounded shrub clusters (2–3 overlapping puffy masses, not
  one perfect circle), warm-green with a few small berry/flower accent dots
  in the sand-gold accent color for visual interest. Per §14's "hiding /
  movement opportunities," these should generally be decorative (no
  collision) so players can path near/behind them — confirm with gameplay
  before adding collision to any bush.

### Existing element types needing a repaint (not a redesign)

- **Rock** — needs actual rock form: an irregular (not rounded-rectangle)
  silhouette, a flat-shaded top facet plus a darker shadowed underside facet,
  a thin dark outline. Provide at least 2 size/shape variants so 12 placements
  don't read as one clone — reuse is fine, one clone is not.
- **Water blob** — the shape/softness is already close to on-style; add a
  slightly darker depth-shading toward the blob's center and a soft lighter
  rim highlight, plus a small set of reed/grass-tuft decals to scatter at
  2–3 points along each blob's edge at integration time (these bridge water
  into ground and fix the hard-edge problem called out above).
- **Ground** — needs at least two more tile variants: a worn dirt/path tone
  for the arena transition ring and yurt-to-arena paths, and optionally a
  subtly different "near water" damp-grass tone. Keep the same seamless-tile
  approach (`ground.png` is already tileable) — just add `ground_path.png` /
  `ground_arena_edge.png` style variants rather than replacing the base tile.
- **Yurt** — needs actual volume: a visible dome/roof capped over a
  cylindrical wall band with a door facing outward, plus its own small ground
  shadow. Orient every yurt instance's door toward the arena center at
  integration time (a code-level placement tweak once the art has a
  door) — this alone will make the outer ring visually organize itself into
  "a village facing its shared meeting ground" instead of a scatter of
  identical coins.
- **Arena rings / corner rugs** — same motifs, rendered smooth (this is
  achievable without new textures at all, purely by removing the 4px-snap in
  `_draw_pixel_ring` and enabling antialiasing on the draw calls — flagging
  it here since it's a legitimate code-only fix a future pass could make
  independent of new art).

## Palette

Extends the same navy/sand identity already used for the character work,
kept consistent with the current ground/water hues rather than replacing them:

| Role | Hex | Used for |
|---|---|---|
| Grass base | `#2E6C22` | ground.png replacement base tone (close to current `#4a7c30` speckle, pulled slightly more saturated/cartoon) |
| Grass shadow | `#1F4C17` | AO under props, denser grass clumps |
| Dirt / path | `#8A6A3E` | arena transition ring, worn paths |
| Dirt shadow | `#5E4527` | path edge shading |
| Water base | `#2A66C4` | water blob core (close to current blob) |
| Water highlight | `#6FA3EE` | blob rim light |
| Rock body | `#8B93A0` | rock top facet |
| Rock shadow | `#5C6270` | rock underside facet |
| Log bark | `#6B4A2E` | log body |
| Log ring | `#8A6440` | cut-end tree rings |
| Bush green | `#3F8A3F` | bush clusters |
| Bush accent | `#EAC25B` | berry/flower dots (matches character sand accent) |
| Yurt wall | `#E8C77E` | felt/canvas wall band |
| Yurt roof | `#8B3E32` | roof cap (matches existing red ring tone) |
| Yurt trim | `#EAC25B` | door frame, roof-band ornament |
| Shadow (all props) | `#1B2A4A` @ ~25% alpha | contact shadow under every standing object |

## Integration checklist for whenever art lands

1. Drop repainted `ground.png`, `rock.png`, `water_blob.png` in place at their
   existing paths (same filenames — `ROCK_TEX`/`WATER_TEX`/`GRASS_TEX`
   constants in `map_manager.gd` reference them directly).
2. Add `assets/tiles/log.png`, `assets/tiles/bush.png`,
   `assets/tiles/ground_path.png` and wire new `LOG_TEX`/`BUSH_TEX` constants
   plus `_build_logs()`/`_build_bushes()` functions mirroring `_build_rocks()`
   (same `StaticBody2D` + circle-collision pattern for logs; plain `Sprite2D`,
   no collision, for bushes unless gameplay wants otherwise).
3. Replace `yurt.png` and re-scale/re-check its `CircleShape2D` wall ring
   still matches the new art's visible wall radius (currently tuned to the
   flat circle's ~90px radius at `scale = 0.75`) — a taller/domed yurt
   silhouette must not silently make the collision ring visually wrong.
4. Add the shadow, edge-blend (reeds/path), and clustering placement details
   described above in `map_manager.gd`'s `_build_*` functions once the new
   textures exist to place — this is where placement code and new art meet;
   doing it before the art exists would just rearrange the current
   placeholders.
5. Playtest: walk the full outer ring and confirm no new prop silhouette is
   ambiguous with another (rock vs. log vs. bush) at actual gameplay camera
   distance, and that logs/rocks still correctly block movement while bushes
   don't (per the collision contract above).

## What still needs manual art review

1. Actually painting/generating: ground base + path/arena-edge variants,
   rock (2+ variants), log, bush, water blob touch-up, yurt with real volume,
   corner rug/flag touch-up, reed/grass-tuft edge decals — in an environment
   with image-gen access, or by an illustrator, per this brief.
2. The arena-ring de-pixelation and contact-shadow/Y-sort code changes are
   art-independent and could be done in a follow-up pass without waiting on
   new textures, if useful in the meantime — flagged, not applied, this
   session.
3. In-editor playtest once new art/placement code lands: confirm collision
   shapes still match new silhouettes, confirm mobile-camera readability at
   actual zoom (§17), confirm the arena still reads as an open, uncluttered
   catch space (§15 — gameplay readability over decoration).
