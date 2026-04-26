// Verify scripts/fence-wt builds the expected fence config and forwards
// the inner command intact. Uses a stub `fence` binary (via FENCE_BIN env)
// that captures its --settings file and the arguments after `--`, so the
// real fence sandbox is never invoked.
//
// Run from the repo root:
//   node --test t/*.test.mts

import { test } from 'node:test';
import { strict as assert } from 'node:assert';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, chmodSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SCRIPT = `${REPO}/scripts/fence-wt`;

type StubResult = {
  status: number;
  stderr: string;
  stdout: string;
  config: any | null;
  innerArgv: string[] | null;
};

// Build a stub fence in `dir/bin/fence` that writes a JSON dump of its
// argv + the contents of the file passed via --settings to `dir/dump.json`.
function makeStub(dir: string): string {
  const bin = join(dir, 'bin');
  mkdirSync(bin, { recursive: true });
  const dump = join(dir, 'dump.json');
  const stub = `#!/usr/bin/env bash
set -euo pipefail
settings=""
args=()
while (($#)); do
  case "$1" in
    --settings) settings=$2; shift 2 ;;
    --) shift; args=("$@"); break ;;
    *) args+=("$1"); shift ;;
  esac
done
cfg=$(cat "$settings")
${'jq -nc'} --arg cfg "$cfg" --argjson argv "$(printf '%s\\n' "\${args[@]+"\${args[@]}"}" | jq -R . | jq -s .)" '{config: ($cfg|fromjson), argv: $argv}' > "${dump}"
`;
  const path = join(bin, 'fence');
  writeFileSync(path, stub);
  chmodSync(path, 0o755);
  return path;
}

function readDump(stubDir: string): { config: any; argv: string[] } | null {
  const p = join(stubDir, 'dump.json');
  try {
    return JSON.parse(readFileSync(p, 'utf8'));
  } catch {
    return null;
  }
}

function runFenceWt(opts: {
  cwd: string;
  args: string[];
  stub?: string; // path to stub fence binary
  env?: Record<string, string>;
}): StubResult {
  const env: Record<string, string> = { ...process.env, ...(opts.env ?? {}) } as any;
  if (opts.stub) env.FENCE_BIN = opts.stub;
  const r = spawnSync('bash', [SCRIPT, ...opts.args], {
    cwd: opts.cwd,
    env,
    encoding: 'utf8',
  });
  let dump: { config: any; argv: string[] } | null = null;
  if (opts.stub) {
    dump = readDump(dirname(dirname(opts.stub)));
  }
  return {
    status: r.status ?? -1,
    stderr: r.stderr,
    stdout: r.stdout,
    config: dump?.config ?? null,
    innerArgv: dump?.argv ?? null,
  };
}

function gitInit(dir: string) {
  const env = { ...process.env, GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_SYSTEM: '/dev/null' };
  execFileSync('git', ['init', '-q', '-b', 'main', dir], { env });
  execFileSync('git', ['-C', dir, 'config', 'user.email', 't@example.com'], { env });
  execFileSync('git', ['-C', dir, 'config', 'user.name', 'T'], { env });
  execFileSync('git', ['-C', dir, 'commit', '-q', '--allow-empty', '-m', 'init'], { env });
}

function makeWorkspace() {
  const root = mkdtempSync(join(tmpdir(), 'fence-wt-test-'));
  return realpathSync(root);
}

test('regular checkout: emits .git for both git-dir and common-dir, dedup', () => {
  const ws = makeWorkspace();
  const repo = join(ws, 'repo');
  mkdirSync(repo);
  gitInit(repo);
  const stub = makeStub(ws);

  const r = runFenceWt({ cwd: repo, args: ['--', 'echo', 'hi'], stub });
  assert.equal(r.status, 0, `stderr=${r.stderr}`);
  assert.deepEqual(r.config.extends, 'code');
  // unique-sorted: '.' and the .git path (git-dir == common-dir in plain checkout)
  const writes: string[] = r.config.filesystem.allowWrite;
  assert.ok(writes.includes('.'), `expected '.' in ${JSON.stringify(writes)}`);
  assert.ok(writes.some((w) => w.endsWith('/.git')), `expected .git path in ${JSON.stringify(writes)}`);
  assert.equal(writes.length, 2, `should dedup git-dir==common-dir, got ${JSON.stringify(writes)}`);
  assert.deepEqual(r.innerArgv, ['echo', 'hi']);
});

test('worktree: allowWrite includes both per-worktree and common .git paths', () => {
  const ws = makeWorkspace();
  const repo = join(ws, 'repo');
  mkdirSync(repo);
  gitInit(repo);
  const wtPath = join(ws, 'wt-feature');
  execFileSync('git', ['-C', repo, 'worktree', 'add', '-q', wtPath, '-b', 'feature'], {
    env: { ...process.env, GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_SYSTEM: '/dev/null' },
  });
  const stub = makeStub(ws);

  const r = runFenceWt({ cwd: wtPath, args: ['--', 'true'], stub });
  assert.equal(r.status, 0, `stderr=${r.stderr}`);
  const writes: string[] = r.config.filesystem.allowWrite;
  assert.ok(writes.includes('.'));
  assert.ok(
    writes.some((w) => w.endsWith('/.git/worktrees/wt-feature')),
    `expected per-worktree path in ${JSON.stringify(writes)}`,
  );
  assert.ok(
    writes.some((w) => w.endsWith('/.git') && !w.endsWith('/worktrees/wt-feature')),
    `expected common .git path in ${JSON.stringify(writes)}`,
  );
});

test('argument parsing: -t, -w, --, inner flags pass through verbatim', () => {
  const ws = makeWorkspace();
  const repo = join(ws, 'repo');
  mkdirSync(repo);
  gitInit(repo);
  const stub = makeStub(ws);

  const r = runFenceWt({
    cwd: repo,
    args: ['-t', 'code-strict', '-w', '/tmp/foo', '-w', '/tmp/bar', '--', 'claude', '--resume'],
    stub,
  });
  assert.equal(r.status, 0, `stderr=${r.stderr}`);
  assert.equal(r.config.extends, 'code-strict');
  const writes: string[] = r.config.filesystem.allowWrite;
  assert.ok(writes.includes('/tmp/foo'), JSON.stringify(writes));
  assert.ok(writes.includes('/tmp/bar'), JSON.stringify(writes));
  assert.deepEqual(r.innerArgv, ['claude', '--resume']);
});

test('extra settings: --settings produces array-form extends with abs path', () => {
  const ws = makeWorkspace();
  const repo = join(ws, 'repo');
  mkdirSync(repo);
  gitInit(repo);
  const extra = join(ws, 'extra.json');
  writeFileSync(extra, '{}');
  const stub = makeStub(ws);

  const r = runFenceWt({ cwd: repo, args: ['-s', extra, '--', 'true'], stub });
  assert.equal(r.status, 0, `stderr=${r.stderr}`);
  assert.deepEqual(r.config.extends, ['code', extra]);
});

test('missing value for -w fails with helpful message', () => {
  const ws = makeWorkspace();
  const repo = join(ws, 'repo');
  mkdirSync(repo);
  gitInit(repo);
  const stub = makeStub(ws);

  const r = runFenceWt({ cwd: repo, args: ['-w'], stub });
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /missing value for -w/);
});

test('non-git directory fails with explicit message', () => {
  const ws = makeWorkspace();
  const stub = makeStub(ws);
  const nongit = join(ws, 'plain');
  mkdirSync(nongit);

  const r = runFenceWt({ cwd: nongit, args: ['--', 'true'], stub });
  assert.notEqual(r.status, 0);
  assert.match(r.stderr, /not inside a git work tree/);
});

test('no -- separator: first non-flag begins inner argv', () => {
  const ws = makeWorkspace();
  const repo = join(ws, 'repo');
  mkdirSync(repo);
  gitInit(repo);
  const stub = makeStub(ws);

  const r = runFenceWt({ cwd: repo, args: ['claude'], stub });
  assert.equal(r.status, 0, `stderr=${r.stderr}`);
  assert.deepEqual(r.innerArgv, ['claude']);
});
