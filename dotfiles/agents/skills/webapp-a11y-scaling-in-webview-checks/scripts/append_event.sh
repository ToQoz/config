#!/usr/bin/env bash
# Append one JSONL event to <artifact_dir>/report.jsonl. Used by sub-
# agents to log captures, retries, refused writes, and other notable
# events so the main orchestrator can surface them in INDEX.md.
#
# Auto-fields:
#   ts       — ISO-8601 UTC timestamp
#   pid      — caller pid (handy when pinning failures to an agent run)
#
# Usage:
#   append_event.sh <artifact_dir> <key=value> [<key=value> ...]
#
# Examples:
#   append_event.sh "$ART" \
#     agent_id=03 event=capture screen=terms-modal state=open \
#     pair_id=03-terms-modal file=03-01-terms-modal-open.png
#   append_event.sh "$ART" \
#     agent_id=03 event=read_only_refused action="submit profile form"
#   append_event.sh "$ART" \
#     agent_id=03 event=retry reason="webview crashed" retry_count=1
#
# Values are JSON-string-escaped via jq. Numeric-looking values stay
# strings — INDEX.md generation does not need numeric typing.

set -euo pipefail

ART="${1:?artifact_dir required}"
shift
[ "$#" -gt 0 ] || { echo "append_event: at least one key=value pair required" >&2; exit 1; }

mkdir -p "$ART"

args=()
for kv in "$@"; do
  k="${kv%%=*}"
  v="${kv#*=}"
  if [ "$k" = "$kv" ]; then
    echo "append_event: bad key=value: '$kv'" >&2
    exit 1
  fi
  args+=( --arg "$k" "$v" )
done

# Build object: {k1: $k1, k2: $k2, ..., ts: ..., pid: ...}
obj_expr='{'
sep=''
for kv in "$@"; do
  k="${kv%%=*}"
  obj_expr+="${sep}${k}: \$${k}"
  sep=', '
done
obj_expr+='}'

jq -cn "${args[@]}" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg pid "$$" \
  "$obj_expr + {ts: \$ts, pid: \$pid}" \
  >>"$ART/report.jsonl"
