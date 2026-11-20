# Restore the previous dropbear binary.  Run:  ssh emuelec sh -s < handheld/rollback.sh
set -e
d=/storage/.dropbear
[ -f $d/dropbearmulti.prev ] || { echo "no dropbearmulti.prev"; exit 1; }
cp $d/dropbearmulti.prev $d/dropbearmulti
cp $d/dropbearmulti.prev /storage/roms/.usbssh/dropbearmulti
sync
kill "$(cat $d/dropbear.pid)" 2>/dev/null || true
sleep 1; /bin/sh $d/usbssh-boot.sh; cat $d/boot.log
