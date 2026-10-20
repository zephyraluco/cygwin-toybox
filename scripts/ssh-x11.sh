#!/bin/bash
# Forward trusted remote X11 applications through SSH to the local XWin.
set -euo pipefail
export DISPLAY=${DISPLAY:-:0}
export XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
exec /usr/bin/ssh -Y -o XAuthLocation=/usr/bin/xauth "$@"
