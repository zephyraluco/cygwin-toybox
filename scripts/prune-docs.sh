#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin

# Retain notices and README files that may carry redistribution terms,
# preserving their original relative paths for attribution.
if [[ -d /usr/share/doc ]]; then
  mkdir -p /opt/licenses/usr/share/doc
  cd /usr/share/doc
  while IFS= read -r -d '' file; do
    target="/opt/licenses/usr/share/doc/${file#./}"
    mkdir -p "$(dirname "$target")"
    cp -L -- "$file" "$target"
  done < <(find . \( -type f -o -type l \) \( \
    -iname '*license*' -o -iname '*licence*' -o -iname '*copying*' \
    -o -iname '*copyright*' -o -iname '*notice*' -o -iname '*readme*' \
    \) -print0)
  cd /
fi
rm -rf -- /usr/share/doc /usr/share/info
test ! -e /usr/share/doc
test ! -e /usr/share/info
echo 'Removed /usr/share/doc and /usr/share/info; retained notices in /opt/licenses'
