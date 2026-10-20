#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin
client=$(cygpath -u "$1")
scratch=$(mktemp -d)
log="$scratch/XWin.log"
touch "$log"
export XAUTHORITY="$scratch/Xauthority"
pid=
cleanup() {
  if [[ -n "$pid" ]]; then kill -KILL "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  cat "$log"
  rm -rf "$scratch"
}
trap cleanup EXIT
/usr/bin/XWin.exe -version
/usr/bin/ssh -V
DISPLAY=:99 /usr/bin/ssh -Y -o XAuthLocation=/usr/bin/xauth -G localhost > "$scratch/ssh-config"
grep -qx 'forwardx11 yes' "$scratch/ssh-config"
grep -qx 'forwardx11trusted yes' "$scratch/ssh-config"
grep -qx 'xauthlocation /usr/bin/xauth' "$scratch/ssh-config"
# Use cookie authentication for the same path used by SSH X11 forwarding.
umask 077
touch "$XAUTHORITY"
xauth add :99 MIT-MAGIC-COOKIE-1 "$(openssl rand -hex 16)"
/usr/bin/XWin.exe :99 -multiwindow -clipboard -extension GLX -fp built-ins -nolisten tcp -auth "$XAUTHORITY" -logfile "$log" &
pid=$!
for attempt in {1..15}; do
  if DISPLAY=:99 timeout 2 "$client"; then
    test -n "$(xauth list :99)"
    echo 'Cookie-authenticated XWin connection, window creation and drawing passed'
    exit 0
  fi
  kill -0 "$pid"
  sleep 1
done
echo 'XWin did not accept an X11 connection before the probe deadline' >&2
exit 1
