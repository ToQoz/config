/**
 * Unit tests for getWorkspaceAuth.
 *
 * Run:  node --experimental-transform-types --no-warnings=ExperimentalWarning \
 *         --test src/helpers/auth-store.test.ts
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { getWorkspaceAuth, type AuthConfig, type WorkspaceAuth } from "./auth-store.ts";
import { FatalError } from "./cli.ts";

const ws1: WorkspaceAuth = {
  token: "xoxb-111",
  type: "api",
  workspaceUrl: "https://team1.slack.com",
  teamName: "Team 1",
};

const ws2: WorkspaceAuth = {
  token: "xoxc-222",
  cookie: "xoxd-cookie",
  type: "browser",
  workspaceUrl: "https://team2.slack.com",
  teamName: "Team 2",
};

function makeConfig(overrides: Partial<AuthConfig> = {}): AuthConfig {
  return {
    default: "https://team1.slack.com",
    workspaces: {
      "https://team1.slack.com": ws1,
      "https://team2.slack.com": ws2,
    },
    ...overrides,
  };
}

describe("getWorkspaceAuth", () => {
  it("returns the default workspace when no workspace arg given", () => {
    const result = getWorkspaceAuth(makeConfig());
    assert.equal(result.token, "xoxb-111");
    assert.equal(result.teamName, "Team 1");
  });

  it("returns the specified workspace by exact key", () => {
    const result = getWorkspaceAuth(makeConfig(), "https://team2.slack.com");
    assert.equal(result.token, "xoxc-222");
    assert.equal(result.teamName, "Team 2");
  });

  it("matches workspace by substring", () => {
    const result = getWorkspaceAuth(makeConfig(), "team2");
    assert.equal(result.teamName, "Team 2");
  });

  it("returns the only workspace when there is exactly one and no default", () => {
    const config: AuthConfig = {
      workspaces: { "https://only.slack.com": ws1 },
    };
    const result = getWorkspaceAuth(config);
    assert.equal(result.token, "xoxb-111");
  });

  it("throws FatalError when no workspaces configured", () => {
    const config: AuthConfig = { workspaces: {} };
    assert.throws(() => getWorkspaceAuth(config), FatalError);
  });

  it("throws FatalError when multiple workspaces and no default", () => {
    const config = makeConfig({ default: undefined });
    assert.throws(() => getWorkspaceAuth(config), FatalError);
  });

  it("throws FatalError when specified workspace not found", () => {
    assert.throws(() => getWorkspaceAuth(makeConfig(), "nonexistent"), FatalError);
  });
});
