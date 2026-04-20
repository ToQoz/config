---
name: scan-abandoned-sessions
description: Scan `~/.claude/projects/*/*.jsonl` Claude Code session logs to surface truly abandoned sessions — user prompts or assistant work left mid-way and not recoverable from workspace state. Use this whenever the user asks about "abandoned sessions", "forgotten sessions", "half-finished sessions", "放置セッション", "途中のセッション", "今日忘れてるやつ", or otherwise asks to audit recent Claude Code activity for unfinished threads.
---

# scan-abandoned-sessions

## Intent

Claude Code persists each session as a JSONL file at `~/.claude/projects/<project-slug>/<session-uuid>.jsonl`. Each line is a message object with a `type` field (`user` / `assistant` / `summary` / `system`) and a `message.content` payload (text / tool_use / tool_result).

This skill surfaces sessions that are **truly abandoned** — work left mid-way and not recoverable from other sources (git working tree, memory, ongoing conversation, etc.). Sessions that paused for a reason whose state is preserved elsewhere should not be surfaced; otherwise the report drowns in noise and the user stops trusting it.

## Default scan window

Unless the user specifies a range, scan:

```
[ max(cursor, today - 7d),  today ]
```

Cursor file: `<agent-sandbox-directory>/scan-abandoned-sessions/cursor.txt` — contains an ISO-8601 date (`YYYY-MM-DD`) of the most recent completed scan.

- If the cursor file does not exist or is unparseable, scan the last 7 days.
- The 7-day cap exists so that a long gap since the last scan does not produce an overwhelming report. If the user wants earlier sessions, they will ask.

If the user explicitly supplies a range ("last 3 days", "this week", "since 2026-04-15", "全部", "今日だけ"), honor that and **do not update the cursor** — a narrower or custom scan should not advance the "I have reviewed up to here" marker.

After a successful default-window scan, overwrite the cursor file with today's date.

## Procedure

1. **Compute window.** Read cursor, derive `start` and `end` dates as above.
2. **List candidates.** Find `*.jsonl` files under `~/.claude/projects/` modified within `[start, end]`. Exclude any file under a `subagents/` directory — those are child-agent logs already represented by their parent session and would double-count.
3. **Inspect tail.** For each candidate, read the last ~8KB (`tail -c 8192`). JSONL lines can be long, and only the final few entries matter for classification.
4. **Classify** each session using the rules below.
5. **Report** only sessions classified as `abandoned`. Include counts for the ignored categories so the user can sanity-check that the filter is behaving as they expect.
6. **Update cursor** to today's date, but only if (a) the scan completed without error AND (b) the user did not supply a custom range.

## Classification rules

Look at the last several entries in the JSONL tail, then apply in order:

**`in-progress`** — the session's UUID matches the current running session, or the session is an ancestor that delegated to the current agent (check for a recent `Agent` tool_use with no corresponding tool_result). Do not surface; it is the conversation running this skill.

**`setup-noise`** — the session contains only harness checks with no real user instruction. Typical indicators:
- File size ≤ ~6KB AND the only user content is sandbox-denied bash tests (`echo hello > ~/x.txt`, `ls /`, etc.) or `/clear` artifacts.
- No substantive natural-language user prompt anywhere in the tail.

Do not surface. These are harness/sandbox probes, not real work.

**`commit-decision-pause`** — the final assistant turn ends with a question about commit scope, branching strategy, or similar git-flow confirmation ("master に直接コミットしますか、それともトピックブランチを切りますか?"). Do not surface. The relevant state (dirty working tree, uncommitted edits) is already preserved in the repo itself; the user rediscovers it via `git status`, so the unanswered prompt is not actually lost.

**`completed`** — the last assistant message provides natural closure: a summary, a direct answer to the last question, a "完了しました" report, an explicit hand-off, or similar. Do not surface.

**`abandoned`** — surface this. Any of:
- The last entry is a substantive `user` message (a real task or question, not a bash probe) with no subsequent `assistant` response.
- The last `assistant` turn emitted a `tool_use` with no matching `tool_result`.
- A `tool_result` followed by no assistant synthesis.
- An "interrupted by user" / cancellation marker with no continuation afterwards.
- A user task that received a partial answer and was then left hanging with obvious next steps outstanding.

When in doubt between `completed` and `abandoned`, prefer `abandoned` — a false positive costs the user one glance; a false negative costs them the lost work.

## Parallelism

A scan may cover dozens of sessions. If there are more than ~10 candidates, delegate tail-inspection to a general-purpose subagent. Hand it the classification rules verbatim and the candidate file list; have it return only the `abandoned` list plus counts for each other category. This keeps the parent context clean and lets the scan complete in one round-trip.

## Report format

```
放置セッション (<start> 〜 <end>):

- <project-slug-short>/<uuid-first-8> (<HH:MM> 最終更新)
  <1行: 何を依頼し、どこで止まったか>

(以下略 / 以下同様のフォーマット)

---
内訳: abandoned=<N>, completed=<N>, commit-decision-pause=<N>, setup-noise=<N>, in-progress=<N>
```

If zero abandoned: state that plainly and still report the category breakdown so the user can see the filter did its job.

`<project-slug-short>` = drop the `-Users-toqoz-src-github-com-` prefix; keep the trailing project identifier (e.g. `toqoz-sence`, `ToQoz-config`).
