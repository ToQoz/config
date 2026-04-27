#!/usr/bin/env bash
# Wrap `fence` so any caller — interactive shell, scripts, or compiled
# binaries (e.g. `sence`) — gets worktree-aware allowWrite paths injected
# into the fence policy. In a worktree, --git-dir and --git-common-dir
# point outside the worktree's CWD; templates like `code` scope writes to
# the workspace tree and therefore can't reach those paths, so ordinary
# git operations (commit, branch, fetch) fail under fence.
#
# This wrapper aligns with fence's real CLI rather than wrapping it. It
# only inspects two flags:
#
#   --settings <path>   Existing fence settings file. The wrapper reads
#                       it, appends '.', git-dir and common-dir to
#                       .filesystem.allowWrite (deduped), writes a tmp
#                       file, and substitutes that path in the call.
#   --template <name>   Used as the `extends:` target when the wrapper
#                       has to synthesize a fresh settings file. Also
#                       forwarded to fence verbatim. Defaults to "code".
#
# Every other argument — including unknown flags such as `-m`,
# `--fence-log-file`, and the `--` inner-command separator — passes
# through to fence unchanged. This keeps the wrapper composable with
# callers like `sence` that drive fence with a richer argv.
set -euo pipefail

die() { echo "fence: $*" >&2; exit 2; }

settings_in=""
have_settings=false
template="code"
forwarded=()

while (( $# )); do
  case "$1" in
    --settings)
      (( $# >= 2 )) || die "missing value for --settings"
      settings_in=$2
      have_settings=true
      shift 2
      ;;
    --template)
      (( $# >= 2 )) || die "missing value for --template"
      template=$2
      forwarded+=("$1" "$2")
      shift 2
      ;;
    --)
      forwarded+=("$@")
      break
      ;;
    *)
      forwarded+=("$1")
      shift
      ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git work tree"
git_dir=$(cd "$(git rev-parse --git-dir)" && pwd)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd)

tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT

if $have_settings; then
  [[ -r $settings_in ]] || die "settings file not readable: $settings_in"
  jq \
    --arg gd "$git_dir" \
    --arg cd_ "$common_dir" \
    '.filesystem //= {}
     | .filesystem.allowWrite = (((.filesystem.allowWrite // []) + [".", $gd, $cd_]) | unique)' \
    "$settings_in" > "$tmp"
else
  jq -nc \
    --arg t "$template" \
    --arg gd "$git_dir" \
    --arg cd_ "$common_dir" \
    '{extends: $t, filesystem: {allowWrite: ([".", $gd, $cd_] | unique)}}' \
    > "$tmp"
fi

exec "${FENCE_BIN:-fence}" --settings "$tmp" ${forwarded[@]+"${forwarded[@]}"}
