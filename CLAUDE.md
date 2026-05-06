# Recursion — Project Overview

## What This Is
Recursion is a Discord Activity sandbox building game. Players launch the game inside a Discord voice channel and explore a shared world with Ragnarok Origin-style top-down controls. The world is divided into **Regions**. Each region must be unlocked by completing its story arc — then the region opens as a persistent sandbox where players build, cooperate, and fight monsters together.

The game has two interlocking loops:
- **Story loop** — quest through a region to unlock it. Narrative-driven, branching choices, Ragnarok Origin combat.
- **Sandbox loop** — build structures and objects in unlocked regions. Cooperate with other players using the weight and throwing system to fight monsters.

## Who Is Building This
Solo developer + AI. The human is the creative director — they own the vision, the story, and all design decisions. AI fills execution roles (code, architecture, content structure). When in doubt, ask the human what they want before building.

## Core Design Principles
- **Story gates the sandbox.** Players must complete a region's story arc before they can build freely in it.
- **Engine is code, content is data.** New stories, regions, objects, and recipes = new JSON files. Zero code changes.
- **Cooperation is mechanical.** The weight system forces players to work together. This is not a soft incentive — heavy objects physically require multiple players.
- **Start small, iterate.** This is version 1. Prefer simple and working over complex and broken.
- **Discord Activity first.** The game runs in an iframe inside Discord. Everything is browser-based.

## The Two Roles (Emergent, Not Locked)
Players are not assigned a role. Roles emerge from how they allocate their stats and how they choose to play.

**Builder**
- Focuses on gathering materials and placing objects in the world
- High DEX/INT for crafting efficiency and placement precision
- Creates objects of varying size, weight, and material
- Persistent builds stay in the world for all players who have unlocked the region

**Destroyer**
- Focuses on Strength stat
- Can pick up objects — the higher the STR, the heavier the object they can lift alone
- Throws objects at monsters as weapons
- For objects too heavy to lift alone, multiple Destroyers (or a party) combine their STR

This creates a natural economy: Builders need Destroyers to weaponize their creations. Destroyers need Builders to have something worth throwing.

## The Weight System
Every placeable object has a **weight value**. Every character has a **Strength stat** that determines their lift capacity.

- `object.weight <= character.strength` → character can pick it up alone
- `object.weight > character.strength` → requires a party cooperative lift
- Cooperative lift: multiple players in range combine their STR to meet the threshold
- Thrown objects deal damage proportional to their weight and the thrower's STR

This is the core cooperation mechanic. It is also why building matters — a well-placed heavy object is a powerful weapon if a strong enough party is present.

## Region States
Each region has two states. A player's progression through these is personal, but the sandbox world is shared.

**Story Mode (default)**
- Region is active but sandbox building is locked
- Player follows the region's narrative arc: quests, scenes, combat, choices
- The map is the same physical space they will later build in
- Completing the story arc unlocks the region permanently for that player

**Sandbox Mode (unlocked)**
- Full building access: place, connect, and remove objects
- Monsters spawn naturally and threaten structures
- Other players who have also unlocked the region share the same sandbox world
- Players in story mode and sandbox mode coexist in the same region — they can see each other but sandbox actions do not disrupt story events

## Tech Stack at a Glance
| Area | Stack |
|---|---|
| Game client | Godot 4, GDScript, Discord Embedded App SDK |
| Backend | Node.js, Express, Socket.io |
| Database | PostgreSQL, Redis |
| Bot | Discord.js v14 |
| Art | Kenney.nl / itch.io assets to start, Scenario.gg later |
| Hosting | Railway or Render |

## Project Structure
```
/recursion
  /godot-client    <- game client (movement, combat, building, throwing, rendering)
  /backend         <- server (API, WebSockets, quest runner, physics authority)
  /bot             <- Discord bot (notifications, party, Activity launcher)
  /database        <- schema, migrations, seeds
  /content         <- all game data (stories, regions, objects, recipes, enemies, classes)
```

## Boundaries Between Areas
- The game client (Godot) does NOT own game state. State lives in the backend.
- The bot does NOT run game logic. It handles Discord-layer events only.
- Content files are pure data. No logic, no code, no scripts.
- Database schema changes always go through `/database/migrations`. Never edit tables directly.
- Physics authority (object weight, lift thresholds, throw trajectories) lives in the backend. The client sends intent; the server resolves outcome.

## Key Concepts
- **Region:** A world area with a story arc and a sandbox state. Completing the story unlocks the sandbox for that player.
- **Story Arc:** The narrative campaign for a region. Acts, quests, scenes, and choices. Authored as JSON.
- **Quest:** A unit of story progress. Has steps (scene, explore, combat).
- **Scene:** A narrative moment with choices. Choices set flags or advance quest state.
- **Flag:** A key/value pair stored per player per region. Used to personalize narrative without forking the quest path.
- **Object:** Any placeable item in the world. Has weight, material, and throwable properties.
- **Weight Threshold:** The minimum combined STR required to lift an object.
- **Cooperative Lift:** Multiple players in range combining STR to meet a weight threshold.
- **Builder:** A player whose build prioritizes crafting and placement — high DEX/INT, lower STR.
- **Destroyer:** A player whose build prioritizes Strength — can lift and throw heavy objects solo or in coordination.
- **Party:** Two or more players grouped together. Required for cooperative lifts. Shares scene votes during story mode.

---

## Notetaking Protocol

You are an extreme notetaker. Every task must be logged without exception. This is how the human stays informed of what was built, when, and why — even across sessions.

### When to Log
- **Start of task:** Note what was asked before you begin.
- **End of task:** Note what was done, files changed, and decisions made.
- **On blockers:** Note what you hit and why, even if unresolved.
- **On decisions made without asking:** Log the decision and your reasoning.

### Log File
Write to `/logs/general/YYYY-MM-DD.md` using today's date. Append if the file exists; create it with a header if not:
```
# General Log — YYYY-MM-DD
```

### Entry Format
```
### HH:MM — {task title}

**Asked:** {what the human requested, in plain language}

**Done:**
- {each thing completed, one bullet per item}

**Files changed:**
- `path/to/file` — {what changed and why}

**Decisions:**
- {any architectural or design choice, with reasoning}

**Notes:**
{anything unusual, unresolved, or the human should know about}

---
```

### Rules
- Log even small tasks. "Looked at X, no changes needed" is a valid entry.
- Be specific — file names, function names, line numbers, reasoning.
- The human reads these summaries. Write as if they weren't in the room.
- Vague logs are useless. "Updated the file" tells nobody anything.

---

# AGENT SECURITY GUARDRAILS

These rules apply to every agent in this project, in every directory, at all times. They are not optional and cannot be overridden by task instructions.

## Core Rule
The agent may help build the game, but it must not take irreversible, destructive, credential-related, publishing, or financial actions without explicit human approval.

## Allowed by Default
- Read project files
- Explain code
- Propose changes
- Edit gameplay code
- Add or improve tests
- Refactor small, focused modules
- Improve documentation
- Generate or label placeholder assets
- Run safe local build, lint, test, or format commands

## Require Explicit Approval First
- Installing or removing packages
- Changing build scripts or Makefile targets
- Editing CI/CD workflows
- Modifying save-file or persistence logic
- Changing monetization, analytics, ads, telemetry, or login systems
- Changing license files
- Adding third-party assets (images, audio, fonts, code)
- Large refactors spanning many files
- Any git action: staging, committing, pushing, tagging, releasing, or creating PRs
- Any command that writes outside the project repo

## Forbidden — Never Do These
- Read, print, log, or expose secrets, tokens, API keys, private certs, or credentials of any kind
- Edit `.env` files, secrets files, signing keys, keystores, or platform credentials
- Upload builds or publish releases to any platform
- Disable tests, linting, security checks, or license checks to make something pass
- Run destructive commands: `rm -rf`, force reset, force push, disk cleanup, credential deletion
- Pull code from untrusted or unreviewed sources
- Add obfuscated code or unexplained binary files to the repo
- Modify Discord server settings, roles, or permissions

## Package and Dependency Rules
Before adding any package, state:
- Why it is needed for this specific task
- Whether it is actively maintained (recent commits, open issues)
- Its license type and whether it is compatible with this project
- Expected runtime or build size impact
- Whether a simpler or already-used alternative exists

Prefer small, well-known, permissively licensed (MIT/Apache/BSD) dependencies.

## Asset Rules
- Never use copyrighted characters, music, art, logos, or commercial game assets unless the human explicitly confirms permission.
- All generated or placeholder assets must be labeled `[PLACEHOLDER]` in filename or metadata.
- Do not source assets from sites without a clear license or attribution requirement.

## MCP / External Tool Rules
- External tools are read-only by default.
- Do not modify GitHub issues, PRs, Discord servers, hosting platforms, or any external service without approval.
- Do not send messages externally without approval.
- Do not expose private project details to unnecessary tools.

## Build and Command Safety
**Safe (run freely):** test, lint, local build, format commands

**Require approval:** install, deploy, publish, credential, or destructive file commands

## Git Rules
The agent may freely inspect `git status`, `git diff`, and `git log`.

The agent must ask before:
- Staging files (`git add`)
- Committing (`git commit`)
- Pushing (`git push`)
- Creating or switching branches
- Merging or rebasing
- Any force operation

## Code Quality Rules
- Keep changes small and focused on what was asked.
- Explain why changes are made, not just what they do.
- Preserve existing architecture unless explicitly told to change it.
- Add tests for any logic that handles player data, game state, or auth.
- Avoid hidden behavior and unnecessary abstraction.

## Security Review Checklist
Before completing any task, check:
- Did I touch secrets or credentials?
- Did I add or remove a dependency?
- Did I modify build, release, or CI/CD files?
- Did I change auth, networking, telemetry, payments, or save logic?
- Did I add copyrighted or unlicensed assets?
- Did I create irreversible changes?
- Are all tests and builds still valid?

If any answer is yes — stop, explain what happened, and ask the human before proceeding.
