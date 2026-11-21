# Handoff prompt for another AI assistant (copy everything below the line)

---

You are taking over an in-progress project. Accuracy matters more than speed: label anything not directly verified as
[Inference], [Speculation] or [Unverified], cite the file or command output you rely on, give me ONE physical action at a time,
and end substantive replies with a short TLDR. If you cannot verify something, say so instead of guessing.

## Context

- Repo with everything so far (scripts, binaries, findings, logs of decisions): https://github.com/J-u-s-t-J-o-s-h/emuelec-usb-ssh
  Read `README.md`, `docs/findings.md`, and `godot/README.md` first.
- Device: generic RK3326 handheld (Mali-G31, 720x720), vendor EmuELEC 4.7 build, kernel 5.10.160 aarch64, glibc 2.36.
- PC: Windows 11 ("WORKSTATION01"), OpenSSH client, WSL Ubuntu 24.04 (no sudo available to automation).
- You cannot reach my machines; I will run commands and paste output. Prefer cmd.exe for pipelines (PowerShell 5.1 mangles quoting/binary pipes).

## What already works (verified)

- USB-C networking + key-only SSH/SFTP to the handheld: `ssh emuelec`, `scp file emuelec:/path`, `sftp emuelec`
  (handheld 172.31.255.2, PC 172.31.255.1; auto-starts at boot). Run remote scripts as `ssh emuelec sh -s < script.sh`.
- Game: "Monster Truck Backyard Bash", Godot **4.7** project, 3D, ~4,900 lines GDScript in 5 files (`src/main.gd`, `bash_hud.gd`,
  `truck.gd`, `toy_car.gd`, `audio_factory.gd`), one scene built in code, 720x720, max 30 FPS. Source of the handheld build is on the PC at
  `%USERPROFILE%\codex-workspace\Portable-Arcade\artifacts\backyard-bash-handheld-v1\source`. Never modify it - work on a copy.
- The original Weston route (game's current launcher) fails/crawls on this firmware's GBM-only libmali; abandoned (details in `godot/README.md`).
- **Working route: FRT runtime for Godot 4.1 (direct to screen via SDL2/KMSDRM + libmali):**
  - Runtime `frt_4.1.3.squashfs` from PortMaster-Runtime (md5 matches published; SHA-256 in `godot/README.md`), on the handheld at
    `/storage/roms/ports/backyardbash/frt/`. Binary inside: `frt_4.1.3` = Godot 4.1.3.stable (commit f06b6836a).
  - Needs newer C++ runtime: `frt/lib/libstdc++.so.6` (Debian 12 libstdc++6 12.2.0, checksum-verified). Plain copy - FAT32 has no symlinks.
  - Launch: `LD_LIBRARY_PATH=<frt>/lib frt_4.1.3 --main-pack X.pck --display-driver frt --rendering-driver opengl3 --audio-driver SDL2`
    (audio driver must be SDL2, not ALSA).
  - Measured: 3D smoke test (12 rigid bodies) at a steady ~52 FPS, first frame <1 s, user confirmed smooth.
  - Input: FRT 4.1.3 reads keyboards only. The firmware's `gptokeyb` maps the pad to keys:
    `gptokeyb 1 frt_4.1.3 -c <file>.gptk -killsignal 15 &` before launching. With `/usr/config/emuelec/configs/gptokeyb/default.gptk`:
    A=X, B=Z, X=C, Y=A, Left/Right/Down=arrows, Start=Enter, Select=Escape, L1=Shift, R1=S, L2=Home, R2=End.
  - Export pipeline: official Godot 4.1.3 Linux editor in WSL (SHA-512 verified): `--headless --editor --quit --path P` then
    `--headless --path P --export-pack "Linux" out.pck` (needs an `export_presets.cfg` with a "Linux" preset; see `godot/frt-smoke41/`).
  - Tests stop EmulationStation (`systemctl stop emustation`) and must restart it; run them detached so a dropped SSH session can't
    strand the device: `systemd-run --unit=NAME --quiet sh /tmp/script.sh` (no `setsid` on this firmware).

## Your task

Get the game running smoothly on the handheld via FRT 4.1.3:
1. Copy the project; change `config/features` to 4.1; import + export with the Godot 4.1.3 editor; fix every error the editor reports
   (4.7-only APIs). Report the error list before fixing.
2. Make sure every gameplay/menu action has keyboard bindings matching a game-specific `.gptk` file (copy default.gptk, adjust).
3. Provide a quit path inside the game (Select/Escape did NOT quit FRT).
4. Write a new Ports launcher next to the old one (do not edit `gamelist.xml`; do not add files to `ports_scripts` other than replacing
   the game's own launcher once it works), test, then commit to the repo.

## Open questions / caveats

- D-pad Up appeared to arrive as `W` (7 events, no `Up`) with default.gptk - unconfirmed; check `gptokeyb` mapping for `up`.
- `gptokeyb` logs `fopen(): Read-only file system` but still works - find out what it tries to write.
- Leftover test files on the handheld in `/storage/roms/ports/backyardbash/`: `run-crusty.sh`, `segvtrace.so`, `launch-crusty*.log`,
  `frt/` (runtimes, smoke41.pck, logs). Harmless; clean up when done.
- Battery: the data port doesn't charge; a vendor daemon powers off at <=3.40 V when not charging - keep a charger on the charge-only port.
- Card rules: games partition label EEROMS; handheld scripts must be LF; never edit `ports_scripts/gamelist.xml`.
