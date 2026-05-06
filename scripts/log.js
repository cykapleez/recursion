#!/usr/bin/env node

/**
 * Recursion — Log Utility
 * Appends a structured entry to the area's daily log file.
 *
 * Usage:
 *   node scripts/log.js <area> <title> <asked> <done> [decisions] [notes]
 *
 * Areas: general, godot-client, backend, bot, database, content, validator
 *
 * Example:
 *   node scripts/log.js backend "Add combat socket handler" \
 *     "Add player:attack event handler" \
 *     "Created src/socket/combat.js with attack validation and damage broadcast"
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");

const VALID_AREAS = ["general", "godot-client", "backend", "bot", "database", "content", "validator"];

const AREA_HEADERS = {
  general:        "General Log",
  "godot-client": "Godot Client Log",
  backend:        "Backend Log",
  bot:            "Bot Log",
  database:       "Database Log",
  content:        "Content Log",
  validator:      "Validator Log",
};

function today() {
  return new Date().toISOString().slice(0, 10);
}

function timestamp() {
  return new Date().toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false });
}

function formatEntry({ title, asked, done, files, decisions, notes }) {
  const lines = [];
  lines.push(`### ${timestamp()} — ${title}`);
  lines.push("");
  lines.push(`**Asked:** ${asked}`);
  lines.push("");
  if (done) {
    lines.push("**Done:**");
    const items = Array.isArray(done) ? done : [done];
    for (const item of items) lines.push(`- ${item}`);
    lines.push("");
  }
  if (files && files.length) {
    lines.push("**Files changed:**");
    const items = Array.isArray(files) ? files : [files];
    for (const item of items) lines.push(`- ${item}`);
    lines.push("");
  }
  if (decisions && decisions.length) {
    lines.push("**Decisions:**");
    const items = Array.isArray(decisions) ? decisions : [decisions];
    for (const item of items) lines.push(`- ${item}`);
    lines.push("");
  }
  if (notes) {
    lines.push("**Notes:**");
    lines.push(notes);
    lines.push("");
  }
  lines.push("---");
  lines.push("");
  return lines.join("\n");
}

function appendLog(area, entry) {
  const date = today();
  const logPath = join(ROOT, "logs", area, `${date}.md`);
  const logDir = dirname(logPath);
  if (!existsSync(logDir)) mkdirSync(logDir, { recursive: true });
  const header = `# ${AREA_HEADERS[area]} — ${date}\n\n`;

  let content = existsSync(logPath) ? readFileSync(logPath, "utf8") : header;
  content += formatEntry(entry);
  writeFileSync(logPath, content, "utf8");
  console.log(`Logged to logs/${area}/${date}.md`);
}

const [,, area, title, asked, done, decisions, notes] = process.argv;

if (!area || !title || !asked) {
  console.error("Usage: node scripts/log.js <area> <title> <asked> [done] [decisions] [notes]");
  console.error("Areas:", VALID_AREAS.join(", "));
  process.exit(1);
}

if (!VALID_AREAS.includes(area)) {
  console.error(`Unknown area: ${area}. Valid areas: ${VALID_AREAS.join(", ")}`);
  process.exit(1);
}

appendLog(area, { title, asked, done, decisions, notes });
