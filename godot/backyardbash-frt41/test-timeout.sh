#!/bin/sh
d=/storage/roms/ports/backyardbash/frt41
exec >"$d/test-timeout.log" 2>&1
trap 'systemctl start emustation' EXIT
systemctl stop emustation
sleep 2
BB_SAVE_DIR="$d/test-savedata" timeout -k 5 12 sh "$d/run-frt41.sh"
rc=$?
echo "TIMEOUT_RC=$rc"
systemctl start emustation
echo "EMUSTATION=$(systemctl is-active emustation)"
ps | grep '[f]rt_4.1.3 --main-pack' || true
mount | grep '/tmp/backyardbash-frt' || true
