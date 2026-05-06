#!/usr/bin/env node
// Reads /content JSON files and generates /wiki markdown pages.
// Fields inside a "secret" block are never written to wiki output.
// Run: node scripts/generate-wiki.js

'use strict';

const fs   = require('fs');
const path = require('path');

const ROOT        = path.join(__dirname, '..');
const CONTENT_DIR = path.join(ROOT, 'content');
const WIKI_DIR    = path.join(ROOT, 'wiki');

if (!fs.existsSync(WIKI_DIR)) fs.mkdirSync(WIKI_DIR, { recursive: true });

function readJson(relPath) {
  const full = path.join(CONTENT_DIR, relPath);
  if (!fs.existsSync(full)) { console.warn(`  SKIP (not found): content/${relPath}`); return null; }
  return JSON.parse(fs.readFileSync(full, 'utf8'));
}

function write(filename, content) {
  fs.writeFileSync(path.join(WIKI_DIR, filename), content, 'utf8');
  console.log(`  wrote  wiki/${filename}`);
}

// ── Objects ──────────────────────────────────────────────────────────────────

function generateObjects() {
  const objects = readJson('objects/objects.json');
  if (!objects) return;

  const crafted   = objects.filter(o => o.item_category === 'crafted');
  const materials = objects.filter(o => o.item_category === 'material');

  let md = '# Objects\n\n';
  md += 'Placeable objects can be picked up, stored in your cart, thrown at enemies, or built into fortifications.\n';
  md += 'Raw materials can also be thrown but deal reduced damage.\n\n';

  md += '## Placeable Objects\n\n';
  md += '| Object | Weight | Solo Liftable | Throw Tier |\n';
  md += '|---|---|---|---|\n';
  for (const obj of crafted) {
    const solo = obj.liftable_solo ? 'Yes' : '**No** — party required';
    md += `| **${obj.name}** | ${obj.weight} kg | ${solo} | ${obj.throw_tier ?? '—'} |\n`;
  }
  md += '\n';

  md += '### Throw Tiers\n\n';
  md += '| Tier | Impact |\n|---|---|\n';
  md += '| Light | Low damage, great for quick harassment |\n';
  md += '| Medium | Reliable damage, suits most encounters |\n';
  md += '| Heavy | Serious damage, worth the extra cart weight |\n';
  md += '| Massive | Catastrophic — reserved for coordinated party throws |\n\n';

  md += '### Object Descriptions\n\n';
  for (const obj of crafted) {
    md += `**${obj.name}** *(${obj.weight} kg)*\n\n${obj.description}\n\n`;
  }

  if (materials.length > 0) {
    md += '---\n\n## Raw Materials\n\n';
    md += 'Materials deal significantly reduced damage when thrown. They are intended as crafting inputs, not weapons.\n\n';
    md += '| Material | Weight | Description |\n|---|---|---|\n';
    for (const obj of materials) {
      md += `| **${obj.name}** | ${obj.weight} kg | ${obj.description} |\n`;
    }
    md += '\n';
  }

  write('objects.md', md);
}

// ── Mechanics ────────────────────────────────────────────────────────────────

function generateMechanics() {
  const mechanics = readJson('mechanics/mechanics.json');
  if (!mechanics) return;

  let md = '# Mechanics\n\n';
  md += 'How Recursion works — controls, modes, and core systems.\n\n';

  const byCategory = {};
  for (const m of mechanics) {
    const cat = m.category || 'General';
    if (!byCategory[cat]) byCategory[cat] = [];
    byCategory[cat].push(m);
  }

  for (const [category, items] of Object.entries(byCategory)) {
    md += `## ${category}\n\n`;
    for (const m of items) {
      md += `### ${m.name}`;
      if (m.hotkey) md += `  \`${m.hotkey}\``;
      md += '\n\n';
      md += `${m.description}\n\n`;
      if (m.details) md += `${m.details}\n\n`;
      if (m.tips && m.tips.length > 0) {
        md += '**Tips:**\n';
        for (const tip of m.tips) md += `- ${tip}\n`;
        md += '\n';
      }
    }
  }

  write('mechanics.md', md);
}

// ── Enemies ──────────────────────────────────────────────────────────────────

function generateEnemies() {
  const enemies = readJson('enemies/enemies.json');
  if (!enemies) return;

  let md = '# Enemies\n\n';
  md += 'Enemies threaten your structures and must be defeated using throw and smash mechanics.\n\n';
  md += '> **Note:** Monster combat values are intentionally not listed here. Discover their strength through play.\n\n';

  for (const enemy of enemies) {
    if (enemy.wiki_visible === false) continue;
    // "secret" block is intentionally never read or written

    md += `## ${enemy.name}\n\n`;
    md += `${enemy.description}\n\n`;
    if (enemy.threat_level) md += `**Threat Level:** ${enemy.threat_level}\n\n`;
    if (enemy.behavior)     md += `**Behavior:** ${enemy.behavior}\n\n`;
    if (enemy.weaknesses && enemy.weaknesses.length > 0) {
      md += `**Weaknesses:** ${enemy.weaknesses.join(', ')}\n\n`;
    }
    if (enemy.resistances && enemy.resistances.length > 0) {
      md += `**Resistances:** ${enemy.resistances.join(', ')}\n\n`;
    }
    if (enemy.tips && enemy.tips.length > 0) {
      md += '**Tips:**\n';
      for (const tip of enemy.tips) md += `- ${tip}\n`;
      md += '\n';
    }
  }

  write('enemies.md', md);
}

// ── Classes ──────────────────────────────────────────────────────────────────

function generateClasses() {
  const classes = readJson('classes/classes.json');
  if (!classes) return;

  let md = '# Classes\n\n';
  md += 'Classes are not fixed roles — they are starting points. Your stat allocation determines whether you become a Destroyer, a Builder, or something in between.\n\n';

  for (const cls of classes) {
    md += `## ${cls.name}\n\n`;
    md += `${cls.description}\n\n`;

    md += '| Stat | Base Value |\n|---|---|\n';
    for (const [stat, val] of Object.entries(cls.base_stats)) {
      const label = stat.charAt(0).toUpperCase() + stat.slice(1);
      md += `| ${label} | ${val} |\n`;
    }
    md += '\n';

    if (cls.throw_damage_multiplier) {
      md += `**Throw Damage Multiplier:** ×${cls.throw_damage_multiplier}\n\n`;
    }
    if (cls.lift_capacity_formula) {
      md += `**Lift Capacity Formula:** \`${cls.lift_capacity_formula}\`\n\n`;
    }
    if (cls.skills && cls.skills.length > 0) {
      md += `**Starting Skills:** ${cls.skills.join(', ')}\n\n`;
    }
  }

  write('classes.md', md);
}

// ── Carts ────────────────────────────────────────────────────────────────────

function generateCarts() {
  const carts = readJson('carts/carts.json');
  if (!carts) return;

  let md = '# Carts\n\n';
  md += 'Your cart stores the objects you pick up. Upgrading your cart increases capacity and unlocks perk slots.\n\n';

  md += '| Cart | Tier | Max Weight | Perk Slots | Overload Penalty |\n';
  md += '|---|---|---|---|---|\n';
  for (const cart of carts) {
    const penalty = `−${Math.round(cart.overload_speed_penalty * 100)}% speed`;
    md += `| **${cart.name}** | ${cart.tier} | ${cart.max_weight} kg | ${cart.perk_slots} | ${penalty} |\n`;
  }
  md += '\n';

  for (const cart of carts) {
    md += `## ${cart.name}\n\n${cart.description}\n\n`;
    if (cart.craft_cost && cart.craft_cost.length > 0) {
      md += '**Craft Cost:**\n';
      for (const c of cart.craft_cost) md += `- ${c.quantity}× ${c.item_id}\n`;
      md += '\n';
    } else {
      md += '*No craft cost — available from the start.*\n\n';
    }
  }

  write('carts.md', md);
}

// ── Index ────────────────────────────────────────────────────────────────────

function generateIndex() {
  const date = new Date().toISOString().split('T')[0];
  const md =
    `# Recursion — Wiki\n\n` +
    `Welcome to the Recursion player wiki.\n\n` +
    `## Contents\n\n` +
    `- [Mechanics](mechanics.md) — controls, modes, and core systems\n` +
    `- [Objects](objects.md) — every placeable object and its properties\n` +
    `- [Enemies](enemies.md) — what you will be fighting\n` +
    `- [Classes](classes.md) — how stats shape your role\n` +
    `- [Carts](carts.md) — cart tiers, capacity, and upgrades\n\n` +
    `---\n\n` +
    `*Auto-generated from \`/content\` — do not edit this file directly. Run \`node scripts/generate-wiki.js\` to regenerate.*\n` +
    `*Last generated: ${date}*\n`;
  write('index.md', md);
}

// ── Run ──────────────────────────────────────────────────────────────────────

console.log('Generating wiki...');
generateObjects();
generateMechanics();
generateEnemies();
generateClasses();
generateCarts();
generateIndex();
console.log('Done.');
