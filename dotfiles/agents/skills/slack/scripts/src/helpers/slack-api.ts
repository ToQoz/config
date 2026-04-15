// Slack Web API client, URL parsing, and channel resolution.

import { fatal } from "./cli.ts";
import type { WorkspaceAuth } from "./auth-store.ts";

// ── API call helpers ─────────────────────────────────────────────

function apiUrl(endpoint: string, auth: WorkspaceAuth): string {
  if (auth.type === "browser" && auth.workspaceUrl) {
    return `${auth.workspaceUrl.replace(/\/$/, "")}/api/${endpoint}`;
  }
  return `https://slack.com/api/${endpoint}`;
}

function baseHeaders(auth: WorkspaceAuth): Record<string, string> {
  const headers: Record<string, string> = {
    "User-Agent": "slack-skill/1.0 Node",
  };
  if (auth.type === "browser" && auth.cookie) {
    headers["Cookie"] = `d=${encodeURIComponent(auth.cookie)}`;
    headers["Origin"] = "https://app.slack.com";
  } else if (auth.type === "api") {
    headers["Authorization"] = `Bearer ${auth.token}`;
  }
  return headers;
}

async function checkSlackResponse<T = Record<string, unknown>>(
  res: Response,
): Promise<T> {
  if (res.status === 429) {
    const retryAfter = res.headers.get("Retry-After") ?? "?";
    throw new Error(`Slack rate limited; retry after ${retryAfter}s`);
  }
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
  const data = (await res.json()) as Record<string, unknown>;
  if (!data.ok) {
    throw new Error(`Slack API error: ${String(data.error ?? JSON.stringify(data))}`);
  }
  return data as T;
}

export async function slackGet<T = Record<string, unknown>>(
  endpoint: string,
  params: Record<string, string | number | boolean | undefined>,
  auth: WorkspaceAuth,
): Promise<T> {
  const url = apiUrl(endpoint, auth);

  if (auth.type === "browser") {
    const form = new URLSearchParams();
    form.set("token", auth.token);
    for (const [k, v] of Object.entries(params)) {
      if (v !== undefined) form.set(k, String(v));
    }
    const res = await fetch(url, {
      method: "POST",
      headers: { ...baseHeaders(auth), "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    return checkSlackResponse<T>(res);
  }

  const u = new URL(url);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined) u.searchParams.set(k, String(v));
  }
  const res = await fetch(u, { headers: baseHeaders(auth) });
  return checkSlackResponse<T>(res);
}

export async function slackPost<T = Record<string, unknown>>(
  endpoint: string,
  body: Record<string, unknown>,
  auth: WorkspaceAuth,
): Promise<T> {
  const url = apiUrl(endpoint, auth);

  if (auth.type === "browser") {
    const form = new URLSearchParams();
    form.set("token", auth.token);
    for (const [k, v] of Object.entries(body)) {
      if (v !== undefined) {
        form.set(k, typeof v === "object" ? JSON.stringify(v) : String(v));
      }
    }
    const res = await fetch(url, {
      method: "POST",
      headers: { ...baseHeaders(auth), "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });
    return checkSlackResponse<T>(res);
  }

  const res = await fetch(url, {
    method: "POST",
    headers: { ...baseHeaders(auth), "Content-Type": "application/json; charset=utf-8" },
    body: JSON.stringify(body),
  });
  return checkSlackResponse<T>(res);
}

// ── Slack URL parsing ─────────────────────────────────────────────

export interface ParsedSlackUrl {
  workspaceUrl: string;
  channel: string;
  ts: string;
  threadTs?: string;
}

export function parseSlackUrl(input: string): ParsedSlackUrl | null {
  try {
    const u = new URL(input);
    const m = u.pathname.match(/^\/archives\/([A-Z0-9]+)\/p(\d{10})(\d{6})$/);
    if (!m) return null;
    return {
      workspaceUrl: `${u.protocol}//${u.host}`,
      channel: m[1]!,
      ts: `${m[2]}.${m[3]}`,
      threadTs: u.searchParams.get("thread_ts") ?? undefined,
    };
  } catch {
    return null;
  }
}

// ── Channel resolution ────────────────────────────────────────────

const _chanCache = new Map<string, string>();

export async function resolveChannel(
  nameOrId: string,
  auth: WorkspaceAuth,
): Promise<string> {
  const name = nameOrId.replace(/^#/, "");
  if (/^[A-Z][A-Z0-9]{5,}$/.test(name)) return name;

  const cacheKey = `${auth.workspaceUrl}:${name}`;
  if (_chanCache.has(cacheKey)) return _chanCache.get(cacheKey)!;

  let cursor: string | undefined;
  do {
    const data = await slackGet<{
      channels: Array<{ id: string; name: string }>;
      response_metadata?: { next_cursor?: string };
    }>(
      "users.conversations",
      { limit: 200, cursor, types: "public_channel,private_channel,mpim,im", exclude_archived: true },
      auth,
    );
    const found = data.channels.find((c) => c.name === name);
    if (found) {
      _chanCache.set(cacheKey, found.id);
      return found.id;
    }
    cursor = data.response_metadata?.next_cursor || undefined;
  } while (cursor);

  fatal(`Channel not found: ${nameOrId}`);
}
