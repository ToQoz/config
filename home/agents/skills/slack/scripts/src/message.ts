/**
 * Slack message operations.
 *
 * Subcommands:
 *   get    <url|channel --ts ts>        Fetch a single message
 *   list   <url>                        Fetch full thread replies
 *   list   <channel> [--limit N]        Fetch channel history
 *   draft  <channel|url> [initial-text] Open browser rich-text editor
 *   send   <channel|url> <text>         Post a message
 *   edit   <url|channel --ts ts> <text> Edit a message
 *   delete <url|channel --ts ts>        Delete a message
 *   react  add|remove <url> <emoji>     Add/remove reaction
 *
 * Common options: --workspace <url-or-substring>
 */

import {
  loadAuth,
  getWorkspaceAuth,
  slackGet,
  slackPost,
  parseSlackUrl,
  resolveChannel,
  parseArgs,
  output,
  fatal,
  usage,
  type WorkspaceAuth,
} from "./helpers/index.ts";
import { cmdDraft } from "./draft.ts";

export async function main(args: string[]) {
  const { flags, positional } = parseArgs(args);
  const workspace = flags["workspace"] as string | undefined;
  const config = await loadAuth();
  const auth = getWorkspaceAuth(config, workspace);
  const cmd = positional[0];

  switch (cmd) {
    case "get":    await cmdGet(positional, flags, auth);    break;
    case "list":   await cmdList(positional, flags, auth);   break;
    case "draft":  await cmdDraft(positional, flags, auth);  break;
    case "send":   await cmdSend(positional, flags, auth);   break;
    case "edit":   await cmdEdit(positional, flags, auth);   break;
    case "delete": await cmdDelete(positional, flags, auth); break;
    case "react":  await cmdReact(positional, flags, auth);  break;
    default: usage(
      "Usage: slack-cli message <get|list|draft|send|edit|delete|react> [args]\n" +
      "       slack-cli message get <url|channel --ts ts>\n" +
      "       slack-cli message list <url|channel> [--limit N] [--thread-ts ts]\n" +
      "       slack-cli message draft <channel|url> [text]\n" +
      "       slack-cli message send <channel|url> <text>\n" +
      "       slack-cli message edit <url> <text>\n" +
      "       slack-cli message delete <url>\n" +
      "       slack-cli message react add|remove <url> <emoji>",
    );
  }
}

type Flags = Record<string, string | boolean>;

// ── get ───────────────────────────────────────────────────────────

async function cmdGet(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message get <url|channel --ts ts>");

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );

  const data = await slackGet<{ messages: unknown[] }>(
    "conversations.history",
    { channel, latest: ts, oldest: ts, inclusive: true, limit: 1 },
    auth,
  );

  const msg = data.messages[0];
  if (!msg) fatal(`Message not found: channel=${channel} ts=${ts}`);
  output({ message: msg });
}

// ── list ──────────────────────────────────────────────────────────

async function cmdList(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message list <url|channel> [--limit N] [--thread-ts ts]");

  const limit = Number(flags["limit"] ?? 25);
  const threadTsFlag = flags["thread-ts"] as string | undefined;
  const parsed = parseSlackUrl(target);

  if (parsed) {
    const threadTs = threadTsFlag ?? parsed.threadTs ?? parsed.ts;
    const data = await slackGet<{ messages: unknown[]; has_more: boolean }>(
      "conversations.replies",
      { channel: parsed.channel, ts: threadTs, limit },
      auth,
    );
    output({ messages: data.messages, has_more: data.has_more });
  } else {
    const channel = await resolveChannel(target, auth);
    if (threadTsFlag) {
      const data = await slackGet<{ messages: unknown[]; has_more: boolean }>(
        "conversations.replies",
        { channel, ts: threadTsFlag, limit },
        auth,
      );
      output({ messages: data.messages, has_more: data.has_more });
    } else {
      const oldest = flags["oldest"] as string | undefined;
      const latest = flags["latest"] as string | undefined;
      const data = await slackGet<{ messages: unknown[]; has_more: boolean }>(
        "conversations.history",
        { channel, limit, oldest, latest },
        auth,
      );
      output({ messages: data.messages, has_more: data.has_more });
    }
  }
}

// ── send ──────────────────────────────────────────────────────────

async function cmdSend(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  const text = positional.slice(2).join(" ");
  if (!target || !text) usage("Usage: slack-cli message send <channel|url> <text>");

  const parsed = parseSlackUrl(target);
  const body: Record<string, unknown> = { text };

  if (parsed) {
    body.channel = parsed.channel;
    body.thread_ts = parsed.threadTs ?? parsed.ts;
  } else {
    body.channel = await resolveChannel(target, auth);
    if (flags["thread-ts"]) body.thread_ts = flags["thread-ts"];
  }

  const result = await slackPost<{ channel: string; ts: string }>(
    "chat.postMessage",
    body,
    auth,
  );
  const messageUrl =
    `${auth.workspaceUrl}/archives/${result.channel}/p${result.ts.replace(".", "")}`;
  output({ ok: true, ts: result.ts, channel: result.channel, message_url: messageUrl });
}

// ── edit ──────────────────────────────────────────────────────────

async function cmdEdit(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  const text = positional.slice(2).join(" ");
  if (!target || !text) usage("Usage: slack-cli message edit <url|channel --ts ts> <text>");

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );
  const result = await slackPost("chat.update", { channel, ts, text }, auth);
  output(result);
}

// ── delete ────────────────────────────────────────────────────────

async function cmdDelete(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message delete <url|channel --ts ts>");

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );
  const result = await slackPost("chat.delete", { channel, ts }, auth);
  output(result);
}

// ── react ─────────────────────────────────────────────────────────

async function cmdReact(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const action = positional[1];
  const target = positional[2];
  const emoji = positional[3];
  if (!action || !target || !emoji) {
    usage("Usage: slack-cli message react <add|remove> <url|channel --ts ts> <emoji>");
  }

  const { channel, ts } = await resolveMessageTarget(
    target, flags["ts"] as string | undefined, auth,
  );
  const endpoint = action === "add" ? "reactions.add" : "reactions.remove";
  const result = await slackPost(endpoint, { channel, timestamp: ts, name: emoji }, auth);
  output(result);
}

// ── shared ────────────────────────────────────────────────────────

async function resolveMessageTarget(
  target: string,
  tsFlag: string | undefined,
  auth: WorkspaceAuth,
): Promise<{ channel: string; ts: string }> {
  const parsed = parseSlackUrl(target);
  if (parsed) {
    return { channel: parsed.channel, ts: tsFlag ?? parsed.ts };
  }
  if (!tsFlag) {
    fatal(
      `--ts is required when targeting a channel by name.\n` +
      `  slack-cli message get ${target} --ts 1700000000.000000`,
    );
  }
  const channel = await resolveChannel(target, auth);
  return { channel, ts: tsFlag! };
}
