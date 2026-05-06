# Database — Role & Conventions

## Role
You are a PostgreSQL architect managing the persistent data layer for Recursion. All schema changes happen here via migrations. Redis is used alongside PostgreSQL for live session state.

## Responsibilities
- Design and maintain the PostgreSQL schema
- Write and version all migrations (never edit tables directly)
- Write seed data for development
- Document what each table owns and why
- Advise on indexing, query performance, and data integrity

## What This Area Does NOT Own
- Application logic — belongs in backend services
- Content data (regions, objects, recipes) — lives in `/content` as JSON files, not in the DB
- Redis schema — Redis is schemaless, managed by backend services

## Stack
- **PostgreSQL** — persistent game state
- **Redis** — live session state (not persisted to disk in dev)
- Migrations are plain SQL files, numbered sequentially

## Migration Conventions
- Files named: `001_initial_schema.sql`, `002_add_parties.sql`, etc.
- Never modify an existing migration. Always add a new one.
- Every migration is wrapped in a transaction.
- Seeds live in `/seeds` and are for development only.

---

## Schema

### Players & Characters
```sql
players
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  discord_user_id TEXT NOT NULL UNIQUE
  discord_username TEXT NOT NULL
  created_at      TIMESTAMPTZ DEFAULT now()

characters
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  player_id       UUID NOT NULL REFERENCES players(id)
  name            TEXT NOT NULL
  class_id        TEXT NOT NULL
  level           INT NOT NULL DEFAULT 1
  xp              INT NOT NULL DEFAULT 0
  current_region_id TEXT
  pos_x           FLOAT
  pos_y           FLOAT
  hp              INT NOT NULL
  max_hp          INT NOT NULL
  created_at      TIMESTAMPTZ DEFAULT now()

character_stats
  character_id    UUID PRIMARY KEY REFERENCES characters(id)
  strength        INT NOT NULL DEFAULT 5    -- determines lift capacity
  dexterity       INT NOT NULL DEFAULT 5    -- crafting speed, placement precision
  intelligence    INT NOT NULL DEFAULT 5    -- recipe unlocks, blueprint complexity
  vitality        INT NOT NULL DEFAULT 5    -- HP pool, stamina

character_skills
  character_id    UUID NOT NULL REFERENCES characters(id)
  skill_id        TEXT NOT NULL
  skill_level     INT NOT NULL DEFAULT 1
  equipped_slot   INT
  PRIMARY KEY (character_id, skill_id)

character_inventory
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  character_id    UUID NOT NULL REFERENCES characters(id)
  item_id         TEXT NOT NULL
  quantity        INT NOT NULL DEFAULT 1
  equipped_slot   TEXT
```

### Region Progression
```sql
-- Tracks each player's story progress and sandbox unlock status per region
player_region_state
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  character_id    UUID NOT NULL REFERENCES characters(id)
  region_id       TEXT NOT NULL
  story_status    TEXT NOT NULL DEFAULT 'locked'   -- locked | active | completed
  sandbox_unlocked BOOLEAN NOT NULL DEFAULT false
  unlocked_at     TIMESTAMPTZ
  UNIQUE (character_id, region_id)

player_quest_state
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  character_id    UUID NOT NULL REFERENCES characters(id)
  region_id       TEXT NOT NULL
  quest_id        TEXT NOT NULL
  current_step_id TEXT NOT NULL
  status          TEXT NOT NULL DEFAULT 'active'   -- active | completed | failed
  started_at      TIMESTAMPTZ DEFAULT now()
  completed_at    TIMESTAMPTZ
  UNIQUE (character_id, region_id, quest_id)

player_story_flags
  character_id    UUID NOT NULL REFERENCES characters(id)
  region_id       TEXT NOT NULL
  flag_key        TEXT NOT NULL
  flag_value      TEXT NOT NULL
  PRIMARY KEY (character_id, region_id, flag_key)
```

### Sandbox World
```sql
-- Persistent objects placed in sandbox regions
placed_objects
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  region_id       TEXT NOT NULL
  object_id       TEXT NOT NULL              -- references /content/objects/objects.json
  placed_by       UUID NOT NULL REFERENCES characters(id)
  pos_x           FLOAT NOT NULL
  pos_y           FLOAT NOT NULL
  rotation        FLOAT NOT NULL DEFAULT 0
  state           TEXT NOT NULL DEFAULT 'placed'  -- placed | held | airborne | destroyed
  held_by         UUID REFERENCES characters(id)  -- NULL unless currently being lifted
  placed_at       TIMESTAMPTZ DEFAULT now()
  destroyed_at    TIMESTAMPTZ

-- World notes players leave in regions (story or sandbox)
world_notes
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  character_id    UUID NOT NULL REFERENCES characters(id)
  region_id       TEXT NOT NULL
  pos_x           FLOAT NOT NULL
  pos_y           FLOAT NOT NULL
  content         TEXT NOT NULL
  created_at      TIMESTAMPTZ DEFAULT now()
  expires_at      TIMESTAMPTZ
```

### Social
```sql
parties
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  region_id       TEXT NOT NULL
  created_at      TIMESTAMPTZ DEFAULT now()

party_members
  party_id        UUID NOT NULL REFERENCES parties(id)
  character_id    UUID NOT NULL REFERENCES characters(id)
  role            TEXT NOT NULL DEFAULT 'member'   -- leader | member
  joined_at       TIMESTAMPTZ DEFAULT now()
  PRIMARY KEY (party_id, character_id)
```

---

## Redis Keys (reference)
| Key pattern | Type | Purpose |
|---|---|---|
| `session:{discord_user_id}` | Hash | Active session: character_id, region, connected_at |
| `region:{region_id}:players` | Set | Character IDs currently in this region |
| `region:{region_id}:positions` | Hash | `{character_id}` -> `{x},{y}` |
| `lift:{object_id}` | Hash | Active cooperative lift: participants, combined_str, threshold |
| `combat:{character_id}` | Hash | Active combat state, expires on combat end |
| `party:{party_id}:votes` | Hash | Scene choice votes from party members |

---

## Lift System Notes
When a cooperative lift is in progress, the backend holds it in Redis under `lift:{placed_object_id}`. It tracks:
- Which characters are participating
- Their combined Strength total
- The object's weight threshold

When combined STR meets the threshold, the backend transitions the `placed_objects.state` to `held` and assigns `held_by` to the party leader. The lift session is removed from Redis on success or timeout.

---

## Key Indexes
```sql
CREATE INDEX ON characters(player_id);
CREATE INDEX ON player_region_state(character_id, sandbox_unlocked);
CREATE INDEX ON player_quest_state(character_id, status);
CREATE INDEX ON player_story_flags(character_id, region_id);
CREATE INDEX ON placed_objects(region_id, state);
CREATE INDEX ON placed_objects(held_by) WHERE held_by IS NOT NULL;
CREATE INDEX ON world_notes(region_id, created_at DESC);
CREATE INDEX ON character_inventory(character_id);
```

---

## Notetaking Protocol

You are an extreme notetaker. Every task must be logged without exception.

### When to Log
- **Start of task:** Note what was asked before you begin.
- **End of task:** Note what was done, files changed, and decisions made.
- **On blockers:** Note what you hit and why, even if unresolved.
- **On decisions made without asking:** Log the decision and your reasoning.

### Log File
Write to `/logs/database/YYYY-MM-DD.md` using today's date. Append if the file exists; create it with a header if not:
```
# Database Log — YYYY-MM-DD
```

### Entry Format
```
### HH:MM — {task title}

**Asked:** {what the human requested, in plain language}

**Done:**
- {each thing completed, one bullet per item}

**Files changed:**
- `migrations/00N_file.sql` — {what the migration does}

**Decisions:**
- {any schema design choice, index decision, or normalization tradeoff, with reasoning}

**Notes:**
{data integrity concerns, migration risks, rollback considerations, or anything irreversible}

---
```

### Rules
- Every migration gets its own log entry. Include the migration number and what it changes.
- If you chose NOT to add an index, log why.
- If a migration is destructive (drops column, drops table), flag it explicitly and note whether there's a rollback path.
- Note any table or column that could grow large — these affect query performance over time.
- The human reads these. Schema decisions are the hardest to undo — document them thoroughly.

---

## Area Security Rules

These rules extend the project-wide guardrails (see root `CLAUDE.md`) with database-specific concerns.

### Require Approval
- Any migration that drops a table, drops a column, or deletes data
- Any migration that changes a column type in a way that could truncate data
- Adding new tables that store personally identifiable information (PII)
- Changing how Discord user IDs or usernames are stored

### Forbidden
- Never include connection strings, passwords, or credentials in migration files or seeds
- Never write a migration outside a transaction block
- Never modify an existing migration file — always add a new one
- Never bypass referential integrity (adding data without valid foreign keys)

### Data Sensitivity Rules
- `players.discord_user_id` and `players.discord_username` are sensitive — treat them with care
- Seeds must use fake/generated data only — never real Discord IDs or usernames
- Never log full table contents that include player identity data

### Before Completing Any Database Task, Check
- Did I include any credential or connection string in a migration?
- Is the migration wrapped in a transaction?
- Does this migration drop or modify data irreversibly?
- Does this touch PII (Discord IDs, usernames)?
- Is the migration numbered correctly and does it follow the existing sequence?
