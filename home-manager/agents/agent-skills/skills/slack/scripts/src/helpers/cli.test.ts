/**
 * Unit tests for CLI helpers (parseArgs, output, fatal, usage).
 *
 * Run:  node --experimental-transform-types --no-warnings=ExperimentalWarning \
 *         --test src/helpers/cli.test.ts
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { parseArgs } from "./cli.ts";

describe("parseArgs", () => {
  it("parses positional arguments", () => {
    const result = parseArgs(["get", "https://example.com"]);
    assert.deepEqual(result.positional, ["get", "https://example.com"]);
    assert.deepEqual(result.flags, {});
  });

  it("parses --key value flags", () => {
    const result = parseArgs(["--workspace", "myteam", "--limit", "10"]);
    assert.deepEqual(result.flags, { workspace: "myteam", limit: "10" });
    assert.deepEqual(result.positional, []);
  });

  it("parses boolean flags (no following value)", () => {
    const result = parseArgs(["--all", "--verbose"]);
    assert.deepEqual(result.flags, { all: true, verbose: true });
  });

  it("treats --flag followed by --another-flag as boolean", () => {
    const result = parseArgs(["--all", "--limit", "5"]);
    assert.deepEqual(result.flags, { all: true, limit: "5" });
  });

  it("mixes positional and flags", () => {
    const result = parseArgs(["list", "--all", "--limit", "100", "extra"]);
    assert.deepEqual(result.positional, ["list", "extra"]);
    assert.deepEqual(result.flags, { all: true, limit: "100" });
  });

  it("handles empty args", () => {
    const result = parseArgs([]);
    assert.deepEqual(result.positional, []);
    assert.deepEqual(result.flags, {});
  });

  it("flag at end of args is boolean", () => {
    const result = parseArgs(["cmd", "--dry-run"]);
    assert.deepEqual(result.positional, ["cmd"]);
    assert.deepEqual(result.flags, { "dry-run": true });
  });
});
