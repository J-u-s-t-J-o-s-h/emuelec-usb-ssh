#!/bin/sh
# Run the FRT smoke test on the handheld, detached from SSH (EmulationStation is stopped and restarted).
# Expects in /storage/roms/ports/backyardbash/frt/: frt_4.1.3.squashfs, smoke41.pck,
# lib/libstdc++.so.6 (plain copy of Debian 12 libstdc++.so.6.0.30 - FAT32 cannot hold symlinks).
# Usage on the handheld:  systemd-run --unit=frtsmoke --quiet sh /path/frt-smoke-run.sh
d=/storage/roms/ports/backyardbash/frt
m=/tmp/frt_4.1.3
log=$d/frt-smoke.log
systemctl stop emustation; sleep 2
mkdir -p $m; mountpoint -q $m || mount -t squashfs -o loop,ro $d/frt_4.1.3.squashfs $m
echo "start $(cut -d' ' -f1 /proc/uptime)" > $log
cd $d
LD_LIBRARY_PATH=$d/lib XDG_DATA_HOME=$d/savedata timeout 70 $m/frt_4.1.3 --main-pack $d/smoke41.pck \
  --display-driver frt --rendering-driver opengl3 --audio-driver SDL2 >> $log 2>&1
echo "exit code $? at $(cut -d' ' -f1 /proc/uptime)" >> $log
umount $m
systemctl start emustation
echo "emustation: $(systemctl is-active emustation)" >> $log
