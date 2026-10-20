#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin
export LC_ALL=C

project=$(cd "$(dirname "$0")/.." && pwd)
source_dir=$(cygpath -u "$1")
runtime=$(cygpath -u "$2")
cd "$source_dir"
patch --batch --forward -p1 < "$project/scripts/patches/toybox-cygwin.patch"
export CC=gcc HOSTCC=gcc CPUS=2
export KCONFIG_ALLCONFIG="$project/scripts/toybox-cygwin.config"
make allnoconfig
make toybox

install -d "$runtime/usr/local/bin" "$runtime/opt/toybox/bin" "$runtime/opt/toybox/share"
install -m 755 toybox.exe "$runtime/usr/local/bin/toybox.exe"
cp .config "$runtime/opt/toybox/share/build.config"
cp LICENSE "$runtime/opt/toybox/share/LICENSE"
printf '%s\n' 'Toybox 0.8.15' 'upstream: landley/toybox' 'commit: a57b091d05ec366dcd4dd737784c03761cb6a4b1' > "$runtime/opt/toybox/share/version.txt"

# Copy only imported Cygwin DLLs, never the compiler or its development files.
cygcheck ./toybox.exe | tr -d '\r' > generated/runtime-dependencies.txt
if grep -q 'not found' generated/runtime-dependencies.txt; then
  cat generated/runtime-dependencies.txt
  exit 1
fi
while IFS= read -r dll; do
  dll=${dll#"${dll%%[![:space:]]*}"}
  [[ "$dll" == *.dll ]] || continue
  dll=$(cygpath -u "$dll")
  case "$dll" in
    /usr/bin/*|/bin/*) cp -n "$dll" "$runtime/bin/" ;;
  esac
done < generated/runtime-dependencies.txt

# Keep existing GNU utilities intact. Opt in with PATH=/opt/toybox/bin:$PATH.
./toybox.exe > "$runtime/opt/toybox/share/applets.txt"
for applet in $(./toybox.exe); do
  ln -f "$runtime/usr/local/bin/toybox.exe" "$runtime/opt/toybox/bin/$applet.exe"
done
