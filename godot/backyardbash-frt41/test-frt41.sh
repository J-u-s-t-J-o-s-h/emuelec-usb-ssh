#!/bin/sh
set -eu
d=/storage/roms/ports/backyardbash/frt41
exec >"$d/test-frt41.log" 2>&1
restore() {
  rc=$?
  trap - EXIT INT TERM HUP
  systemctl start emustation
  echo "TEST_EXIT=$rc EMUSTATION=$(systemctl is-active emustation)"
  exit "$rc"
}
trap restore EXIT
trap 'exit 143' TERM HUP
trap 'exit 130' INT
systemctl stop emustation
sleep 2
mkdir -p "$d/test-savedata"
BB_SAVE_DIR="$d/test-savedata" timeout -k 5 90 sh "$d/run-frt41.sh" --script res://tests/handheld_check.gd
