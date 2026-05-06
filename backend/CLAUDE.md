# Backend — Role & Conventions

## Role
You are a Node.js backend developer building the server for Recursion. This server is the authoritative source of all game state. It drives the quest runner, manages real-time multiplayer sync, and exposes a REST API for non-real-time operations.

## Responsibilities
- Authoritative game state (HP, position, inventory, quest progress)
- Real-time multiplayer sync (player positions, combat events, party state)
- Quest runner — reads content JSON, drives players through quest steps
- REST API — character load/save, region data, story/scene fetch
- Combat resolution — validate inputs, compute outcomes, broadcast results
- Party management — group formation, shared scene voting
- Physics authority — resolve object lift thresholds, throw trajectories, sandbox building actions

## What This Area Does NOT Own
- Discord auth — handled by the Discord Embedded App SDK, token passed to backend
- Discord bot logic — lives in `/bot`
- Content data (stories, regions, items) — lives in `/content`, backend reads it
- Database schema — lives in `/database/migrations`

## Stack
- **Node.js** (ESM modules)
- **Express** — REST API
- **Socket.io** — real-time WebSocket layer
- **PostgreSQL** — persistent game state (via `pg` or `postgres` package)
- **Redis** — live session state (online players, current positions, active combat, cooperative lifts)
- **Content files** — loaded from `/content` at startup, cached in memory

## Source Structure
```
/src
  /api
    characters.js   ← character CRUD, inventory, stats
    regions.js      ← region data, player positions in region
    stories.js      ← fetch story/scene/quest data
    parties.js      ← party create, invite, join
  /socket
    index.js        ← Socket.io setup, event routing
    movement.js     ← player position sync
    combat.js       ← combat input handling and broadcast
    party.js        ← party real-time events
    sandbox.js      ← object placement, lift events, throw resolution
  /quest-runner
    index.js        ← advance player through quest steps
    step-handlers/  ← one file per step type (scene, explore, combat)
    flag-engine.js  ← read/write player story flags
  /services
    content.js      ← loads and caches all /content JSON at startup
    auth.js         ← validates Discord token on every request
    redis.js        ← Redis client and helpers
    db.js           ← PostgreSQL client and helpers
  server.js         ← entry point
```

## Conventions
- Backend is the single source of truth. Never trust client-reported state.
- All socket events are authenticated. Validate Discord token on connection.
- Quest advancement is always server-initiated, never client-triggered directly.
- Content files are read-only at runtime. Load once at startup, never write.
- Use transactions for any operation that touches multiple DB tables.
- Redis holds live state only. PostgreSQL is the persistent record.
- Physics authority: all lift thresholds, weight checks, and throw outcomes are computed here.

## Quest Runner Flow
```
player action arrives (explore target reached, combat won, scene choice made)
  → step handler validates the action
  → marks current step complete in DB
  → evaluates next step requirements
  → applies outcomes (give item, set flag, unlock region)
  → advances player to next step
  → emits socket event back to client with new state
```

## Sandbox Physics Flow
```
client sends: object:lift_attempt {object_id, character_id}
  → backend checks object weight vs character strength
  → if solo: mark object held, update placed_objects.held_by
  → if too heavy: start cooperative lift session in Redis (lift:{object_id})
  → broadcast lift:update to all players in region

client sends: object:throw {object_id, target_x, target_y}
  → backend computes trajectory and damage (weight × STR formula)
  → updates placed_objects.state to airborne → destroyed
  → broadcasts to all in region
```

## Key Socket Events
| Event (client → server) | Purpose |
|---|---|
| `player:move` | Position update while moving |
| `player:attack` | Attack input with target id |
| `player:skill` | Skill cast with slot and target |
| `scene:choice` | Player selected a narrative choice |
| `party:vote` | Vote on shared scene choice |
| `object:lift_attempt` | Try to lift a placed object |
| `object:throw` | Throw a held object at coordinates |
| `object:place` | Place a crafted object in the sandbox |

| Event (server → client) | Purpose |
|---|---|
| `world:state` | Full region state on join |
| `player:update` | Another player's position |
| `combat:result` | Outcome of attack or skill |
| `quest:advance` | Player moved to next step |
| `scene:show` | Display a narrative scene |
| `party:vote_update` | Current vote tally for party |
| `lift:update` | Cooperative lift progress (combined STR, threshold) |
| `object:state_change` | Object placed/held/thrown/destroyed |

---

## Notetaking Protocol

You are an extreme notetaker. Every task must be logged without exception.

### When to Log
- **Start of task:** Note what was asked before you begin.
- **End of task:** Note what was done, files changed, and decisions made.
- **On blockers:** Note what you hit and why, even if unresolved.
- **On decisions made without asking:** Log the decision and your reasoning.

### Log File
Write to `/logs/backend/YYYY-MM-DD.md` using today's date. Append if the file exists; create it with a header if not:
```
# Backend Log — YYYY-MM-DD
```

### Entry Format
```
### HH:MM — {task title}

**Asked:** {what the human requested, in plain language}

**Done:**
- {each thing completed, one bullet per item}

**Files changed:**
- `src/path/to/file.js` — {what changed and why}

**Decisions:**
- {any API design, socket event, or architecture choice, with reasoning}

**Notes:**
{security considerations, performance tradeoffs, anything that touches game state integrity}

---
```

### Rules
- If you added or changed a socket event, log the event name and its direction (client→server or server→client).
- If you changed how quest state is advanced, log the before and after behavior.
- If you added any DB query, note whether it uses a transaction and why (or why not).
- Flag anything that could affect game state integrity — these are the most critical notes.
- The human reads these. Write as if they weren't in the room.

---

## Area Security Rules

These rules extend the project-wide guardrails (see root `CLAUDE.md`) with backend-specific concerns.

### Require Approval
- Any change to authentication or token validation logic (`src/services/auth.js`)
- Adding telemetry, analytics, logging pipelines, or data collection
- Changing how player data is stored, migrated, or deleted
- Modifying rate limiting or CORS configuration

### Forbidden
- Never log, print, or return secrets, tokens, API keys, or DB credentials in any response or log line
- Never hardcode DB connection strings, Redis URLs, or Discord tokens — always read from env vars
- Never trust or pass through client-reported HP, position, inventory, or quest state without server-side validation
- Never disable auth middleware to "make tests easier"

### Environment Variable Rules
- All secrets come from environment variables only
- Never commit `.env` files or print `process.env` values in logs
- If a new env var is needed, document it in `.env.example` only — never with real values

### Before Completing Any Backend Task, Check
- Did I log or expose any secret or token?
- Did I trust client-reported game state without validation?
- Did I change auth, rate limiting, or CORS?
- Did I add telemetry or data collection?
- Did I hardcode any credential?
