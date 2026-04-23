// Verify that files which are shared-by-convention between sibling
// skills are byte-identical. Skills are self-contained (each ships
// its own copy), but drift across copies is a bug.
//
// Run from the repo root:
//   node --test t/*.test.mts
//
// On failure, sync the canonical copy into the divergent path with
// `cp` and re-run. We do not auto-fix because the choice of canonical
// direction is reviewer-judged.
//
// TypeScript runs natively via Node's built-in type-stripping
// (Node ≥ 22.6, default-on since 23). No build step, no tsc.

import { test } from 'node:test';
import { strict as assert } from 'node:assert';
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO: string = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SKILLS: string = `${REPO}/home/agents/skills`;

type SharedFileGroup = {
  /** Filename inside each skill's `scripts/` directory. */
  file: string;
  /** Skill subpaths under `home/agents/skills/` that must hold a
   *  byte-identical copy. The first entry is treated as the reference. */
  paths: [string, ...string[]];
};

const groups: SharedFileGroup[] = [
  {
    file: 'apply_a11y.sh',
    paths: [
      'webapp-a11y-scaling-checks/scripts',
      'webapp-a11y-scaling-in-webview-checks/scripts',
    ],
  },
  {
    file: 'boot_emulator.sh',
    paths: [
      'webapp-a11y-scaling-checks/scripts',
      'webapp-a11y-scaling-in-webview-checks/scripts',
    ],
  },
  {
    file: 'sdkenv.sh',
    paths: [
      'webapp-a11y-scaling-checks/scripts',
      'webapp-a11y-scaling-in-webview-checks/scripts',
    ],
  },
];

for (const { file, paths } of groups) {
  const [refPath, ...others] = paths;
  for (const otherPath of others) {
    test(`shared file in sync: ${file}  (${refPath}  ⇄  ${otherPath})`, () => {
      const ref: string = `${SKILLS}/${refPath}/${file}`;
      const other: string = `${SKILLS}/${otherPath}/${file}`;
      assert.ok(existsSync(ref), `missing reference: ${ref}`);
      assert.ok(existsSync(other), `missing: ${other}`);
      const refContent: string = readFileSync(ref, 'utf8');
      const otherContent: string = readFileSync(other, 'utf8');
      assert.equal(
        otherContent,
        refContent,
        `${file} drifted between ${refPath} and ${otherPath}.\n` +
          `Fix: cp '${ref}' '${other}'   # or vice versa`,
      );
    });
  }
}
