# Step 2 of a safe binary update. Only after port 2222 tested OK.
# Run over the TEST port:  ssh -p 2222 emuelec sh -s < handheld/update-swap.sh
# Keeps the previous binary as dropbearmulti.prev and updates the card payload so the launcher won't revert it.
set -e
d=/storage/.dropbear
cp $d/dropbearmulti $d/dropbearmulti.prev
cp $d/staging/dropbearmulti $d/dropbearmulti.new && mv $d/dropbearmulti.new $d/dropbearmulti
cp $d/staging/dropbearmulti /storage/roms/.usbssh/dropbearmulti
cp $d/sftp-server /storage/roms/.usbssh/sftp-server
sync
sha256sum $d/dropbearmulti $d/dropbearmulti.prev $d/sftp-server
kill "$(cat $d/dropbear.pid)" 2>/dev/null || true
sleep 1
/bin/sh $d/usbssh-boot.sh
cat $d/boot.log
[ -f /tmp/db-test.pid ] && kill "$(cat /tmp/db-test.pid)" 2>/dev/null || true
sleep 1; netstat -lnt | grep -E ':(22|2222) '
