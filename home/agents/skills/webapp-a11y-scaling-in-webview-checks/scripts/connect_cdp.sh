#!/usr/bin/env bash
# Forward the running wvtest WebView's CDP socket to a local TCP port and
# print the port on stdout. Pipe straight into `agent-browser connect`.
#
# Usage: connect_cdp.sh <serial> [port]

set -euo pipefail

SERIAL="${1:?serial required}"
PORT="${2:-9222}"

PID=$(adb -s "$SERIAL" shell pidof com.example.wvtest 2>/dev/null | tr -d '\r\n')
if [ -z "$PID" ]; then
  echo "connect_cdp: com.example.wvtest is not running on $SERIAL" >&2
  exit 1
fi

# Drop any stale forward on this port (could be pointing at a previous
# run's pid, on this serial or another). `--remove` is a no-op if the
# rule does not exist.
adb -s "$SERIAL" forward --remove "tcp:$PORT" >/dev/null 2>&1 || true
adb -s "$SERIAL" forward "tcp:$PORT" "localabstract:webview_devtools_remote_$PID" >/dev/null

for _ in $(seq 1 10); do
  if curl -sf "http://localhost:$PORT/json/version" >/dev/null 2>&1; then
    echo "$PORT"
    exit 0
  fi
  sleep 1
done

echo "connect_cdp: CDP endpoint not reachable on localhost:$PORT" >&2
exit 1
