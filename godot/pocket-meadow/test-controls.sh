#!/bin/sh
set -eu
d=/storage/roms/ports/pocketmeadow
exec >"$d/test-controls.log" 2>&1
restore() {
  rc=$?
  trap - EXIT INT TERM HUP
  systemctl start emustation
  echo "CONTROLS_EXIT=$rc EMUSTATION=$(systemctl is-active emustation)"
  exit "$rc"
}
trap restore EXIT
trap 'exit 143' INT TERM HUP
systemctl stop emustation
sleep 2
MEADOW_SAVE_DIR="$d/test-savedata" timeout -k 5 45 sh "$d/run-meadow.sh" --script "$d/controls-check.gd"
