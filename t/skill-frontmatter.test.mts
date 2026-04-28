// Verify every skill's SKILL.md frontmatter parses as valid YAML.
//
// Why this exists: codex (and other downstream agents) refuses to load a
// skill whose frontmatter does not parse, with a low-signal error like
// `mapping values are not allowed in this context`. The most common
// cause is an unquoted plain scalar containing `: ` (colon + space).
// Catching the parse failure here makes the breakage visible at commit
// time instead of at agent startup.
//
// We do not own a YAML parser in this repo, so we delegate to yq-go via
// `nix run`. The first invocation may be slow while nix populates the
// store; subsequent runs hit the cache.
//
// Run from the repo root:
//   node --test t/*.test.mts

import { test } from 'node:test';
import { strict as assert } from 'node:assert';
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO: string = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SKILLS: string = `${REPO}/home/agents/skills`;

// Resolve the yq-go binary once via `nix build`. Re-invoking `nix run`
// per-file works but adds ~100ms of CLI startup to every test.
const YQ: string = (() => {
  const out = execFileSync(
    'nix',
    ['build', 'nixpkgs#yq-go', '--no-link', '--print-out-paths'],
    { encoding: 'utf8' },
  ).trim();
  return `${out}/bin/yq`;
})();

function extractFrontmatter(file: string): string {
  const text = readFileSync(file, 'utf8');
  const lines = text.split('\n');
  if (lines[0] !== '---') {
    throw new Error(`${file}: missing opening '---' on line 1`);
  }
  const end = lines.indexOf('---', 1);
  if (end === -1) {
    throw new Error(`${file}: missing closing '---' delimiter`);
  }
  return lines.slice(1, end).join('\n') + '\n';
}

function listSkillFiles(): string[] {
  return readdirSync(SKILLS)
    .map((d) => join(SKILLS, d, 'SKILL.md'))
    .filter((p) => {
      try {
        return statSync(p).isFile();
      } catch {
        return false;
      }
    });
}

for (const file of listSkillFiles()) {
  const skillName = file.split('/').slice(-2, -1)[0];
  test(`frontmatter parses: ${skillName}`, () => {
    const fm = extractFrontmatter(file);
    const r = spawnSync(YQ, ['eval', '.', '-'], { input: fm, encoding: 'utf8' });
    assert.equal(
      r.status,
      0,
      `yq rejected frontmatter of ${file}:\n${r.stderr.trim()}\n` +
        `--- frontmatter ---\n${fm}--- end ---`,
    );
  });
}
