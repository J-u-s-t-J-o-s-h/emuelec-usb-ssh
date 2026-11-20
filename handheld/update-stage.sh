# Step 1 of a safe binary update over SSH. Port 22 is untouched.
# Before running: copy new dropbearmulti + sftp-server into /storage/.dropbear/staging/
#   scp bin/dropbearmulti bin/sftp-server emuelec:/storage/.dropbear/staging/   (mkdir it first: ssh emuelec mkdir -p /storage/.dropbear/staging)
# Run:  ssh emuelec sh -s < handheld/update-stage.sh
# Then test the new server on port 2222 from the PC:  sftp -P 2222 emuelec   /   ssh -p 2222 emuelec
set -e
d=/storage/.dropbear
cd $d/staging
sha256sum dropbearmulti sftp-server
chmod 755 dropbearmulti sftp-server
cp sftp-server $d/sftp-server
[ -f /tmp/db-test.pid ] && kill "$(cat /tmp/db-test.pid)" 2>/dev/null || true
$d/staging/dropbearmulti dropbear -r $d/host_ed25519 -p 2222 -P /tmp/db-test.pid
sleep 1
netstat -lnt | grep -E ':(22|2222) '
