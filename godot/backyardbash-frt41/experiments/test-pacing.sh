#!/bin/sh
set -eu
d=/storage/roms/ports/backyardbash/frt41-v2
exec >"$d/test-pacing.log" 2>&1
trap 'systemctl start emustation; echo "EMUSTATION=$(systemctl is-active emustation)"' EXIT
systemctl stop emustation
sleep 2
BB_SAVE_DIR="$d/test-savedata" timeout -k 5 90 sh "$d/run-frt41.sh" --script "$d/pacing.gd"
