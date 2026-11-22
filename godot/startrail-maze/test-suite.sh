#!/bin/sh
set -eu
d=/storage/roms/ports/startrailmaze
exec >"$d/test-suite.log" 2>&1
restore() {
  rc=$?
  trap - EXIT INT TERM HUP
  systemctl start emustation
  echo "SUITE_EXIT=$rc EMUSTATION=$(systemctl is-active emustation)"
  exit "$rc"
}
trap restore EXIT
trap 'exit 143' INT TERM HUP
systemctl stop emustation
sleep 2
for stage in 0 1 2; do
  MAZE_SAVE_DIR="$d/test-savedata" timeout -k 5 60 sh "$d/run-maze.sh" -- --benchmark --benchmark-stage="$stage"
  cp "$d/launch-maze.log" "$d/benchmark-stage-$stage.log"
done
MAZE_SAVE_DIR="$d/test-savedata" timeout -k 5 60 sh "$d/run-maze.sh" -- --benchmark --benchmark-map
cp "$d/launch-maze.log" "$d/benchmark-map.log"
