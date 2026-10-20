#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin

rm -rf -- /usr/share/doc /usr/share/info
test ! -e /usr/share/doc
test ! -e /usr/share/info
echo 'Removed /usr/share/doc and /usr/share/info'
