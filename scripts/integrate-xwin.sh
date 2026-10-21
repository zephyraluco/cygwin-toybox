#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin
export LC_ALL=C
project=$(cd "$(dirname "$0")/.." && pwd)
runtime=$(cygpath -u "$1")
client=$(cygpath -u "$2")
share="$runtime/opt/xwin/share"
mkdir -p "$runtime/usr/local/bin" "$share" "$runtime/usr/share/X11"
manifest="$share/runtime-files.txt"
: > "$manifest"

copy_file() {
  local source=$1 target=$2
  mkdir -p "$(dirname "$runtime$target")"
  cp "$source" "$runtime$target"
  printf '%s\n' "$target" >> "$manifest"
}

# cygcheck recursively walks imported DLLs. GLX also needs modules loaded at
# runtime, which are staged explicitly below along with their own imports.
for exe in /usr/bin/XWin.exe /usr/bin/xkbcomp.exe; do
  test -x "$exe"
  copy_file "$exe" "/bin/$(basename "$exe")"
  cygcheck "$exe" | tr -d '\r' > "$share/$(basename "$exe").dependencies.txt"
  if grep -q 'not found' "$share/$(basename "$exe").dependencies.txt"; then
    cat "$share/$(basename "$exe").dependencies.txt"
    exit 1
  fi
  while IFS= read -r dll; do
    dll=${dll#"${dll%%[![:space:]]*}"}
    [[ "$dll" == *.dll ]] || continue
    dll=$(cygpath -u "$dll")
    name=$(basename "$dll")
    if [[ -f "/usr/bin/$name" ]]; then
      # Preserve DLLs already supplied by the base runtime.
      if [[ ! -f "$runtime/bin/$name" ]]; then
        copy_file "/usr/bin/$name" "/bin/$name"
      fi
    fi
  done < "$share/$(basename "$exe").dependencies.txt"
done

# Retain both XWin's native WGL bridge and Mesa's software GLX provider.
# Unlike imported DLLs, these modules are invisible in XWin's import table.
mapfile -t native_modules < <(find -L /usr/bin /usr/lib -type f -iname 'cygnativeGLthunk.dll')
mapfile -t software_modules < <(find -L /usr/lib -type f -name swrast_dri.so)
if (( ${#native_modules[@]} == 0 || ${#software_modules[@]} == 0 )); then
  echo 'Missing XWin native GL bridge or Mesa software driver' >&2
  exit 1
fi
mapfile -t gl_libraries < <(find -L /usr/bin -maxdepth 1 -type f \
  \( -name 'cygGL*.dll' -o -name 'cygglapi*.dll' \))
test -f /usr/bin/cygGL-1.dll
for module in "${native_modules[@]}" "${software_modules[@]}" "${gl_libraries[@]}"; do
  target=$module
  case "$target" in
    /usr/bin/*) target="/bin/${target#/usr/bin/}" ;;
    /usr/lib/*) target="/lib/${target#/usr/lib/}" ;;
  esac
  copy_file "$module" "$target"
  dependencies="$share/$(basename "$module").dependencies.txt"
  cygcheck "$module" | tr -d '\r' > "$dependencies"
  if grep -q 'not found' "$dependencies"; then cat "$dependencies"; exit 1; fi
  while IFS= read -r dll; do
    dll=${dll#"${dll%%[![:space:]]*}"}
    [[ "$dll" == *.dll ]] || continue
    dll=$(cygpath -u "$dll")
    name=$(basename "$dll")
    if [[ -f "/usr/bin/$name" && ! -f "$runtime/bin/$name" ]]; then
      copy_file "/usr/bin/$name" "/bin/$name"
    fi
  done < "$dependencies"
done

# XKB compilation requires rules, keycodes, symbols, geometry and locale data.
cp -aL /usr/share/X11/xkb "$runtime/usr/share/X11/"
find -L /usr/share/X11/xkb -type f >> "$manifest"
if [[ -d /usr/share/X11/locale ]]; then
  cp -aL /usr/share/X11/locale "$runtime/usr/share/X11/"
  find -L /usr/share/X11/locale -type f >> "$manifest"
fi
test -r "$runtime/usr/share/X11/xkb/rules/base"
if [[ -f /etc/X11/system.XWinrc ]]; then
  copy_file /etc/X11/system.XWinrc /etc/X11/system.XWinrc
fi
cygcheck -c xorg-server > "$share/upstream-version.txt"
sort -u "$manifest" -o "$manifest"

# A disposable client is compiled outside the deployment to test a real X11
# connection. It is not included in the published archive.
gcc "$project/scripts/xwin-smoke.c" -o "$client" -lX11
gcc "$project/scripts/glx-smoke.c" -o "$(dirname "$client")/glx-smoke.exe" -lGL -lX11
du -sh "$runtime"
find "$runtime" -type f -printf '%s %p\n' | sort -nr | head -30 || true
