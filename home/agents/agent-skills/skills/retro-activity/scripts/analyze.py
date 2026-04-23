#!/usr/bin/env python3
"""
Work activity data collector: gathers raw signals from ghq-managed repositories.

Collects commit data and agent conversation timestamps, then saves raw JSON
to ~/agents/retro-activity/YYYYMMW{N}/ for the agent to interpret.
"""

import json
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SESSION_GAP_MINUTES = 30  # timestamps within this gap = same session

JST = timezone(timedelta(hours=9))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def now_jst():
    return datetime.now(JST)


def week_range(ref: datetime):
    """Return (start, end) of the week containing ref. Week starts on Monday."""
    start = ref - timedelta(days=ref.weekday())
    start = start.replace(hour=0, minute=0, second=0, microsecond=0)
    end = start + timedelta(days=7)
    return start, end


def week_dir_name(ref: datetime):
    """Return directory name like '202604W3' for the week containing ref."""
    first_of_month = ref.replace(day=1)
    week_num = (ref.day - 1) // 7 + 1
    return f"{ref.year}{ref.month:02d}W{week_num}"


def get_ghq_root():
    result = subprocess.run(["ghq", "root"], capture_output=True, text=True)
    return result.stdout.strip()


def get_ghq_list():
    result = subprocess.run(["ghq", "list"], capture_output=True, text=True)
    return [r.strip() for r in result.stdout.strip().split("\n") if r.strip()]


def get_git_user_email(repo_path):
    """Get the effective git email for a repo, respecting direnv."""
    # direnv / .envrc may set GIT_COMMITTER_EMAIL per-project.
    try:
        result = subprocess.run(
            ["direnv", "exec", ".", "printenv", "GIT_COMMITTER_EMAIL"],
            capture_output=True, text=True, cwd=repo_path,
            timeout=10,
        )
        env_email = result.stdout.strip()
        if env_email:
            return env_email
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass

    result = subprocess.run(
        ["git", "config", "user.email"],
        capture_output=True, text=True, cwd=repo_path,
    )
    return result.stdout.strip()


# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------

def get_commits(repo_path, author_email, since, until):
    """Get commits with diffstat in the given time range."""
    fmt = "%H%x00%aI%x00%s"
    result = subprocess.run(
        [
            "git", "log", "--all",
            f"--author={author_email}",
            f"--since={since.isoformat()}",
            f"--until={until.isoformat()}",
            f"--format={fmt}",
            "--shortstat",
            "--no-merges",
        ],
        capture_output=True, text=True, cwd=repo_path,
    )
    commits = []
    lines = result.stdout.strip().split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line:
            i += 1
            continue
        parts = line.split("\x00")
        if len(parts) == 3:
            sha, date_str, subject = parts
            insertions = 0
            deletions = 0
            files_changed = 0
            for offset in range(1, 3):
                if i + offset < len(lines):
                    stat_line = lines[i + offset].strip()
                    if "file" in stat_line and (
                        "insertion" in stat_line or "deletion" in stat_line
                    ):
                        m_files = re.search(r"(\d+) file", stat_line)
                        m_ins = re.search(r"(\d+) insertion", stat_line)
                        m_del = re.search(r"(\d+) deletion", stat_line)
                        files_changed = int(m_files.group(1)) if m_files else 0
                        insertions = int(m_ins.group(1)) if m_ins else 0
                        deletions = int(m_del.group(1)) if m_del else 0
                        i = i + offset
                        break
            commits.append({
                "sha": sha,
                "timestamp": date_str,
                "subject": subject,
                "insertions": insertions,
                "deletions": deletions,
                "files_changed": files_changed,
            })
        i += 1
    return commits


def get_diff_file_types(repo_path, author_email, since, until):
    """Get changed file extensions to categorize work type."""
    result = subprocess.run(
        [
            "git", "log", "--all",
            f"--author={author_email}",
            f"--since={since.isoformat()}",
            f"--until={until.isoformat()}",
            "--name-only",
            "--format=",
            "--no-merges",
        ],
        capture_output=True, text=True, cwd=repo_path,
    )
    extensions = defaultdict(int)
    for line in result.stdout.strip().split("\n"):
        line = line.strip()
        if line:
            _, ext = os.path.splitext(line)
            extensions[ext.lower()] += 1
    return dict(extensions)


def sessions_from_timestamps(timestamps, gap_minutes=SESSION_GAP_MINUTES):
    """Group ISO timestamp strings into sessions.
    Returns list of [start, end] pairs (ISO strings)."""
    if not timestamps:
        return []
    sorted_ts = sorted(timestamps)
    parsed = [datetime.fromisoformat(t.replace("Z", "+00:00")) for t in sorted_ts]
    sessions = []
    session_start = parsed[0]
    session_end = parsed[0]
    for ts in parsed[1:]:
        if (ts - session_end).total_seconds() > gap_minutes * 60:
            sessions.append([session_start.isoformat(), session_end.isoformat()])
            session_start = ts
        session_end = ts
    sessions.append([session_start.isoformat(), session_end.isoformat()])
    return sessions


def repo_to_project_slug(repo_abs_path):
    """Convert absolute repo path to ~/.claude/projects slug."""
    return re.sub(r"[/._]", "-", repo_abs_path)


def get_agent_timestamps(repo_abs_path, since, until):
    """Parse ~/.claude/projects JSONL files for conversation timestamps."""
    slug = repo_to_project_slug(repo_abs_path)
    projects_dir = os.path.expanduser(f"~/.claude/projects/{slug}")
    if not os.path.isdir(projects_dir):
        return []

    timestamps = []
    for fname in os.listdir(projects_dir):
        if not fname.endswith(".jsonl"):
            continue
        fpath = os.path.join(projects_dir, fname)
        try:
            with open(fpath, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        ts_str = entry.get("timestamp")
                        if ts_str:
                            ts = datetime.fromisoformat(
                                ts_str.replace("Z", "+00:00")
                            )
                            if since <= ts < until:
                                timestamps.append(ts_str)
                    except (json.JSONDecodeError, ValueError):
                        continue
        except (IOError, OSError):
            continue

    return sorted(timestamps)


# ---------------------------------------------------------------------------
# Repo collection
# ---------------------------------------------------------------------------

def collect_repo(repo_rel, ghq_root, since, until):
    """Collect raw data for a single repo."""
    repo_abs = os.path.join(ghq_root, repo_rel)
    if not os.path.isdir(os.path.join(repo_abs, ".git")):
        return None

    email = get_git_user_email(repo_abs)
    if not email:
        return None

    commits = get_commits(repo_abs, email, since, until)
    file_types = get_diff_file_types(repo_abs, email, since, until)
    agent_timestamps = get_agent_timestamps(repo_abs, since, until)

    if not commits and not agent_timestamps:
        return None

    commit_timestamps = [c["timestamp"] for c in commits]
    commit_sessions = sessions_from_timestamps(commit_timestamps)
    agent_sessions = sessions_from_timestamps(agent_timestamps)

    total_insertions = sum(c["insertions"] for c in commits)
    total_deletions = sum(c["deletions"] for c in commits)

    return {
        "repo": repo_rel,
        "author_email": email,
        "commits": commits,
        "commit_sessions": commit_sessions,
        "agent_sessions": agent_sessions,
        "diff_stats": {
            "insertions": total_insertions,
            "deletions": total_deletions,
            "files_changed": sum(c["files_changed"] for c in commits),
        },
        "file_types": file_types,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ref = now_jst()
    since, until = week_range(ref)
    dir_name = week_dir_name(ref)

    ghq_root = get_ghq_root()
    repos = get_ghq_list()

    all_repos = []
    for repo in repos:
        result = collect_repo(repo, ghq_root, since, until)
        if result is not None:
            all_repos.append(result)

    # Sort by number of commits + agent sessions descending
    all_repos.sort(
        key=lambda r: len(r["commits"]) + len(r["agent_sessions"]),
        reverse=True,
    )

    output = {
        "generated_at": ref.isoformat(),
        "period": {
            "label": dir_name,
            "since": since.isoformat(),
            "until": until.isoformat(),
        },
        "repos": all_repos,
    }

    out_dir = os.path.expanduser(f"~/agents/retro-activity/{dir_name}")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "data.json")
    with open(out_path, "w") as f:
        json.dump(output, f, indent=2, default=str)

    print(out_path)


if __name__ == "__main__":
    main()
