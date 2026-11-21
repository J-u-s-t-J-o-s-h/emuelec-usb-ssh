#!/bin/sh
set -eu
d=/storage/roms/ports/backyardbash/frt41
exec >"$d/test-installed.log" 2>&1
restore() {
  rc=$?
  trap - EXIT INT TERM HUP
  systemctl start emustation
  echo "INSTALLED_TEST_EXIT=$rc EMUSTATION=$(systemctl is-active emustation)"
  exit "$rc"
}
trap restore EXIT
trap 'exit 143' INT TERM HUP
systemctl stop emustation
sleep 2
BB_SAVE_DIR="$d/test-savedata" timeout -k 5 90 sh "/storage/roms/ports_scripts/Monster Truck Backyard Bash.sh" --script res://tests/handheld_check.gd
