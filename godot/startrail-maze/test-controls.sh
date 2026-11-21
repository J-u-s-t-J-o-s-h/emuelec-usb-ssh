#!/bin/sh
set -eu
d=/storage/roms/ports/startrailmaze
exec >"$d/test-controls.log" 2>&1
restore() {
  rc=$?
  trap - EXIT INT TERM HUP
  systemctl start emustation
  echo "TEST_EXIT=$rc EMUSTATION=$(systemctl is-active emustation)"
  exit "$rc"
}
trap restore EXIT
trap 'exit 143' INT TERM HUP
mkdir -p "$d/test-savedata"
systemctl stop emustation
sleep 2
MAZE_SAVE_DIR="$d/test-savedata" timeout -k 5 60 sh "$d/run-maze.sh" --script "$d/controls-check.gd"
