/**
 * Draft editor — opens a local browser-based rich-text editor for composing
 * Slack messages before sending them via the API.
 */

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import {
  slackGet,
  slackPost,
  parseSlackUrl,
  resolveChannel,
  usage,
  type WorkspaceAuth,
} from "./helpers/index.ts";

const __dirname = dirname(fileURLToPath(import.meta.url));
const EDITOR_TEMPLATE = readFileSync(resolve(__dirname, "files/editor.html"), "utf-8");

type Flags = Record<string, string | boolean>;

export async function cmdDraft(positional: string[], flags: Flags, auth: WorkspaceAuth) {
  const target = positional[1];
  if (!target) usage("Usage: slack-cli message draft <channel|url> [initial-text]");

  const initialText = positional.slice(2).join(" ");
  const parsed = parseSlackUrl(target);

  let channel: string;
  let threadTs: string | undefined;
  let displayTarget: string;
  let parentMessage: string | undefined;
  let teamId: string | undefined;

  if (parsed) {
    channel = parsed.channel;
    threadTs = parsed.threadTs ?? parsed.ts;
    const [chanInfo, parentMsg] = await Promise.all([
      slackGet<{ channel?: { name?: string; is_im?: boolean; user?: string; context_team_id?: string } }>(
        "conversations.info", { channel }, auth,
      ).catch(() => null),
      slackGet<{ messages?: Array<{ text?: string }> }>(
        "conversations.history",
        { channel, latest: threadTs, oldest: threadTs, inclusive: true, limit: 1 },
        auth,
      ).catch(() => null),
    ]);
    displayTarget = await resolveChannelDisplayName(chanInfo?.channel, auth);
    parentMessage = parentMsg?.messages?.[0]?.text;
    teamId = chanInfo?.channel?.context_team_id;
  } else {
    channel = await resolveChannel(target, auth);
    displayTarget = target.startsWith("#") ? target : `#${target}`;
    threadTs = flags["thread-ts"] as string | undefined;
    if (threadTs) {
      const parentMsg = await slackGet<{ messages?: Array<{ text?: string }> }>(
        "conversations.history",
        { channel, latest: threadTs, oldest: threadTs, inclusive: true, limit: 1 },
        auth,
      ).catch(() => null);
      parentMessage = parentMsg?.messages?.[0]?.text;
    }
  }

  let resolveReady: () => void;
  const done = new Promise<void>((r) => { resolveReady = r; });

  function readBody(req: IncomingMessage): Promise<string> {
    return new Promise((resolve) => {
      const chunks: Buffer[] = [];
      req.on("data", (c: Buffer) => chunks.push(c));
      req.on("end", () => resolve(Buffer.concat(chunks).toString("utf-8")));
    });
  }

  const server = createServer(async (req: IncomingMessage, res: ServerResponse) => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host}`);

    if (req.method === "GET" && url.pathname === "/") {
      res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
      res.end(renderEditorHtml(displayTarget, auth.teamName ?? auth.workspaceUrl, initialText, threadTs, parentMessage));
      return;
    }

    if (req.method === "POST" && url.pathname === "/send") {
      const raw = await readBody(req);
      const { text, thread_ts } = JSON.parse(raw) as {
        text: string;
        thread_ts?: string | null;
      };
      try {
        const body: Record<string, unknown> = { channel, text };
        if (thread_ts) body.thread_ts = thread_ts;
        const result = await slackPost<{ channel: string; ts: string }>(
          "chat.postMessage",
          body,
          auth,
        );
        const msgUrl =
          `${auth.workspaceUrl}/archives/${result.channel}/p${result.ts.replace(".", "")}`;
        // slack:// URL scheme to open the message in Slack Desktop
        const slackUrl = teamId
          ? `slack://channel?team=${teamId}&id=${result.channel}&message=${result.ts}`
          : null;
        setTimeout(() => resolveReady(), 1500);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: true, message_url: msgUrl, slack_url: slackUrl }));
      } catch (e) {
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ ok: false, error: (e as Error).message }));
      }
      return;
    }

    if (url.pathname === "/close") {
      setTimeout(() => resolveReady(), 100);
      res.end("ok");
      return;
    }

    res.writeHead(404);
    res.end("Not Found");
  });

  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const addr = server.address() as { port: number };
  const editorUrl = `http://127.0.0.1:${addr.port}`;

  console.error(`Draft editor: ${editorUrl}`);
  spawn("open", [editorUrl], { detached: true, stdio: "ignore" }).unref();

  process.on("SIGINT", () => resolveReady());
  await done;
  server.close();
}

async function resolveChannelDisplayName(
  chanInfo: { name?: string; is_im?: boolean; user?: string } | null | undefined,
  auth: WorkspaceAuth,
): Promise<string> {
  if (!chanInfo) return "(unknown)";
  // DM channel: resolve user name
  if (chanInfo.is_im && chanInfo.user) {
    try {
      const userInfo = await slackGet<{ user?: { real_name?: string; name?: string } }>(
        "users.info", { user: chanInfo.user }, auth,
      );
      const name = userInfo.user?.real_name || userInfo.user?.name;
      if (name) return `DM: ${name}`;
    } catch { /* fall through */ }
    return `DM: ${chanInfo.user}`;
  }
  if (chanInfo.name) return `#${chanInfo.name}`;
  return "(unknown)";
}

function renderEditorHtml(
  target: string,
  workspace: string,
  initialText: string,
  threadTs?: string,
  parentMessage?: string,
): string {
  const escapeHtml = (s: string) => s.replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
  const parentBlockHtml = parentMessage
    ? `<div class="reply-context"><div class="reply-context-label">Replying to:</div><div class="reply-context-text">${escapeHtml(parentMessage)}</div></div>`
    : "";
  return renderTemplate(EDITOR_TEMPLATE, {
    targetHtml: escapeHtml(target),
    workspaceHtml: escapeHtml(workspace),
    threadLabelHtml: threadTs ? " (thread reply)" : "",
    parentBlockHtml,
    initialTextJson: JSON.stringify(initialText),
    threadTsJson: JSON.stringify(threadTs ?? null),
  });
}

function renderTemplate(template: string, values: Record<string, string>): string {
  return template.replace(/\{\{(\w+)\}\}/g, (_, key) => {
    if (!(key in values)) throw new Error(`Missing template value: ${key}`);
    return values[key];
  });
}
