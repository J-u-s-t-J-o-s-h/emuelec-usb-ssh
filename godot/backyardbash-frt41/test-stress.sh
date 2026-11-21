#!/bin/sh
set -eu
d=/storage/roms/ports/backyardbash/frt41
exec >"$d/test-stress.log" 2>&1
trap 'systemctl start emustation; echo "EMUSTATION=$(systemctl is-active emustation)"' EXIT
systemctl stop emustation
sleep 2
BB_SAVE_DIR="$d/test-savedata" timeout -k 5 75 sh "/storage/roms/ports_scripts/Monster Truck Backyard Bash.sh" --script "$d/stress.gd"
