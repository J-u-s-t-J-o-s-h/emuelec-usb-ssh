#!/bin/sh
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
editor=${1:?Pass the official Godot 4.1.3 Linux editor path}
out=${2:?Pass an output directory outside this repository}
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd)
test "$("$editor" --version)" = 4.1.3.stable.official.f06b6836a
"$editor" --headless --editor --quit --path "$here/project" >"$out/import.log" 2>&1
XDG_DATA_HOME="$out/test-saves" timeout 30 "$editor" --headless --path "$here/project" -- --self-test >"$out/self-test.log" 2>&1
grep MAZE_SELF_TEST_PASS "$out/self-test.log"
if grep -q 'SCRIPT ERROR' "$out/self-test.log"; then cat "$out/self-test.log"; exit 1; fi
"$editor" --headless --path "$here/project" --export-pack Linux "$out/game.pck" >"$out/export.log" 2>&1
test -s "$out/game.pck"
if grep -q 'SCRIPT ERROR' "$out/export.log"; then cat "$out/export.log"; exit 1; fi
sha256sum "$out/game.pck"
