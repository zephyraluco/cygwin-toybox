#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin
tb=/usr/local/bin/toybox.exe
"$tb" --version
test "$("$tb" echo cygwin-toybox-ok)" = cygwin-toybox-ok
test "$(printf 'abc' | "$tb" wc -c | tr -d ' ')" = 3
test "$(printf 'b\na\nb\n' | "$tb" sort | "$tb" uniq)" = $'a\nb'
test "$(printf 'toybox' | "$tb" base64 | "$tb" base64 -d)" = toybox
test "$(printf 'abc' | "$tb" sha256sum | cut -d ' ' -f1)" = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
test "$(/opt/toybox/bin/echo.exe applet-ok)" = applet-ok
if "$tb" false; then echo 'false must fail' >&2; exit 1; fi
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
"$tb" mkdir "$scratch/sub"
printf 'hello\n' > "$scratch/sub/input"
"$tb" cp "$scratch/sub/input" "$scratch/sub/copy"
test "$("$tb" cat "$scratch/sub/copy")" = hello
"$tb" mv "$scratch/sub/copy" "$scratch/sub/moved"
"$tb" rm "$scratch/sub/moved"
test ! -e "$scratch/sub/moved"
echo 'Toybox runtime smoke tests passed'
