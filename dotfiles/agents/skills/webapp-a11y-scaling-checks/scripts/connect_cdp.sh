#!/usr/bin/env bash
# Forward the emulator's Chrome DevTools Protocol socket to a local TCP
# port and confirm the endpoint is reachable. Prints the port to stdout so
# it can be piped into `agent-browser connect`.
#
# Usage: connect_cdp.sh <serial> [port]

set -euo pipefail

SERIAL="${1:?serial required}"
PORT="${2:-9222}"

# Drop any stale forward on this port (could be pointing at a previous
# run's target, on this serial or another). `--remove` is a no-op if
# the rule does not exist.
adb -s "$SERIAL" forward --remove "tcp:$PORT" >/dev/null 2>&1 || true
adb -s "$SERIAL" forward "tcp:$PORT" localabstract:chrome_devtools_remote >/dev/null

for _ in $(seq 1 10); do
  if curl -sf "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
    echo "$PORT"
    exit 0
  fi
  sleep 1
done

echo "connect_cdp: CDP endpoint not reachable on localhost:$PORT after 10s (has Chrome been launched on $SERIAL?)" >&2
exit 1
