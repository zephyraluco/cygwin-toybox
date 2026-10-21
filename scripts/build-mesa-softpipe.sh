#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin
export LC_ALL=C
cache=$(cygpath -u "$1")
mirror=https://mirrors.kernel.org/sourceware/cygwin/
work=$(mktemp -d /tmp/mesa-softpipe.XXXXXXXX)
cd "$work"

# setup-x86_64.exe has already verified and cached this mirror's package index.
# Use its source archive entry and SHA-512 instead of an unverified source URL.
mapfile -t indexes < <(find "$cache" -type f -path '*/x86_64/setup.ini')
if (( ${#indexes[@]} != 1 )); then
  echo 'Expected one installer-verified x86_64/setup.ini in the package cache' >&2
  find "$cache" -maxdepth 4 -name 'setup*' -print
  exit 1
fi
read -r source_path source_size source_hash < <(awk '
  /^@ mesa$/ { package=1; next }
  package && (/^@ / || /^\[/) { exit }
  package && /^source: / { print $2, $3, $4; exit }
' "${indexes[0]}")
[[ "$source_path" == x86_64/release/mesa/*-src.tar.* ]]
[[ "$source_hash" =~ ^[[:xdigit:]]{128}$ ]]
archive=$(basename "$source_path")
curl --fail --location --retry 3 --proto '=https' "$mirror$source_path" -o "$archive"
test "$(stat -c %s "$archive")" = "$source_size"
printf '%s  %s\n' "$source_hash" "$archive" | sha512sum --check -
tar -xf "$archive"
mapfile -t recipes < <(find "$work" -type f -name '*.cygport')
(( ${#recipes[@]} == 1 ))
recipe=${recipes[0]}
cd "$(dirname "$recipe")"
echo 'Official Cygwin Mesa build configuration:'
cat "$recipe"
cygport "$recipe" prep
cygport "$recipe" vars CYGMESON_ARGS > "$work/meson-args.sh"
source "$work/meson-args.sh"
mapfile -d '' -t recipe_args < <(python3 - "$CYGMESON_ARGS" <<'PY'
import shlex, sys
for arg in shlex.split(sys.argv[1]):
    sys.stdout.buffer.write(arg.encode() + b'\0')
PY
)
source_dir=
while IFS= read -r candidate; do
  candidate=$(dirname "$candidate")
  if [[ -f "$candidate/VERSION" && -f "$candidate/meson.build" ]]; then
    [[ -z "$source_dir" ]]
    source_dir=$candidate
  fi
done < <(find "$work" -type f -name meson_options.txt)
test -n "$source_dir"
build="$work/build-softpipe"
stage="$work/stage"
meson setup "$build" "$source_dir" --prefix=/usr --libdir=lib \
  --buildtype=release --wrap-mode=nofallback "${recipe_args[@]}" \
  -Dllvm=disabled -Dgallium-drivers=swrast -Dvulkan-drivers= \
  -Dgallium-opencl=disabled -Dgallium-rusticl=false
meson introspect --buildoptions "$build" > "$work/build-options.json"
python3 - "$work/build-options.json" <<'PY'
import json, sys
options = {item['name']: item['value'] for item in json.load(open(sys.argv[1]))}
assert options['llvm'] in ('disabled', False), options['llvm']
assert options['gallium-drivers'] == ['swrast'], options['gallium-drivers']
print('Verified Mesa configuration: LLVM disabled, Gallium swrast only')
PY
jobs=$(nproc)
(( jobs <= 4 )) || jobs=4
meson compile -C "$build" -j "$jobs"
meson install -C "$build" --destdir "$stage" --no-rebuild --strip
test -f "$stage/usr/bin/cygGL-1.dll"
test -f "$stage/usr/lib/dri/swrast_dri.so"
mkdir -p "$stage/opt/mesa/share"
cp "$work/build-options.json" "$stage/opt/mesa/share/"
printf 'source=%s\nsha512=%s\nllvm=disabled\nrenderer=softpipe\n' \
  "$source_path" "$source_hash" > "$stage/opt/mesa/share/build.txt"
printf '%s\n' "$stage" > /opt/mesa-softpipe-stage
