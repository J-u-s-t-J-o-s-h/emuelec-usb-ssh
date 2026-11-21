# Findings log

Labels: **Verified** = observed directly (command output, logs, hashes). **Inferred** = reasoning from
evidence, not directly confirmed. **Unexplained** = observed, cause not determined.

## Device and firmware

| Finding | Status | Evidence |
| --- | --- | --- |
| Firmware ships no SSH server (no sshd, no sshd.service, no dropbear) | Verified | `/usr/sbin/sshd` absent; `systemctl start sshd` -> "Unit sshd.service not found" |
| OTG controller ff300000.usb is dual-role, `dr_mode = otg` (not host-only) | Verified | `/proc/device-tree/usb@ff300000/dr_mode` |
| Kernel has configfs gadget + RNDIS built in | Verified | `CONFIG_USB_GADGET=y`, `CONFIG_USB_CONFIGFS=y`, `CONFIG_USB_CONFIGFS_RNDIS=y` |
| Gadget enumerates high-speed and reaches `configured` when the PC is attached | Verified | dmesg: `bound driver configfs-gadget`, `new device is high-speed`, `USB_STATE=CONFIGURED` |
| Root filesystem read-only; `/storage` (ext4) writable; games partition FAT32 `EEROMS` | Verified | mounts, successful writes |
| Root's home is `/storage` | Verified | `/etc/passwd` |
| Clock resets to 2023-02-16 ~13:10 EST every boot; handheld timestamps meaningless | Verified | `date`, journal, file times |
| Journal is RAM-only; previous boot's logs are lost on reboot | Verified | `journalctl --list-boots` shows one boot; no `/var/log/journal` |
| `zed_gadget.service` is a **low-battery shutdown daemon**, not a USB gadget service: every 5 s, if status != Charging and `voltage_now` <= 3,400,000 uV -> `systemctl poweroff` | Verified | `/usr/bin/zed_gadget.sh` source |
| The data (OTG) port does not charge the handheld | Verified | `power_supply/usb/online = 0`, battery Discharging while connected |
| User services in `/storage/.config/system.d/` are honoured; `multi-user.target` is reached under `emuelec.target` | Verified | service enabled there starts at boot |
| `/storage/.config/custom_start.sh` exists (`before`/after hooks) | Verified | file contents; not used by this setup |
| Remote command PATH is `/usr/sbin:/usr/bin:/sbin:/bin` (dropbear `DEFAULT_PATH` not applied), so `/storage/bin` tools are not found | Verified | `echo $PATH` over SSH; legacy `scp -O` failed "scp: command not found" |

## PC side (Windows 11, OpenSSH_for_Windows_9.5p2)

| Finding | Status | Evidence |
| --- | --- | --- |
| Windows binds the gadget automatically as "Remote NDIS Compatible Device" (no driver install) | Verified | `USB\VID_0525&PID_A4A2\PA20261120`, adapter Up, 426 Mbps |
| Windows `scp` uses the SFTP protocol by default, so `sftp-server` is required for plain `scp` | Verified | works only after sftp-server installed |
| IPv6 link-local works with zero config: handheld `fe80::77:ff:fe00:2` (EUI-64 of 02:77:00:00:00:02) | Verified | ping + ssh |
| Setting a static IPv4 requires admin; non-admin sessions cannot | Verified | non-elevated context |
| PowerShell 5.1 pipes corrupt binary streams; use cmd.exe for `tar ... \| ssh` pipelines | Inferred (known PS 5.1 behaviour) | all binary pipelines were run from cmd and hash-verified |

## Build

| Finding | Status | Evidence |
| --- | --- | --- |
| zig 0.13.0 (PyPI wheel) cross-compiles static aarch64-musl dropbear + sftp-server reproducibly | Verified | identical SHA-256 on two machines |
| dropbear `-s` flag is rejected when password auth is compiled out | Verified | startup usage error |
| Under qemu, dropbear logs `fexecve failed ... Exec format error` and falls back; harmless | Verified | test logs |
| WSL clears `/tmp` when idle; copy build outputs out in the same session | Verified | build dir vanished between calls |
| OpenSSH git tag needs `autoreconf`; the release tarball does not | Verified | |

## Unexplained / not determined

| Event | What is known |
| --- | --- |
| First launches of the gadget produced **no USB event at all** on Windows (watcher saw nothing), while the identical gadget code later enumerated instantly | Cable, port and script were the same as far as recorded. Cause not determined. |
| Selecting "Check Connection" turned the screen dark and the handheld rebooted | Script contains no shutdown command; its report was never written. Possibly the low-voltage daemon (would be a poweroff, not reboot) - **not confirmed**. Avoid that launcher. |
| One boot after adding a new script + gamelist entry booted then shut down; reverting fixed it | Could have been the low-voltage daemon under boot load (battery ~44 %, 3.69 V idle) or the change itself. Journal lost on reboot, so **cannot tell**. Later boots with a hidden `.usbssh` folder were fine. Policy since: never edit `gamelist.xml`, keep payload outside `ports_scripts`. |

## TP-Link TL-WN722N

Not used. Never connected to the handheld; no evidence of a matching Wi-Fi driver in this kernel.
`CONFIG_USB_RTL8152=y` is for **wired** Realtek USB Ethernet (useful fallback: an RTL8153 adapter in the data port, untested).

## Godot / graphics (summary - details in `godot/README.md`)

| Finding | Status |
| --- | --- |
| libmali r13p0 (EGL 1.4) provides GBM but no Wayland EGL and none of the modern GBM plane/modifier calls | Verified |
| PortMaster Westonpack's crusty shim makes Weston run here; Godot 4 runs only as an X11 client via Xwayland | Verified |
| That path is far too slow to play (crusty reported ~0.5 FPS to the panel) | Verified (user-observed lag + log) |
| Godot's X11 prime-detection probe costs ~40 s at startup; `DRI_PRIME=0` skips it | Verified (user-timed) |
| Direct-to-screen FRT runtimes are the planned route | Planned |
