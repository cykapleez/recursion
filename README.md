# Recursion

A Discord Activity sandbox building game. Players launch the game inside a Discord voice channel and explore a shared world. Each region must be unlocked by completing its story arc — then the region opens as a persistent sandbox where players build, cooperate, and fight monsters together.

## Stack

| Area | Stack |
|---|---|
| Game client | Godot 4, GDScript, Discord Embedded App SDK |
| Backend | Node.js, Express, Socket.io |
| Database | PostgreSQL, Redis |
| Bot | Discord.js v14 |
| Art | Kenney.nl assets |

## Project Structure

```
/recursion
  /godot-client    ← game client (movement, combat, building, throwing, rendering)
  /backend         ← server (API, WebSockets, cart service)
  /bot             ← Discord bot
  /database        ← schema and migrations
  /content         ← all game data (objects, enemies, classes, carts)
  /logs            ← session dev logs
```

---

## Dev Logs

---

### Godot Client — 2026-05-05

#### Build preview ghost

**Asked:** When selecting an item to build in the build menu, show a transparent version of the item where the mouse cursor is.

**Done:**
- Created `scripts/build_preview.gd` — Node3D that instantiates a WorldObject ghost, strips collision and labels, makes all materials 40% transparent, and follows the snapped (or ALT=free) mouse position in real time.
- Updated `scenes/World.tscn` — added `BuildPreview` Node3D.

**Decisions:**
- Ghost is built by instantiating WorldObject.tscn and calling `setup()` — reuses all existing visual logic without duplicating it.
- After setup: removed from `world_objects` group, collision disabled, all Label3D hidden, all MeshInstance3D materials duplicated with `TRANSPARENCY_ALPHA` and alpha=0.4.
- Rebuilds ghost only when `build_object_id` changes, not every frame.

---

#### Orange tree + new cherry tree

**Asked:** Rename the existing cherry tree to orange tree and make it 3× larger. Create the original cherry tree as a new separate object.

**Done:**
- `world_object.gd`: renamed `obj-cherry-tree` → `obj-orange-tree` across all dictionaries. Added scale 3.0 for orange tree. Added `obj-cherry-tree` as a new procedural object.
- `game_manager.gd`: split into two entries — cherry-tree (20 kg) and orange-tree (120 kg).
- `world.gd`: updated spawn list with one cherry tree and two orange trees.

**Decisions:**
- Orange tree model: `tree-autumn.glb` at 3.0× scale. Label at y=9.0.
- Cherry tree: procedural brown trunk (CylinderMesh) + pink canopy (SphereMesh) — the original "brown stick with pink circle on top" look.
- Orange tree weight: 120 kg — at the solo Warrior lift ceiling.

---

#### Material class split: farmable vs crafted

**Asked:** Two classes of throwable materials — farmable (trees, rocks) weak when thrown, built products (fences, walls, houses) deal full damage by weight.

**Done:**
- Added `item_category` field to all OBJECT_DEFS: `"farmable"` or `"crafted"`.
- `obj-cherry-tree` and `obj-stone-block` classified as `"farmable"` with `throw_effectiveness: 0.25`. All others `"crafted"` at 1.0.
- `cart_ui.gd`: added RAW (green) / BUILT (orange) tag per cart row.
- `object_palette.gd`: tooltip now shows category.

**Decisions:**
- `calc_throw_damage()` already reads `throw_effectiveness` — no formula changes, only data.
- Damage at current balance: cherry-tree ~28, stone-block ~32, flower-pot (lightest crafted) ~33. Gap widens at higher tiers.

---

#### Thrown object visuals match original model

**Asked:** When objects are thrown, they should look exactly like the object that was picked up.

**Done:**
- Replaced placeholder BoxMesh in `throw_projectile.gd` with `_build_visual()` — instantiates WorldObject.tscn, calls `setup()`, reparents visual children (skipping CollisionShape3D and Label3D) onto the RigidBody3D.
- ThrowProjectile BoxShape3D (0.5×0.35×0.5) unchanged as physics hitbox.

---

#### Texture system upgrade (PBR pass)

**Asked:** Audit textures, improve visual quality with PBR materials.

**Done:**
- Added `roughness` and `metallic` optional params to `_mat()` in `player.gd` and `enemy.gd`.
- Player materials: cloth (roughness 0.85), skin (0.70), eye gloss (0.35, metallic 0.15).
- Enemy materials: flesh (0.95), bone (0.78), iron armor (0.32, metallic 0.80), spine (0.45, metallic 0.55).
- Ground material: roughness 0.95, metallic 0.0, metallic_specular 0.1.

**Texture system state:**

| Asset | Status |
|---|---|
| World objects | GLB with embedded textures (Kenney) |
| Player body | Procedural — texture sheet TODO |
| Enemy | Procedural — texture sheet TODO |
| Ground | Flat color — seamless grass texture TODO |

---

#### Fence hitbox alignment

**Asked:** The fence hitbox was a large cube — align it to the visual.

**Done:**
- Replaced all guessed hitbox sizes with AABB-computed collision in `_build_collision()`.
- `_visual_aabb()` reads actual mesh bounds from all `MeshInstance3D` children using global transforms, producing a collision box that exactly wraps the visual for any object.
- `_find_mesh_instances()` recurses into nested GLB nodes, skipping CollisionShape3D and Label3D.

---

### Content — 2026-05-06

#### Orange tree + new cherry tree

**Done:**
- Renamed `obj-cherry-tree` → `obj-orange-tree` in `objects.json`. Weight 120 kg, throw tier Heavy.
- Added new `obj-cherry-tree`: 20 kg, Light throw tier, farmable, liftable solo.

**Decisions:**
- Orange tree weight 120 kg: at the solo Warrior ceiling (STR 15 × 10 = 150 kg capacity).
- Cherry tree weight 20 kg: anyone can carry solo.

---

#### Material class split: farmable vs crafted

**Done:**
- Added `"farmable"` as a third `item_category` value.
- `obj-cherry-tree` and `obj-stone-block` reclassified as `"farmable"` with `throw_effectiveness: 0.25`.
- All crafted objects remain at 1.0.
- `content/CLAUDE.md` updated with full category design intent table.

**Decisions:**
- `farmable` is distinct from `material` (raw drops) — farmable objects are placeable world objects you can uproot and throw. Material items are stackable resource drops.
- 0.25 effectiveness: cherry tree ~28 dmg, stone block ~32 dmg vs flower pot (lightest crafted) ~33. Gap widens with perks and higher tiers.

---

### Godot Client — 2026-05-06

#### Enemy AI: Undead Colossus (AOE stomp + eye laser)

**Done:**
- Added AI state machine to `enemy.gd`: IDLE → WINDUP_AOE or WINDUP_LASER → IDLE.
- **AOE stomp**: pulsing red CylinderMesh disc (radius 4.5) at the player's feet for 1.4s windup, then 35 damage to all players in radius. Flashes body orange.
- **Eye laser**: pulsing red BoxMesh beam from eye midpoint to player for 1.4s windup, then 55 damage to players within 2.0 units of beam path. Flashes body white.
- Attack range: 22 units. Cooldown: 4s. 50/50 random attack selection.
- Indicators cleared on enemy death.

**Decisions:**
- Both indicators use `SHADING_MODE_UNSHADED` — always visible regardless of lighting.
- Laser target locked at windup start — telegraphed, dodge window matters.
- Both indicators added to scene root (world space) so they don't drift if the enemy moves.

---

#### Enemy movement + AOE screen shake

**Done:**
- Changed Colossus from `StaticBody3D` → `CharacterBody3D`.
- Monster Hunter-style wander: picks random waypoints in a 3–8 unit ring around the player, moves at 2.8 m/s, always in motion.
- Screen shake on AOE land: tweens Player's Camera3D through 5 random offsets (±0.5 XZ, ±0.25 Y) over ~350ms.
- AOE disc moved to world-space root so it stays fixed during the 1.4s windup while the enemy wanders.

---

#### Player respawn + spawn zone markers

**Done:**
- Player captures spawn position on `_ready()`.
- `take_damage()` calls `_die()` at 0 HP: hides player, awaits 1.2s, teleports to spawn, restores full HP, reappears.
- `_dead` flag blocks all movement and input during the respawn window.
- Glowing blue 2×2 `BoxMesh` marker on the ground at each spawn position (`SHADING_MODE_UNSHADED`, alpha transparency, blue emission).
- `place_object()` in GameManager checks an AABB against all spawn positions — silently blocks builds inside the zone.
- Spawn zone size and visual marker derived from the same `SPAWN_ZONE_HALF` const — always in sync.
