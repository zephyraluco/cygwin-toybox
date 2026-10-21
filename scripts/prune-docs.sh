#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin

rm -rf -- /usr/share/doc /usr/share/info
test ! -e /usr/share/doc
test ! -e /usr/share/info
echo 'Removed /usr/share/doc and /usr/share/info'

test -f /usr/share/locale/locale.alias
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name locale.alias \
  -exec rm -rf -- {} +
test -f /usr/share/locale/locale.alias
test -z "$(find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name locale.alias -print -quit)"
echo 'Removed translations from /usr/share/locale; retained locale.alias'
