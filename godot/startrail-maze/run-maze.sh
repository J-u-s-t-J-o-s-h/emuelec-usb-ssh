#!/bin/sh
# Production runner. The Ports frontend owns its lifecycle; test-frt41.sh owns it during SSH tests.
set -eu
base=/storage/roms/ports
d="$base/startrailmaze"
runtime="$base/backyardbash/frt"
log="$d/launch-maze.log"
mkdir -p "$d/savedata"
exec >"$log" 2>&1
echo "MAZE_RUNNER_START uptime=$(cut -d' ' -f1 /proc/uptime)"
test -s "$d/game.pck"
test -s "$runtime/frt_4.1.3.squashfs"
test -s "$runtime/lib/libstdc++.so.6"
tmp=$(mktemp -d /tmp/startrail-maze.XXXXXX)
gp=
engine=
cleanup() {
  rc=$?
  trap - EXIT INT TERM HUP
  if [ -n "$engine" ]; then
    kill "$engine" 2>/dev/null || true
    sleep 0.5
    kill -9 "$engine" 2>/dev/null || true
    wait "$engine" 2>/dev/null || true
  fi
  if [ -n "$gp" ]; then
    kill "$gp" 2>/dev/null || true
    sleep 0.2
    kill -9 "$gp" 2>/dev/null || true
    wait "$gp" 2>/dev/null || true
  fi
  umount "$tmp" 2>/dev/null || true
  rmdir "$tmp" 2>/dev/null || true
  echo "MAZE_RUNNER_EXIT code=$rc uptime=$(cut -d' ' -f1 /proc/uptime)"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT
mount -t squashfs -o loop,ro "$runtime/frt_4.1.3.squashfs" "$tmp"
cd "$d"
if [ "${MAZE_BENCHMARK:-0}" = 1 ]; then set -- "$@" -- --benchmark; fi
gptokeyb 1 frt_4.1.3 -c "$d/maze.gptk" -killsignal 15 >"$d/gptokeyb.log" 2>&1 &
gp=$!
sleep 0.5
LD_LIBRARY_PATH="$runtime/lib" XDG_DATA_HOME="${MAZE_SAVE_DIR:-$d/savedata}" \
  stdbuf -oL -eL "$tmp/frt_4.1.3" --main-pack "$d/game.pck" --display-driver frt \
  --rendering-driver opengl3 --audio-driver SDL2 --print-fps "$@" &
engine=$!
if wait "$engine"; then rc=0; else rc=$?; fi
engine=
exit "$rc"
