#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin
client=$(cygpath -u "$1")
log=$(mktemp)
pid=
cleanup() {
  if [[ -n "$pid" ]]; then kill -KILL "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  cat "$log"
  rm -f "$log"
}
trap cleanup EXIT
/usr/bin/XWin.exe -version
# Disable authentication only for this short-lived CI test display.
# The packaged launcher retains XWin's default access control.
/usr/local/bin/start-xwin :99 -ac -logfile "$log" &
pid=$!
for attempt in {1..15}; do
  if DISPLAY=:99 timeout 2 "$client"; then
    echo 'XWin connection, window creation and drawing passed'
    exit 0
  fi
  kill -0 "$pid"
  sleep 1
done
echo 'XWin did not accept an X11 connection before the probe deadline' >&2
exit 1
