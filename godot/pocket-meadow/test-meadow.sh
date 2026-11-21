#!/bin/sh
set -eu
d=/storage/roms/ports/pocketmeadow
exec >"$d/test-meadow.log" 2>&1
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
MEADOW_SAVE_DIR="$d/test-savedata" MEADOW_BENCHMARK=1 timeout -k 5 60 sh "$d/run-meadow.sh"
