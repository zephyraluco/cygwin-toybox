#!/bin/bash
# Minimal 2D X11 server. GLX/DRI and external font packages are not deployed.
set -euo pipefail
display=${1:-:0}
if [[ ! "$display" =~ ^:[0-9]+$ ]]; then
  echo 'Usage: start-xwin [:display-number] [XWin options...]' >&2
  exit 2
fi
export XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
umask 077
mkdir -p "$(dirname "$XAUTHORITY")"
touch "$XAUTHORITY"
chmod 600 "$XAUTHORITY"
if [[ -z "$(/usr/bin/xauth list "$display")" ]]; then
  cookie=$(/usr/bin/openssl rand -hex 16)
  /usr/bin/xauth add "$display" MIT-MAGIC-COOKIE-1 "$cookie"
  unset cookie
fi
exec /usr/bin/XWin.exe "$display" -multiwindow -clipboard -extension GLX -fp built-ins -nolisten tcp -auth "$XAUTHORITY" "${@:2}"
