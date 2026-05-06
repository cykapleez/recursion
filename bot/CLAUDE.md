# Discord Bot — Role & Conventions

## Role
You are a Discord.js v14 developer building the bot layer for Recursion. The bot handles everything that happens outside the game window — notifications, party invites, world events, and launching the Activity.

## Responsibilities
- Launch the Recursion Discord Activity in a voice channel
- Notify players of nearby players in their region
- Broadcast world notes left by players
- Handle party invite flow (invite, accept, decline)
- Slash commands for meta actions (character info, quest status, settings)
- Relay backend webhook events to the right Discord channels

## What This Area Does NOT Own
- Game logic — lives in the backend
- Real-time game state — the bot does not connect to Socket.io
- Narrative/story content — lives in `/content`
- Database access — bot communicates with backend via REST API only

## Stack
- **Discord.js v14**
- **Discord Embedded App SDK** — for launching the Activity
- **REST calls to backend** — bot never touches DB directly

## Source Structure
```
/src
  /commands
    play.js         ← launches the Activity in the current voice channel
    character.js    ← show character stats, level, class
    quest.js        ← show current quest and step
    party.js        ← invite player to party, show party status
    note.js         ← view recent world notes in your region
  /events
    ready.js        ← bot startup, register commands
    interactionCreate.js ← route slash commands and button interactions
    messageCreate.js     ← handle any text-based triggers if needed
  bot.js            ← entry point, Discord client setup
```

## Conventions
- Bot never calls the database directly. All data comes from the backend REST API.
- All slash commands are registered globally (not guild-only) for production.
- Use ephemeral replies for personal info (character stats, quest status).
- Use channel messages for world events (nearby player alerts, world notes).
- Party invites use Discord button components (Accept / Decline).
- Never DM players without their opt-in.

## Key Slash Commands
| Command | Description |
|---|---|
| `/play` | Launch Recursion in the current voice channel |
| `/character` | Show your character's stats, class, and level |
| `/quest` | Show your current quest and active step |
| `/party invite @user` | Invite a player to your party |
| `/party status` | Show current party members |
| `/notes` | Show recent world notes in your current region |

## Activity Launch Flow
```
user runs /play in a voice channel
  → bot checks user is in a voice channel
  → bot calls Discord Activity launch via Embedded App SDK
  → Activity opens in the voice channel
  → game client connects to backend with Discord token
  → backend validates token, loads character, sends world state
```

## Notification Types
| Trigger | Message |
|---|---|
| Player enters same region | "⚔️ {name} has entered {region}. You are nearby." |
| Player leaves a world note | "📜 {name} left a note in {region}: '{content}'" |
| Party invite received | Button message: "⚔️ {name} has invited you to their party." [Accept] [Decline] |
| Boss spawned in region | "💀 A powerful enemy stirs in {region}." |

---

## Notetaking Protocol

You are an extreme notetaker. Every task must be logged without exception.

### When to Log
- **Start of task:** Note what was asked before you begin.
- **End of task:** Note what was done, files changed, and decisions made.
- **On blockers:** Note what you hit and why, even if unresolved.
- **On decisions made without asking:** Log the decision and your reasoning.

### Log File
Write to `/logs/bot/YYYY-MM-DD.md` using today's date. Append if the file exists; create it with a header if not:
```
# Bot Log — YYYY-MM-DD
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
- {any command design, notification format, or Discord API choice, with reasoning}

**Notes:**
{Discord API quirks, permission requirements, rate limit concerns, or anything the human should know}

---
```

### Rules
- If you added or changed a slash command, log its name, description, and whether it's ephemeral or public.
- If you changed a notification format, log the old and new format.
- Note any Discord API limitations you worked around.
- Flag anything that requires a specific Discord bot permission to function.

### Future: Discord Daily Summary Delivery
The bot will eventually be the vehicle for delivering daily dev summaries directly to a Discord channel. When that feature is built, the bot will read `/logs/daily/YYYY-MM-DD.md` and post it as a formatted embed. The `DISCORD_WEBHOOK_URL` env var will control the target channel. Log your work carefully — these notes become the content of those summaries.

---

## Area Security Rules

These rules extend the project-wide guardrails (see root `CLAUDE.md`) with Discord bot-specific concerns.

### Require Approval
- Registering new slash commands globally (affects all servers the bot is in)
- Adding new webhook targets or external HTTP destinations
- Changing which Discord permissions the bot requests
- Any feature that sends a DM or message without player opt-in

### Forbidden
- Never read, log, expose, or print `DISCORD_TOKEN`, `DISCORD_WEBHOOK_URL`, or any bot credential
- Never modify Discord server settings, roles, channels, or permissions
- Never send messages to external services (Slack, email, SMS) without explicit approval
- Never store Discord user data beyond what is needed for the current request
- Never expose user IDs, usernames, or guild IDs in log output that could be read externally

### Bot Permission Hygiene
- Request only the minimum Discord permissions needed for each feature
- Document every permission the bot requires and why in the relevant command file
- If a command needs a new permission, flag it for human review before adding it

### Before Completing Any Bot Task, Check
- Did I read or log any Discord token or webhook URL?
- Did I add a new external message destination?
- Did I change bot permissions or scope?
- Did I store or expose Discord user data beyond the current request?
