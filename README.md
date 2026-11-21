# EmuELEC handheld: USB-C networking + key-only SSH/SFTP

Manage a generic RK3326 EmuELEC handheld from a Windows PC over a **direct USB-C cable**, with the
microSD card left in the handheld. The handheld presents a USB RNDIS network adapter to Windows,
runs a bundled static **dropbear** SSH server (key login only) with OpenSSH's **sftp-server**, and
starts all of it automatically at boot.

Status: working and verified end to end on 2026-11-20, including after cold reboots.
See [`docs/findings.md`](docs/findings.md) for everything learned along the way (verified vs inferred).

## Daily use (from the PC, cmd or PowerShell)

```
ssh emuelec                                             # root shell on the handheld
scp "C:\path\Game.gba" emuelec:/storage/roms/gba/       # copy a file to the handheld
scp -r "C:\path\folder" emuelec:/storage/roms/gba/      # copy a folder
scp emuelec:/storage/roms/gba/gamelist.xml .            # copy a file back
sftp emuelec                                            # interactive file browser
```

GUI: WinSCP (SFTP, host `172.31.255.2`, user `root`, key `%USERPROFILE%\.ssh\emuelec_ed25519`).

- Boot the handheld with the cable in the **data (OTG)** USB-C port. SSH is ready ~8 s after power-on.
- The data port does **not** charge the handheld. For long sessions also connect a charger to the
  charge-only port: a vendor service powers the handheld off at <= 3.40 V when it is not charging.

## Layout

| Path | What it is | Where it ends up |
| --- | --- | --- |
| `bin/dropbearmulti` | dropbear 2024.86, static aarch64, key-only, SFTP path set | card `.usbssh/` -> `/storage/.dropbear/` |
| `bin/sftp-server` | OpenSSH 9.9p1 sftp-server, static aarch64 | card `.usbssh/` -> `/storage/.dropbear/` |
| `bin/SHA256SUMS` | expected hashes (installer refuses mismatches) | - |
| `handheld/Start USB SSH.sh` | Ports launcher v3: gadget + SSH + installs boot service + diagnostics report | card `ports_scripts/` |
| `handheld/usbssh-boot.sh` | non-interactive boot script (gadget, IP, dropbear) | `/storage/.dropbear/` |
| `handheld/usbssh.service` | systemd unit, runs after the frontend, 60 s limit, kill switch | `/storage/.config/system.d/` |
| `handheld/update-stage.sh`, `update-swap.sh`, `rollback.sh` | safe binary updates over SSH | run via `ssh ... sh -s <` |
| `windows/new-key.cmd` | creates `%USERPROFILE%\.ssh\emuelec_ed25519` (never overwrites) | PC |
| `windows/install-to-card.ps1` | verifies hashes + volume label EEROMS, backs up, copies payload + launcher | PC, card in reader |
| `windows/set-static-ip.ps1` | one-time, **admin**: 172.31.255.1/30 on the adapter with MAC 02-77-00-00-00-01 | PC |
| `windows/ssh-config.txt` | `Host emuelec` block for `%USERPROFILE%\.ssh\config` | PC |
| `windows/watch-usb.ps1` | diagnostic: logs every USB/network device change every 2 s | PC |
| `build/` | reproducible build scripts + notes | Linux/WSL |
| `godot/` | Godot investigation: test launcher, crash reporter, findings, FRT plan | handheld / reference |

## Rebuild from scratch

Prerequisites: Windows 10/11 with the built-in OpenSSH client; a microSD reader; this repo
checked out (`.gitattributes` keeps the handheld scripts LF - do not convert them).

1. **Key (PC):** run `windows\new-key.cmd`.
2. **Card (PC):** shut the handheld down from its menu, put the card in the PC, then from the repo root:
   `powershell -ExecutionPolicy Bypass -File windows\install-to-card.ps1 -Drive F`
   (it aborts unless the volume label is `EEROMS`; it never edits `gamelist.xml`). Eject safely.
3. **Handheld:** insert the card, boot, connect the USB-C cable from the **data** port to the PC,
   open Ports > **Start USB SSH** once. The screen should show `USB: usb0 up`, `SSH: listening on port 22`,
   `UDC state: configured`. This run also installs and enables the boot service.
4. **Static IP (PC, once, elevated PowerShell):** `powershell -ExecutionPolicy Bypass -File windows\set-static-ip.ps1`
5. **SSH config (PC):** append `windows\ssh-config.txt` to `%USERPROFILE%\.ssh\config`.
6. **Test:** `ssh emuelec`, accept the host key on first use, then `sftp emuelec`.
   Reboot the handheld without launching anything and repeat to prove auto-start.

Before step 4 you can already connect over IPv6 link-local: `ssh emuelec-ll` (edit the `%64`
interface index in `ssh-config.txt` to match `Get-NetAdapter`'s ifIndex for the RNDIS adapter).

## Rebuilding the binaries

See [`build/README.md`](build/README.md). Both build routes reproduce the hashes in `bin/SHA256SUMS`
byte for byte (zig 0.13.0 cross-compiler from PyPI, `aarch64-linux-musl`, static).

## Updating binaries without losing access

1. `ssh emuelec mkdir -p /storage/.dropbear/staging`
2. `scp bin/dropbearmulti bin/sftp-server emuelec:/storage/.dropbear/staging/`
3. `ssh emuelec sh -s < handheld/update-stage.sh` (starts the new server on **port 2222**, port 22 untouched)
4. Test: `ssh -p 2222 emuelec` and `sftp -P 2222 emuelec`
5. Only if OK: `ssh -p 2222 emuelec sh -s < handheld/update-swap.sh` (keeps `dropbearmulti.prev`)

Rollback: `ssh emuelec sh -s < handheld/rollback.sh`

## Recovery

- **Disable auto-start without SSH:** card in PC -> create an empty file `F:\.usbssh\disable`. The service
  skips itself while that file exists. Delete the file to re-enable.
- **Remove the boot service (over SSH):** `systemctl disable --now usbssh.service` then delete
  `/storage/.config/system.d/usbssh.service`.
- **Host key changed / reinstall:** delete the `emuelec-handheld` line in `%USERPROFILE%\.ssh\known_hosts_emuelec`.
- **Lost the PC key:** create a new one (`new-key.cmd`), re-run `install-to-card.ps1`, run the launcher once.
- **Windows sees nothing on plug-in:** run `windows\watch-usb.ps1`, then launch Start USB SSH; any
  "Unknown USB Device" = signal/cable issue, nothing at all = handheld side (see findings).

## Security notes

- Password and PAM login are compiled out of dropbear: only keys in `/storage/.ssh/authorized_keys` work.
- The link is a point-to-point USB network (172.31.255.0/30); nothing is exposed on Wi-Fi or LAN.
- Anyone holding `emuelec_ed25519` (no passphrase) gets root on the handheld. Never commit it
  (`.gitignore` blocks key and host-key files).

## Licences

The binaries in `bin/` are redistributed under their upstream licences, included in full in `LICENSES/`:

- `bin/dropbearmulti`: dropbear 2024.86 (https://github.com/mkj/dropbear), see `LICENSES/dropbear-LICENSE`.
- `bin/sftp-server`: OpenSSH portable 9.9p1 (https://github.com/openssh/openssh-portable), see `LICENSES/openssh-LICENCE`.

Both are unmodified apart from the build-time options listed in `build/README.md`.
The scripts and documentation in this repository are provided as-is, with no warranty.
