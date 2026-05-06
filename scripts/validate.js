#!/usr/bin/env node

/**
 * Recursion — Boundary Validator
 * Checks that files changed since last commit respect area boundaries.
 * Also runs an encoding check on all .md files.
 * Run: node scripts/validate.js
 */

import { execSync } from "child_process";
import { readFileSync, existsSync, readdirSync } from "fs";
import { join, extname } from "path";
import { scanFiles } from "./fix-encoding.js";

const ROOT = new URL("..", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");

const RULES = {
  "godot-client": {
    allowedExtensions: [".gd", ".tscn", ".tres", ".tmj", ".png", ".svg", ".import", ".md"],
    forbidden: [
      { pattern: /discord\.js|discord-js/i, message: "Discord.js import found — Discord logic belongs in /bot" },
      { pattern: /pg\.Pool|redis\.createClient/i, message: "Direct DB client found — game client never talks to DB" },
    ],
    required: [],
  },
  backend: {
    allowedExtensions: [".js", ".json", ".md", ".env.example"],
    forbidden: [
      { pattern: /require\(['"]discord\.js['"]\)|from ['"]discord\.js['"]/i, message: "discord.js import — bot logic belongs in /bot" },
      { pattern: /client\.damage\s*=/i, message: "Client-side damage assignment — compute damage server-side" },
    ],
    required: [],
  },
  bot: {
    allowedExtensions: [".js", ".json", ".md", ".env.example"],
    forbidden: [
      { pattern: /require\(['"]pg['"]\)|from ['"]pg['"]/i, message: "Direct DB import — bot uses backend REST API only" },
      { pattern: /require\(['"]redis['"]\)|from ['"]redis['"]/i, message: "Direct Redis import — bot uses backend REST API only" },
      { pattern: /socket\.io/i, message: "Socket.io import — bot does not connect to game socket" },
    ],
    required: [],
  },
  database: {
    allowedExtensions: [".sql", ".md"],
    forbidden: [
      { pattern: /function\s+\w+\s*\(|const\s+\w+\s*=\s*\(|module\.exports/i, message: "Application code in database directory — only SQL allowed" },
    ],
    required: [],
  },
  content: {
    allowedExtensions: [".json", ".md"],
    forbidden: [
      { pattern: /function\s*\(|=>\s*\{|require\(|import\s+/i, message: "Code found in content file — content is pure data only" },
    ],
    required: [],
  },
};

function getChangedFiles() {
  try {
    const output = execSync("git diff --name-only HEAD", { cwd: ROOT, encoding: "utf8" });
    const staged = execSync("git diff --name-only --cached", { cwd: ROOT, encoding: "utf8" });
    const untracked = execSync("git ls-files --others --exclude-standard", { cwd: ROOT, encoding: "utf8" });
    const all = new Set([...output.split("\n"), ...staged.split("\n"), ...untracked.split("\n")].filter(Boolean));
    return [...all];
  } catch {
    return [];
  }
}

function getArea(filePath) {
  return Object.keys(RULES).find((area) => filePath.startsWith(area + "/") || filePath.startsWith(area + "\\"));
}

function validateFile(filePath, area) {
  const issues = [];
  const rules = RULES[area];
  const ext = extname(filePath);
  const absPath = join(ROOT, filePath);

  if (!existsSync(absPath)) return issues;

  if (rules.allowedExtensions.length && !rules.allowedExtensions.includes(ext)) {
    issues.push(`File extension '${ext}' not expected in /${area} — allowed: ${rules.allowedExtensions.join(", ")}`);
  }

  let content = "";
  try { content = readFileSync(absPath, "utf8"); } catch { return issues; }

  for (const { pattern, message } of rules.forbidden) {
    if (pattern.test(content)) {
      issues.push(message);
    }
  }

  return issues;
}

function validateContentRefs() {
  const warnings = [];
  const regionsDir = join(ROOT, "content", "regions");
  if (!existsSync(regionsDir)) return warnings;

  for (const regionId of readdirSync(regionsDir)) {
    const questsPath = join(regionsDir, regionId, "quests.json");
    const scenesPath = join(regionsDir, regionId, "scenes.json");

    if (!existsSync(questsPath) || !existsSync(scenesPath)) continue;

    let quests, scenes;
    try {
      quests = JSON.parse(readFileSync(questsPath, "utf8"));
      scenes = JSON.parse(readFileSync(scenesPath, "utf8"));
    } catch { continue; }

    const sceneIds = new Set(scenes.map((s) => s.id));
    const questIds = new Set(quests.map((q) => q.id));

    for (const quest of quests) {
      for (const step of quest.steps ?? []) {
        if (step.type === "scene" && !sceneIds.has(step.scene_id)) {
          warnings.push(`[content/${regionId}] Quest '${quest.id}' references missing scene '${step.scene_id}'`);
        }
      }
      if (quest.rewards?.next_quest && !questIds.has(quest.rewards.next_quest)) {
        warnings.push(`[content/${regionId}] Quest '${quest.id}' next_quest '${quest.rewards.next_quest}' does not exist`);
      }
    }
  }

  return warnings;
}

function runEncodingCheck() {
  try {
    const { changed, total } = scanFiles([".md"], true);
    return { clean: total - changed.length, corrupted: changed };
  } catch (err) {
    return { error: err.message };
  }
}

function run() {
  // --- Encoding check (runs on all .md files regardless of git state) ---
  console.log("\n## Encoding Check\n");
  const encoding = runEncodingCheck();

  if (encoding.error) {
    console.log(`  SKIP  Encoding check failed: ${encoding.error}`);
  } else if (encoding.corrupted.length === 0) {
    console.log(`  PASS  All .md files (${encoding.clean} checked) — no mojibake detected`);
  } else {
    for (const r of encoding.corrupted) {
      const rel = r.path.replace(ROOT, "").replace(/^[\\/]/, "");
      console.log(`  FAIL  ${rel} — ${r.fixes} corrupted sequence(s)`);
    }
    console.log(`\n  Fix: node scripts/fix-encoding.js`);
  }

  // --- Boundary check (runs on changed files) ---
  const files = getChangedFiles();
  if (!files.length) {
    console.log("\nNo changed files detected — skipping boundary check.");
    if (!encoding.error && encoding.corrupted.length > 0) process.exit(1);
    return;
  }

  const byArea = {};
  const unowned = [];

  for (const file of files) {
    const area = getArea(file);
    if (!area) { unowned.push(file); continue; }
    if (!byArea[area]) byArea[area] = [];
    byArea[area].push(file);
  }

  let totalPass = 0;
  let totalFail = 0;

  for (const [area, areaFiles] of Object.entries(byArea)) {
    console.log(`\n## /${area} — ${areaFiles.length} file(s) changed\n`);
    for (const file of areaFiles) {
      const issues = validateFile(file, area);
      if (!issues.length) {
        console.log(`  PASS  ${file}`);
        totalPass++;
      } else {
        for (const issue of issues) {
          console.log(`  FAIL  ${file}`);
          console.log(`        ${issue}`);
        }
        totalFail++;
      }
    }
  }

  const contentWarnings = validateContentRefs();
  if (contentWarnings.length) {
    console.log("\n## Content Reference Warnings\n");
    for (const w of contentWarnings) {
      console.log(`  WARN  ${w}`);
    }
  }

  if (unowned.length) {
    console.log("\n## Unowned Files (no area rule applied)\n");
    for (const f of unowned) console.log(`  ?     ${f}`);
  }

  const encodingFail = !encoding.error && encoding.corrupted.length > 0;

  console.log(`\n${"─".repeat(50)}`);
  console.log(`VALIDATION SUMMARY`);
  console.log(`Passed: ${totalPass}  Failed: ${totalFail}  Warnings: ${contentWarnings.length}  Encoding issues: ${encoding.corrupted?.length ?? "unknown"}`);
  console.log(`${"─".repeat(50)}\n`);

  if (totalFail > 0 || encodingFail) process.exit(1);
}

run();
