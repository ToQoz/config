/**
 * Slack search operations.
 *
 * Subcommands:
 *   messages <query>    Search messages
 *   files    <query>    Search files
 *   all      <query>    Search messages and files (search.all endpoint)
 *
 * Options:
 *   --channel <name|id>   Limit to a channel (appended as "in:<name>")
 *   --user <@handle|U..>  Limit to a user ("from:<handle>")
 *   --after  YYYY-MM-DD   Only after date
 *   --before YYYY-MM-DD   Only before date
 *   --limit  N            Results per page (default 20)
 *   --workspace <url>     Workspace to use
 *
 * Note: search endpoints require a user token (xoxc or xoxp).
 *       Bot tokens (xoxb) do not have search:read scope.
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
  const query = positional[1];

  if (!cmd || !query) {
    usage("Usage: slack-cli search <messages|files|all> <query> [options]");
  }

  const type = cmd as "messages" | "files" | "all";
  if (!["messages", "files", "all"].includes(type)) {
    usage("Usage: slack-cli search <messages|files|all> <query> [options]");
  }

  let q = query!;
  if (flags["channel"]) q += ` in:${(flags["channel"] as string).replace(/^#/, "")}`;
  if (flags["user"]) q += ` from:${(flags["user"] as string).replace(/^@/, "")}`;
  if (flags["after"]) q += ` after:${flags["after"]}`;
  if (flags["before"]) q += ` before:${flags["before"]}`;

  const data = await slackGet(
    `search.${type}`,
    {
      query: q,
      count: Number(flags["limit"] ?? 20),
      highlight: false,
    },
    auth,
  );

  output(data);
}
