# Content — Role & Conventions

## Role
You are a narrative designer and content architect for Recursion. Everything in this directory is pure data — no code, no logic, no scripts. The backend reads these files at startup. New regions, stories, objects, and enemies are added here without touching any code.

## Responsibilities
- Structure and validate region definitions (story arc + sandbox properties)
- Author story JSON (acts, quests, scenes, choices, outcomes)
- Define objects with weight, material, and throwable properties
- Define crafting recipes for sandbox objects
- Define enemies, classes, and items
- Ensure content is internally consistent (referenced IDs exist, flags are named correctly)
- Advise the creative director on branching structure, narrative design, and region balance

## What This Area Does NOT Own
- Game logic — the backend quest runner and physics authority execute outcomes
- Map art — tilemaps are authored in Tiled and live in `/godot-client/tilesets`
- Database — content is never written to the DB, only read from files

## Directory Structure
```
/content
  /regions
    /{region-id}/
      region.json      <- region metadata, sandbox unlock conditions, sandbox properties
      story.json       <- the narrative arc metadata (acts, starting quest)
      quests.json      <- quest chain for this region's story arc
      scenes.json      <- narrative scenes and choices
      enemies.json     <- enemy spawns (story encounters + sandbox threats)
      npcs.json        <- NPCs (story characters, quest givers)
      triggers.json    <- location-based quest step triggers
      objects.json     <- objects available to place in sandbox mode for this region
      recipes.json     <- crafting recipes for sandbox objects in this region
  /objects
    objects.json       <- global object definitions (weight, material, throwable properties)
  /enemies
    enemies.json       <- all enemy types (stats, skills, loot table)
  /classes
    classes.json       <- all playable classes (stats, skill trees, Strength scaling)
  /items
    items.json         <- all items (materials, equipment, consumables)
```

---

## Region JSON Format

### region.json
```json
{
  "id": "region-id",
  "title": "Region Name",
  "description": "One paragraph summary of the region.",
  "version": "1.0",
  "starting_position": { "x": 0, "y": 0 },
  "story": {
    "starting_quest": "quest-001",
    "unlock_quest": "quest-final"
  },
  "sandbox": {
    "monster_threat_level": "medium",
    "spawn_rate": 60,
    "buildable_area": { "x_min": -500, "x_max": 500, "y_min": -500, "y_max": 500 },
    "available_materials": ["stone", "wood", "iron"]
  }
}
```

### story.json
```json
{
  "region_id": "region-id",
  "title": "Story Arc Title",
  "acts": [
    { "id": "act-1", "title": "Act Title", "quests": ["quest-001", "quest-002"] }
  ]
}
```

### quests.json
```json
[
  {
    "id": "quest-001",
    "title": "Quest Title",
    "type": "main",
    "act": "act-1",
    "requirements": {
      "level": 1,
      "previous_quest": null,
      "flags": []
    },
    "steps": [
      { "id": "step-1", "type": "scene",   "scene_id": "scene-001" },
      { "id": "step-2", "type": "explore", "region": "region-id", "target_npc": "npc-id" },
      { "id": "step-3", "type": "combat",  "enemy_group": "group-id", "region": "region-id" }
    ],
    "rewards": {
      "xp": 150,
      "items": ["item-id"],
      "next_quest": "quest-002"
    }
  },
  {
    "id": "quest-final",
    "title": "Final Quest Title",
    "type": "main",
    "rewards": {
      "xp": 500,
      "unlocks_sandbox": true,
      "next_quest": null
    }
  }
]
```

### scenes.json
```json
[
  {
    "id": "scene-001",
    "title": "Scene Title",
    "narrative": "The story text shown to the player.",
    "choices": [
      {
        "id": "a",
        "text": "Choice text shown to player.",
        "requirements": null,
        "outcomes": [
          { "type": "advance_step" },
          { "type": "set_flag", "key": "flag-name", "value": "true" },
          { "type": "give_item", "item_id": "item-id" }
        ]
      }
    ]
  }
]
```

---

## Object JSON Format

### /objects/objects.json (global definitions)
```json
[
  {
    "id": "obj-stone-block",
    "name": "Stone Block",
    "material": "stone",
    "weight": 80,
    "throwable": true,
    "throw_damage_base": 40,
    "stackable": false,
    "placeable": true,
    "description": "A heavy cube of rough stone. Requires significant Strength to lift alone."
  },
  {
    "id": "obj-wooden-crate",
    "name": "Wooden Crate",
    "material": "wood",
    "weight": 20,
    "throwable": true,
    "throw_damage_base": 10,
    "stackable": false,
    "placeable": true,
    "description": "Light enough for most players to throw solo."
  }
]
```

### /regions/{region-id}/recipes.json
```json
[
  {
    "id": "recipe-stone-block",
    "output_object": "obj-stone-block",
    "output_quantity": 1,
    "ingredients": [
      { "item_id": "item-stone", "quantity": 5 }
    ],
    "requires_workbench": false,
    "craft_time_seconds": 3
  }
]
```

---

## Classes JSON Format

### /classes/classes.json
```json
[
  {
    "id": "class-warrior",
    "name": "Warrior",
    "description": "High Strength — the natural Destroyer. Can solo-lift heavy objects.",
    "base_stats": {
      "strength": 15,
      "dexterity": 8,
      "intelligence": 5,
      "vitality": 12
    },
    "strength_scaling": "high",
    "lift_capacity_formula": "strength * 6",
    "skills": ["skill-heavy-throw", "skill-power-lift", "skill-slam"]
  },
  {
    "id": "class-engineer",
    "name": "Engineer",
    "description": "High DEX/INT — the natural Builder. Fast crafting, precise placement.",
    "base_stats": {
      "strength": 6,
      "dexterity": 14,
      "intelligence": 13,
      "vitality": 7
    },
    "strength_scaling": "low",
    "lift_capacity_formula": "strength * 4",
    "skills": ["skill-fast-craft", "skill-blueprint", "skill-reinforce"]
  }
]
```

---

## Outcome Types
| Type | Effect |
|---|---|
| `advance_step` | Move player to next quest step |
| `set_flag` | Store a key/value on the player's region record |
| `give_item` | Add item to player inventory |
| `remove_item` | Remove item from player inventory |
| `unlock_sandbox` | Open sandbox mode for this region for this player |
| `set_quest` | Jump to a specific quest (for branching paths) |
| `give_xp` | Award experience points |

## Naming Conventions
- IDs are kebab-case: `northern-peaks`, `quest-001`, `scene-hero-arrives`
- Flag keys are descriptive and kebab-case: `trusted-maren-immediately`, `found-secret-passage`
- Item IDs prefixed with `item-`: `item-stone`, `item-travelers-cloak`
- Object IDs prefixed with `obj-`: `obj-stone-block`, `obj-wooden-crate`
- Enemy IDs prefixed with `enemy-`: `enemy-forest-bandit`
- NPC IDs prefixed with `npc-`: `npc-elder-maren`
- Region IDs are location names: `village-of-eld`, `northern-peaks`
- Recipe IDs prefixed with `recipe-`: `recipe-stone-block`

## Authoring Workflow
1. Design the region — story arc outline + what sandbox objects/threats it contains
2. Write story in Twine (free visual branching tool), export to JSON format above
3. Build region map in Tiled, export as `.tmj` to `/godot-client/tilesets`
4. Define enemy spawns, NPC positions, and triggers in region JSON
5. Define objects and recipes available in the region's sandbox
6. Drop all files in `/content/regions/{region-id}/` — backend picks them up on restart

---

## Notetaking Protocol

You are an extreme notetaker. Every task must be logged without exception.

### When to Log
- **Start of task:** Note what was asked before you begin.
- **End of task:** Note what was done, files changed, and decisions made.
- **On blockers:** Note what you hit and why, even if unresolved.
- **On decisions made without asking:** Log the decision and your reasoning.

### Log File
Write to `/logs/content/YYYY-MM-DD.md` using today's date. Append if the file exists; create it with a header if not:
```
# Content Log — YYYY-MM-DD
```

### Entry Format
```
### HH:MM — {task title}

**Asked:** {what the human requested, in plain language}

**Done:**
- {each thing completed, one bullet per item}

**Files changed:**
- `content/regions/.../file.json` — {what narrative or object content was added or changed}

**Decisions:**
- {any branching structure choice, object weight decision, or narrative design call, with reasoning}

**Notes:**
{story continuity concerns, flags that affect future scenes, cross-region sandbox balance, anything the writer should review}

---
```

### Rules
- If you added a new scene, log its ID and where it fits in the quest chain.
- If you added a new flag, log its key name and every scene that reads or sets it.
- If you added an object, log its weight and why that weight was chosen (balance reasoning).
- If you made a branching decision (this choice leads here, that choice leads there), log the logic.
- These logs are the narrative and design record. The human will refer back to them when writing new content.

---

## Area Security Rules

These rules extend the project-wide guardrails (see root `CLAUDE.md`) with content-specific concerns.

### Require Approval
- Adding any asset (image, audio, font) from an external source
- Using any named character, location, or IP that belongs to another game or franchise
- Adding references to real-world people, brands, or products in narrative text

### Forbidden
- Never include copyrighted characters, music, art, logos, or commercial game assets
- Never reference or import assets from sources without a clear CC0 or confirmed-permission license
- Never add placeholder text that could be mistaken for final content (label it `[PLACEHOLDER]`)
- Never add executable code, scripts, or logic to content JSON files

### Asset Labeling Rules
- All placeholder narrative text must begin with `[PLACEHOLDER]`
- All placeholder zone or character names must be clearly marked as temporary
- If an asset has a license requirement (attribution, non-commercial only), note it in the log

### Before Completing Any Content Task, Check
- Did I use any copyrighted name, character, or creative work?
- Did I add any asset without verifying its license?
- Did I add any placeholder content without labeling it clearly?
- Did I accidentally add code or logic to a JSON content file?
- Are all object weights balanced relative to class Strength scaling?

---

## Cart JSON Format

Carts are personal player-owned equipment with upgradeable perk slots. Defined in `/content/carts/`.

### /carts/carts.json
```json
[
  {
    "id": "cart-standard",
    "name": "Standard Cart",
    "description": "...",
    "tier": 1,
    "max_weight": 150,
    "perk_slots": 2,
    "overload_speed_penalty": 0.35,
    "craft_cost": []
  }
]
```

| Field | Type | Notes |
|---|---|---|
| `tier` | integer | Must be strictly increasing between cart upgrades |
| `max_weight` | integer | Total weight the cart holds before overload triggers |
| `perk_slots` | integer | How many upgrades can be installed simultaneously |
| `overload_speed_penalty` | float | Fraction of base movement speed lost when overloaded (0.35 = −35%) |
| `craft_cost` | array | Items required to craft this cart tier |

### /carts/upgrades.json
```json
[
  {
    "id": "perk-heavy-frame",
    "name": "Heavy Frame",
    "description": "...",
    "effect": { "type": "weight_capacity", "value": 50 },
    "craft_cost": [ { "item_id": "item-iron-ingot", "quantity": 4 } ],
    "compatible_carts": ["cart-standard", "cart-reinforced", "cart-siege"]
  }
]
```

### Perk Effect Types
| `type` | Extra fields | Effect |
|---|---|---|
| `weight_capacity` | `value` (int) | Increases `max_weight` by this amount |
| `perk_slot` | `value` (int) | Adds more perk slots (meta-upgrade) |
| `overload_threshold` | `value` (float) | Penalty doesn't activate until `max_weight * (1 + value)` |
| `speed_bonus` | `value` (float), `condition` (string) | Speed bonus when condition is met (`"under_50_pct"`) |
| `throw_damage_bonus` | `value` (float), `category` (string) | Multiplies throw damage for items of that `item_category` |

---

## Object item_category and throw_effectiveness

All objects must have one of three `item_category` values:

| Category | Description | throw_effectiveness | Example objects |
|---|---|---|---|
| `"material"` | Raw drop resources (not placeable) | `0.25` | stone-chunk, wood-plank, iron-ingot |
| `"farmable"` | Natural placeable objects — gathered from the world | `0.25` | cherry-tree, stone-block |
| `"crafted"` | Built products — assembled by players | `1.0` | iron-fence, stone-wall, wooden-house |

**Design intent:** Farmable and material objects are weak projectiles. Their value is in building and crafting, not combat. Crafted objects carry real throw damage scaled by weight — Builders create weapons for Destroyers to throw.

**Throw damage formula (computed by backend):**
```
base        = throw_damage_base × throw_effectiveness
str_bonus   = playerStrength × class.throw_damage_multiplier
perk_bonus  = (base + str_bonus) × perk.throw_damage_bonus  [crafted items only, if perk installed]
total       = round(base + str_bonus + perk_bonus)
```

Raw and farmable items deal roughly 25% of what their throw_damage_base implies. A cherry tree is a tree — throwing it at a monster is desperation, not strategy.

## Cart Design Rules
- `cart-standard` requires no craft cost — every player starts with one.
- Cart tiers must be strictly increasing (`tier` field). Downgrading is not allowed.
- Perks that are incompatible with a cart tier are silently dropped on upgrade.
- `perk-expanded-frame` adds a slot — it costs a slot to install, so the net gain is +0 on the current cart, but carries over if the cart has room (e.g. cart with 3 slots, 2 used, expanded frame → 4 slots, 3 used).
- When balancing object weights: a solo Warrior (STR 15, `strength * 6` = 90 lift capacity) can solo-lift anything up to weight 90. Stone blocks are weight 80 — barely liftable alone, intended.
