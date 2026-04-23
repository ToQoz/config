/**
 * Slack channel operations.
 *
 * Subcommands:
 *   list            List channels the current user is a member of
 *   list --all      List all public channels in the workspace
 *   list --limit N  Page size (default 100)
 *   list --cursor C Continue pagination with cursor
 *
 * Common options: --workspace <url-or-substring>
 */

import {
  loadAuth,
  getWorkspaceAuth,
  slackGet,
  parseArgs,
  output,
  usage,
} from "./helpers/index.ts";

export async function main(args: string[]) {
  const { flags, positional } = parseArgs(args);
  const workspace = flags["workspace"] as string | undefined;
  const config = await loadAuth();
  const auth = getWorkspaceAuth(config, workspace);
  const cmd = positional[0];

  switch (cmd) {
    case "list": break;
    default: usage(
      "Usage: slack-cli channel list [--all] [--limit N] [--cursor cursor] [--workspace url]",
    );
  }

  const limit = Number(flags["limit"] ?? 100);
  const cursor = flags["cursor"] as string | undefined;
  const all = Boolean(flags["all"]);

  const endpoint = all ? "conversations.list" : "users.conversations";

  const data = await slackGet<{
    channels: unknown[];
    response_metadata?: { next_cursor?: string };
  }>(endpoint, {
    limit,
    cursor,
    types: "public_channel,private_channel,mpim,im",
    exclude_archived: true,
  }, auth);

  output({
    channels: data.channels,
    ...(data.response_metadata?.next_cursor
      ? { next_cursor: data.response_metadata.next_cursor }
      : {}),
  });
}
