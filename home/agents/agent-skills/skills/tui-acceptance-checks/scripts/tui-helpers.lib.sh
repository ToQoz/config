# Sourceable tmux helpers for TUI acceptance checks.
# Source only; not executable directly.
#
# Usage:
#   source scripts/tui-helpers.lib.sh
#   SESSION="tui-$$"
#   tui::new "$SESSION"
#   tui::wait_shell "$SESSION"
#   tui::send "$SESSION" "echo hello" Enter
#   tui::wait "$SESSION" 'hello' 5000
#   tui::capture "$SESSION"
#   # Do NOT kill the session at the end of a successful run — the user may be
#   # attached to observe live. Call tui::kill only to reclaim a stale name
#   # before a new run, or when the user asks you to tear it down.
#
# All functions take the tmux session name as $1. Every function that polls
# returns the current pane content on timeout — the caller decides whether a
# miss is a failure. Never silently ignore a timeout.
#
# Geometry is fixed at 120x40 by default so captures are deterministic across
# machines. Override via TUI_COLS / TUI_ROWS before calling tui::new.
#
# Server isolation is opt-in. By default the helpers run on the user's
# default tmux server so `tmux ls` / eye-on-glass stays easy. Call
# `tui::isolate <name>` before `tui::new` when the tested code touches
# server-wide state (switch-client, kill-server, global `set -g`, any
# client-targeting command). The name keys the socket so parallel runs
# get independent servers.

: "${TUI_COLS:=120}"
: "${TUI_ROWS:=40}"

# Internal: run tmux, targeting the isolated server when TUI_SOCKET is set.
_tui_tmux() {
  if [ -n "${TUI_SOCKET:-}" ]; then
    command tmux -S "$TUI_SOCKET" "$@"
  else
    command tmux "$@"
  fi
}

# Millisecond clock. GNU `date +%s%3N` works on Linux but not on BSD/macOS,
# so fall back to python3 which is available on both.
_tui_now_ms() {
  local ms
  ms=$(date +%s%3N 2>/dev/null) || ms=""
  case "$ms" in
    *N|"") python3 -c 'import time;print(int(time.time()*1000))' ;;
    *) printf '%s\n' "$ms" ;;
  esac
}

# tui::isolate <name>
# Opt in to server isolation. Points subsequent helper calls at a
# workspace-local tmux server whose socket lives at
# $PWD/.agents/tmux/<name>.sock. The name must be unique across concurrent
# runs so parallel tests do not share a server. Path choice is the helper's
# concern — callers only pass the name.
tui::isolate() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "tui::isolate: name required" >&2
    return 1
  fi
  TUI_SOCKET="${PWD}/.agents/tmux/${name}.sock"
  export TUI_SOCKET
  mkdir -p "$(dirname "$TUI_SOCKET")"
}

# tui::new <session>
# Create a detached session with fixed geometry. When tui::isolate was
# called first, the session lives on the isolated server; otherwise it
# lives on the default tmux server.
tui::new() {
  local session="$1"
  _tui_tmux new-session -d -s "$session" -x "$TUI_COLS" -y "$TUI_ROWS"
}

# tui::attach_hint <session>
# Print the command the user runs to attach to this session from another
# pane. Callers should emit this at the end of a successful run so the
# session stays discoverable — especially important after tui::isolate,
# where the server does not show up in plain `tmux ls`.
tui::attach_hint() {
  local session="$1"
  if [ -n "${TUI_SOCKET:-}" ]; then
    printf 'tmux -S %s attach -t %s\n' "$TUI_SOCKET" "$session"
  else
    printf 'tmux attach -t %s\n' "$session"
  fi
}

# tui::kill <session>
# Tear down the session. Safe to call when the session does not exist.
# Do NOT call at the end of a successful run — leave the session alive so the
# user can attach and inspect. Use only to reclaim a colliding session name or
# when the user explicitly asks for teardown.
tui::kill() {
  local session="$1"
  _tui_tmux kill-session -t "$session" 2>/dev/null || true
}

# tui::send <session> <args...>
# Forward args directly to `tmux send-keys`. Named keys (Enter, Escape, C-c,
# Up, …) must be separate args. Shell commands are a single quoted arg.
tui::send() {
  local session="$1"
  shift
  _tui_tmux send-keys -t "$session" "$@"
}

# tui::sendl <session> <text>
# Send literal text with `-l`: no key parsing, no execution. Use for prefill
# tests and for pasting text that contains key names.
tui::sendl() {
  local session="$1"
  local text="$2"
  _tui_tmux send-keys -t "$session" -l "$text"
}

# tui::capture <session> [scrollback]
# Capture the pane joined (`-J`) so wrapped lines match substrings. Pass a
# scrollback depth (e.g. 500) to include history; default is visible pane only.
tui::capture() {
  local session="$1"
  local scrollback="${2:-}"
  if [ -n "$scrollback" ]; then
    _tui_tmux capture-pane -t "$session" -p -J -S "-$scrollback"
  else
    _tui_tmux capture-pane -t "$session" -p -J
  fi
}

# tui::wait <session> <regex> [timeout_ms]
# Poll the pane with exponential backoff until the regex matches or timeout
# expires. Prints the final pane content (matched or not). Returns 0 on match,
# 1 on timeout. Default timeout: 15000ms.
tui::wait() {
  local session="$1"
  local pattern="$2"
  local timeout_ms="${3:-15000}"

  local start
  start=$(_tui_now_ms)
  local now interval=100 content
  while :; do
    content=$(tui::capture "$session" 500)
    if printf '%s' "$content" | grep -Eq -- "$pattern"; then
      printf '%s' "$content"
      return 0
    fi
    now=$(_tui_now_ms)
    if [ $((now - start)) -ge "$timeout_ms" ]; then
      printf '%s' "$content"
      return 1
    fi
    sleep "$(awk "BEGIN{printf \"%.3f\", $interval/1000}")"
    interval=$((interval * 2))
    [ $interval -gt 2000 ] && interval=2000
  done
}

# tui::wait_shell <session> [timeout_ms]
# Wait for a shell prompt ($, %, >) then settle briefly. Use before sending
# the first command so the shell is ready to receive input.
tui::wait_shell() {
  local session="$1"
  local timeout_ms="${2:-10000}"
  tui::wait "$session" '\$|%|>' "$timeout_ms" >/dev/null
  sleep 0.5
}

# tui::run <session> <command> [timeout_ms]
# Run a shell command wrapped in START/END markers that contain literal $$
# (PID substitution). Waits for the END marker, then prints the pane slice
# between the markers — isolated from prior pane residue and from the echoed
# command line.
#
# The echoed command has the literal text "$$"; only the executed line, where
# the shell substituted the PID, satisfies the \d+ pattern in the END regex.
# That eliminates the two classic sources of flake.
tui::run() {
  local session="$1"
  local cmd="$2"
  local timeout_ms="${3:-15000}"

  local id start_tok end_tok
  id="$(_tui_now_ms)_$$_${RANDOM}"
  start_tok="TUI_START_${id}"
  end_tok="TUI_END_${id}"

  _tui_tmux send-keys -t "$session" "echo ${start_tok}_\$\$; ${cmd}; echo ${end_tok}_\$\$" Enter
  tui::wait "$session" "${end_tok}_[0-9]+" "$timeout_ms" >/dev/null || return 1

  local all
  all=$(tui::capture "$session" 1000)

  awk -v s="${start_tok}_" -v e="${end_tok}_" '
    BEGIN { inside=0 }
    {
      if (inside == 0 && match($0, s "[0-9]+")) {
        inside=1
        rest = substr($0, RSTART + RLENGTH)
        if (rest != "") print rest
        next
      }
      if (inside == 1) {
        if (match($0, e "[0-9]+")) { exit }
        print
      }
    }
  ' <<< "$all"
}
