#!/bin/bash
# Minimal 2D X11 server. GLX/DRI and external font packages are not deployed.
exec /usr/bin/XWin.exe "${1:-:0}" -multiwindow -clipboard -extension GLX -fp built-ins -nolisten tcp "${@:2}"
