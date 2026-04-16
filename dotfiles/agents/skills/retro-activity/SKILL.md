---
name: retro-activity
description: Weekly work retrospective — time estimates, patterns, and improvement suggestions.
user-invocable: true
allowed-tools: Bash(python3 ./scripts/analyze.py)
---

# Retro Activity

Retrospective analysis of the user's work: estimate time spent, review work patterns, and suggest improvements.

## Step 1: Collect data

Run the collection script. It's located at `scripts/analyze.py` relative to this SKILL.md file.

```bash
python3 ./scripts/analyze.py
```

The script uses `ghq list` and `ghq root` to find repositories automatically. It outputs the path to the generated data file (e.g. `~/agents/retro-activity/202604W3/data.json`).

To compare with previous weeks, check for other directories under `~/agents/retro-activity/`.

## Step 2: Read and evaluate

Read the `data.json` file. It contains raw data per repository:

- **commits** — list of commits with timestamp, sha, subject, insertions, deletions, files_changed
- **commit_sessions** — commit timestamps grouped into sessions (30-min gap)
- **agent_sessions** — Claude conversation timestamps grouped into sessions
- **diff_stats** — total insertions, deletions, files_changed
- **file_types** — file extension counts (e.g. `{".ts": 42, ".md": 5}`)

## Step 3: Estimate time

For each repo, estimate two values:

### Actual time (how long the user really spent)

Merge commit sessions and agent sessions into unified work intervals:
- Add a ~10 minute startup buffer before the first event in each session
- Set a minimum session length of ~15 minutes for commit sessions, ~5 minutes for agent sessions
- Merge overlapping intervals
- Sum the total duration

Compute actual time **per repo independently** — do not deduplicate across repos. When the user works on two projects in parallel during the same hour, each repo gets the full hour. This reflects the real wall-clock time the user dedicated attention to each project.

### Normal time (how long this would take without AI)

Estimate based on diff size and file types:
- Production code: ~40 lines/hour
- Config (json, yaml, nix, toml, lock, etc.): ~120 lines/hour
- Docs (md, txt, rst): ~150 lines/hour
- Default: ~60 lines/hour

Use the file_types breakdown to compute a weighted rate, then divide total lines changed by that rate.

For agent-only sessions (no commits), normal time is harder to estimate — use ~1.5x the actual time as a rough proxy for exploration/planning work.

## Step 4: Report

Present a summary to the user. Group repositories by GitHub owner/organization (the second segment of the repo path, e.g. `github.com/ToQoz/config` → **ToQoz**). Show an org-level subtotal row for orgs with multiple repos. Include overall totals at the bottom.

For each repo:
- **actual time** (bold) — the merged session estimate
- normal time — the without-AI benchmark
- Key stats: commit count, +insertions/-deletions, session counts
- If previous week data exists, show percentage change

The overall total is a simple sum of per-repo actuals. Because parallel work is counted fully for each repo, the total may exceed wall-clock hours — this is intentional and reflects total effort across projects.

Note in the report:
- Actual time is based on observable signals. Invisible work (reading docs, thinking, meetings) is not captured.
- Normal time is a rough heuristic, not a precise measure.
- Agent-only sessions (no resulting commits) still count as real work time.

## Step 5: Suggest improvements

After presenting the report, analyze the data for patterns and provide concrete suggestions to help the user perform better next week. Focus on:

### Work rhythm
- Are sessions clustered at certain times? Are there very long unbroken sessions (fatigue risk) or very fragmented short sessions (context-switching cost)?
- Is there deep-work time or mostly reactive short bursts?

### AI leverage
- Compare actual vs normal time per repo. Where is AI providing the most leverage? Where is it underutilized?
- Are there repos with high agent session count but low commit output? That could indicate exploration (fine) or friction (worth investigating).

### Commit patterns
- Are commits well-scoped (small, focused) or large and monolithic?
- Are there long gaps between commits within a session (possible sign of debugging struggles or blockers)?

### Prioritization
- Is time allocation across repos aligned with what the user likely considers most important?
- Are there repos consuming disproportionate time relative to output?

### Actionable suggestions
- Provide 2–3 specific, actionable suggestions for next week.
- Frame them positively — build on strengths observed in the data, not just fix weaknesses.
- Be concrete: "Try batching config changes into a single session" is better than "manage your time better."
