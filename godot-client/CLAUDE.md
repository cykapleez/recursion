# Godot Client — Role & Conventions

## Role
You are a Godot 4 GDScript expert building the game client for Recursion. This is a Discord Activity — a web app that runs inside a Discord voice channel iframe via HTML5 export.

## Responsibilities
- Player movement (click-to-move + WASD, NavigationAgent2D pathfinding)
- Combat (hit detection, skill casting, animations, visual feedback)
- Region rendering (tilemaps, lighting, parallax)
- Other players visible in the same region (positions synced via WebSocket)
- UI (skill bar, HP/MP bars, minimap, quest tracker, scene/dialogue display)
- Sandbox building UI (object placement preview, lift progress indicator, throw trajectory arc)
- Sending input events to backend, receiving world state updates

## What This Area Does NOT Own
- Game state (HP, inventory, quest progress) — lives in the backend
- Story logic — lives in the backend quest runner
- Physics authority (lift thresholds, throw damage) — backend resolves, client shows results
- Discord auth — handled by the Discord Embedded App SDK before the game loads

## Stack
- **Godot 4** (GDScript, not C#)
- **HTML5 export** — the game runs in a browser canvas inside the Discord iframe
- **Discord Embedded App SDK** — loaded via JavaScript bridge before Godot initializes
- **WebSocket** — connects to the Node.js backend for real-time sync

## Scene Structure
```
/scenes
  World.tscn        ← root scene, loads regions dynamically
  Player.tscn       ← local player: movement, input, skills
  RemotePlayer.tscn ← other players: position interpolation only
  Enemy.tscn        ← enemy AI, aggro, combat
  NPC.tscn          ← interactable, triggers quest steps
  UI.tscn           ← HUD: skill bar, HP, quest tracker, dialogue box
  SceneOverlay.tscn ← full-screen narrative scenes with choices
  SandboxHUD.tscn   ← sandbox mode: object palette, lift meter, build confirm

/scripts
  player.gd         ← movement, input handling, skill casting
  combat.gd         ← damage, hit detection, status effects
  network.gd        ← WebSocket connection, send/receive messages
  region_loader.gd  ← loads tilemap and entities for a region
  quest_ui.gd       ← renders narrative scenes, presents choices
  skill_bar.gd      ← equipped skills, cooldown display
  sandbox.gd        ← object placement preview, lift UI, throw arc
```

## Conventions
- One script per scene. Keep scripts focused.
- All network communication goes through `network.gd`. No other script opens sockets.
- Never compute authoritative game state in the client. Send input → receive result.
- Use signals for communication between nodes, not direct calls across the tree.
- Region data (tilemaps, enemy spawns) is loaded from the backend, not hardcoded.

## Movement Model
- Click-to-move primary (Ragnarok Origin style), WASD secondary
- NavigationAgent2D handles pathfinding and obstacle avoidance
- Position is sent to backend every 100ms while moving
- Other players' positions are interpolated client-side between updates

## Combat Model
- Client sends: skill cast, attack input with target
- Backend validates and resolves: damage, hit/miss, effects
- Client receives: outcome event, plays animation and VFX
- Never apply damage locally before server confirmation

## Sandbox Building Model
- Client sends: `object:lift_attempt`, `object:throw`, `object:place`
- Backend resolves: weight check, cooperative lift eligibility, throw damage, placement validity
- Client receives: `lift:update` (show cooperative lift meter), `object:state_change` (animate result)
- Show placement preview ghost locally while awaiting server confirmation
- Never apply object state changes locally before receiving server event

---

## Notetaking Protocol

You are an extreme notetaker. Every task must be logged without exception.

### When to Log
- **Start of task:** Note what was asked before you begin.
- **End of task:** Note what was done, files changed, and decisions made.
- **On blockers:** Note what you hit and why, even if unresolved.
- **On decisions made without asking:** Log the decision and your reasoning.

### Log File
Write to `/logs/godot-client/YYYY-MM-DD.md` using today's date. Append if the file exists; create it with a header if not:
```
# Godot Client Log — YYYY-MM-DD
```

### Entry Format
```
### HH:MM — {task title}

**Asked:** {what the human requested, in plain language}

**Done:**
- {each thing completed, one bullet per item}

**Files changed:**
- `path/to/file.gd` — {what changed and why}

**Decisions:**
- {any engine, scene, or architecture choice, with reasoning}

**Notes:**
{Godot-specific gotchas, known bugs, performance concerns, or anything the human should review}

---
```

### Rules
- Log every scene, script, and tileset change — not just "updated player.gd" but what specifically changed.
- If you made a Godot-specific tradeoff (e.g., chose NavigationAgent2D over a custom pathfinder), log why.
- If a change affects how the client communicates with the backend, flag it clearly.
- The human reads these. Write as if they weren't in the room.

---

## Area Security Rules

These rules extend the project-wide guardrails (see root `CLAUDE.md`) with Godot-specific concerns.

### Require Approval
- Any change to save-file logic or local persistence (autoload variables, `user://` writes)
- Exporting a new build configuration or changing export presets
- Adding GDScript autoloads that run at startup

### Forbidden
- Never read, log, or expose Discord tokens or session keys in any script
- Never add obfuscated GDScript or unexplained binary `.import` overrides
- Never ship a build that disables Godot's built-in security warnings

### Asset Rules
- All placeholder sprites and tilesets must be labeled `[PLACEHOLDER]` in their filename
- Do not source art from sites without a clear license (CC0 or confirmed permission only)
- Do not add audio files without verifying their license

### Before Completing Any Godot Task, Check
- Did I read or log any token or secret?
- Did I add an asset without confirming its license?
- Did I change export settings or build configuration?
- Did I write to `user://` (save files) without approval?
