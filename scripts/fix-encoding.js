#!/usr/bin/env node

/**
 * Recursion — Encoding Fix Utility
 *
 * Repairs mojibake caused by reading UTF-8 files as Windows-1252 then
 * re-saving as UTF-8. Each 3-byte UTF-8 sequence (for characters like em
 * dashes and arrows) got interpreted as 3 separate Windows-1252 characters,
 * each of which was then individually encoded back to UTF-8 — tripling the
 * byte count and producing the garbled sequences visible in the files.
 *
 * Usage:
 *   node scripts/fix-encoding.js           — fix all .md files
 *   node scripts/fix-encoding.js --dry-run — report without writing
 *   node scripts/fix-encoding.js --check   — exit 1 if any file needs fixing
 *
 * Importable:
 *   import { fixFile, scanFiles } from './scripts/fix-encoding.js'
 */

import { readFileSync, writeFileSync, readdirSync, statSync } from "fs";
import { join, extname } from "path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/^\/([A-Z]:)/, "$1");

// ---------------------------------------------------------------------------
// Mojibake → correct Unicode mappings.
//
// The corruption chain: UTF-8 bytes read as Windows-1252 codepoints, then
// those codepoints written back as UTF-8. Each entry below is:
//   [corrupted_string, correct_string]
//
// Unicode escapes used so the source file itself is immune to the same bug.
//
// Derivation for each entry (UTF-8 bytes → Win-1252 chars → corrupted UTF-8):
//   0xE2 → U+00E2 (â)   0x80 → U+20AC (€)
//   0x86 → U+2020 (†)   0x90 → U+0090 (C1 ctrl, may be dropped)
//   0x92 → U+2019 (')   0x93 → U+201C (")   0x94 → U+201D (")
//   0x96 → U+2013 (–)   0x98 → U+02DC (˜)   0x99 → U+2122 (™)
//   0x9C → U+0153 (œ)   0xA6 → U+00A6 (¦)
// ---------------------------------------------------------------------------
const FIXES = [
  // --- Arrows (E2 86 xx) — must come before em/en dash to avoid partial matches ---
  // Rightwards arrow →  (U+2192, UTF-8: E2 86 92)
  ["â†’", "→"],
  // Leftwards arrow ←   (U+2190, UTF-8: E2 86 90)  — 0x90 passed as U+0090
  ["â†", "←"],
  // Leftwards arrow ←   — 0x90 dropped entirely (appears as just â†)
  ["â†", "←"],
  // Upwards arrow ↑     (U+2191, UTF-8: E2 86 91)  — 0x91 → U+2018
  ["â†‘", "↑"],
  // Downwards arrow ↓   (U+2193, UTF-8: E2 86 93)  — 0x93 → U+201C
  ["â†“", "↓"],

  // --- Smart quotes and punctuation (E2 80 xx) ---
  // Em dash —           (U+2014, UTF-8: E2 80 94)  — 0x94 → U+201D
  ["â€”", "—"],
  // En dash –           (U+2013, UTF-8: E2 80 93)  — 0x93 → U+201C
  ["â€“", "–"],
  // Left single quote ' (U+2018, UTF-8: E2 80 98)  — 0x98 → U+02DC
  ["â€˜", "‘"],
  // Right single quote '(U+2019, UTF-8: E2 80 99)  — 0x99 → U+2122
  ["â€™", "’"],
  // Left double quote " (U+201C, UTF-8: E2 80 9C)  — 0x9C → U+0153
  ["â€œ", "“"],
  // Right double quote "(U+201D, UTF-8: E2 80 9D)  — 0x9D → U+009D (C1 ctrl)
  ["â€", "”"],
  // Ellipsis …          (U+2026, UTF-8: E2 80 A6)  — 0xA6 → U+00A6
  ["â€¦", "…"],
  // Bullet •            (U+2022, UTF-8: E2 80 A2)  — 0xA2 → U+00A2
  ["â€¢", "•"],
];

/**
 * Fix encoding corruption in a single string. Returns the fixed string and
 * a count of replacements made.
 */
export function fixString(content) {
  let result = content;
  let totalFixes = 0;

  for (const [broken, correct] of FIXES) {
    let count = 0;
    const fixed = result.replaceAll(broken, () => { count++; return correct; });
    result = fixed;
    totalFixes += count;
  }

  return { content: result, fixes: totalFixes };
}

/**
 * Fix a single file. Returns a report object.
 */
export function fixFile(filePath, dryRun = false) {
  const original = readFileSync(filePath, "utf8");
  const { content, fixes } = fixString(original);

  if (fixes > 0 && !dryRun) {
    writeFileSync(filePath, content, { encoding: "utf8" });
  }

  return {
    path: filePath,
    fixes,
    changed: fixes > 0,
  };
}

/**
 * Recursively collect all files matching the given extensions under root.
 */
function collectFiles(dir, extensions, results = []) {
  for (const entry of readdirSync(dir)) {
    if (entry.startsWith(".") && entry !== ".claude") continue;
    const full = join(dir, entry);
    const stat = statSync(full);
    if (stat.isDirectory()) {
      collectFiles(full, extensions, results);
    } else if (extensions.includes(extname(entry).toLowerCase())) {
      results.push(full);
    }
  }
  return results;
}

/**
 * Scan all files of the given extensions under the project root.
 * Returns a summary report.
 */
export function scanFiles(extensions = [".md"], dryRun = false) {
  const files = collectFiles(ROOT, extensions);
  const reports = files.map(f => fixFile(f, dryRun));
  const changed = reports.filter(r => r.changed);
  return { files: reports, changed, total: files.length };
}

// ---------------------------------------------------------------------------
// CLI entry point
// ---------------------------------------------------------------------------
if (process.argv[1] && process.argv[1].endsWith("fix-encoding.js")) {
  const dryRun = process.argv.includes("--dry-run");
  const checkOnly = process.argv.includes("--check");

  const { changed, total } = scanFiles([".md"], dryRun || checkOnly);

  if (changed.length === 0) {
    console.log(`Encoding OK — ${total} file(s) checked, none needed fixing.`);
    process.exit(0);
  }

  const verb = dryRun || checkOnly ? "needs fixing" : "fixed";
  console.log(`\nEncoding ${verb} in ${changed.length} of ${total} file(s):\n`);
  for (const r of changed) {
    const rel = r.path.replace(ROOT, "").replace(/^[\\/]/, "");
    console.log(`  ${r.fixes.toString().padStart(3)} replacement(s)  ${rel}`);
  }
  console.log("");

  if (checkOnly && changed.length > 0) {
    console.error("Run `node scripts/fix-encoding.js` to repair.");
    process.exit(1);
  }
}
