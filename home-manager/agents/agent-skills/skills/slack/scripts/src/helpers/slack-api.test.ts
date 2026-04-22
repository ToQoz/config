/**
 * Unit tests for parseSlackUrl.
 *
 * Run:  node --experimental-transform-types --no-warnings=ExperimentalWarning \
 *         --test src/helpers/slack-api.test.ts
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { parseSlackUrl } from "./slack-api.ts";

describe("parseSlackUrl", () => {
  it("parses a standard Slack message URL", () => {
    const result = parseSlackUrl(
      "https://myteam.slack.com/archives/C01234567/p1700000000123456",
    );
    assert.deepEqual(result, {
      workspaceUrl: "https://myteam.slack.com",
      channel: "C01234567",
      ts: "1700000000.123456",
      threadTs: undefined,
    });
  });

  it("parses a URL with thread_ts query param", () => {
    const result = parseSlackUrl(
      "https://myteam.slack.com/archives/C01234567/p1700000000123456?thread_ts=1699999999.000000&cid=C01234567",
    );
    assert.ok(result);
    assert.equal(result.channel, "C01234567");
    assert.equal(result.ts, "1700000000.123456");
    assert.equal(result.threadTs, "1699999999.000000");
  });

  it("returns null for non-Slack URLs", () => {
    assert.equal(parseSlackUrl("https://example.com/page"), null);
  });

  it("returns null for plain channel names", () => {
    assert.equal(parseSlackUrl("general"), null);
  });

  it("returns null for channel IDs", () => {
    assert.equal(parseSlackUrl("C01234567"), null);
  });

  it("returns null for malformed archive paths", () => {
    assert.equal(
      parseSlackUrl("https://myteam.slack.com/archives/C01234567"),
      null,
    );
  });

  it("handles different workspace domains", () => {
    const result = parseSlackUrl(
      "https://company.enterprise.slack.com/archives/C99999999/p1234567890123456",
    );
    assert.ok(result);
    assert.equal(result.workspaceUrl, "https://company.enterprise.slack.com");
    assert.equal(result.channel, "C99999999");
  });

  it("returns null for empty string", () => {
    assert.equal(parseSlackUrl(""), null);
  });
});
