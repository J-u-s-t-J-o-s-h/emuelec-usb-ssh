# Backyard Bash on FRT 4.1.3

This port adapts a **copy** of the 4.7 handheld project to Godot 4.1.3.
It uses the existing checksum-verified FRT runtime and C++ library described in
[../README.md](../README.md). No Weston, Xwayland or gamelist edits.

## Verified results (2026-11-21)

- Installed launcher: keyboard-driven integration checks pass; clean Select/Escape
  exit code 0; EmulationStation restored by the detached test wrapper.
- Eight-second driving samples: Car Crush **30.07 FPS**, Stunt Stars **30.11 FPS**,
  Castle Crash **28.06 FPS**. These are samples, not a guaranteed minimum.
- Destruction stress samples: eight cars crushed simultaneously **29.96 FPS**;
  24 castle pieces smashed simultaneously **20.86 FPS**. Heavy castle destruction
  therefore still falls below the 30 FPS target (evidence/device-stress.log).
- Game-ready message at **6.634 seconds** after engine start.
- Timeout recovery: timeout exit 124, runner exit 143, frontend active,
  no surviving FRT game process or temporary runtime mount.
- Original source: all 26 files byte-identical to the pre-edit archive.
- Fresh-copy patch/import/audio bake/export succeeds; exported pack passes the
  existing single-player smoke test.
- Evidence: [evidence/](evidence/), especially device-installed.log and initial-errors.txt.

**[Unverified]** Physical pad use with this game-specific mapping, perceived
smoothness, and audible output still require the user's hands-on check.
Automated input is injected as keyboard events; it does not prove the gptokeyb
physical-button path. Earlier FRT smoke tests proved that path with default.gptk.

## Changes

Single-player handheld mode retains all three games, 32 toy cars, 72 castle pieces,
seven ramps, customization and the recorded horns. A 240x240 3D view is enlarged
behind the native 720x720 interface. Rigid visual parts are batched; lighting is
simplified; the decorative crowd is reduced. Full-screen menus skip 3D rendering.
Synthesized audio is generated on the PC and loaded as resources on the handheld.

The initial export preset used the newer platform identifier Linux; 4.1.3 needs
Linux/X11. The preset name is now Linux. The observed incompatible game property
was PanoramaSkyMaterial.energy_multiplier at original main.gd:918. The final
lightweight environment uses a color background instead of that panorama.

All initial distinct errors are preserved in evidence/initial-errors.txt.
Godot 4.1.3 can report Resource/PagedAllocator cleanup errors after savepack ends,
and its headless dummy renderer reports mesh_get_surface_count errors. build.py
allows only those exact observed messages in the relevant stages, records them,
and requires the exported-pack SMOKE_PASS. Unexpected errors fail the build.
On-device clean exits still report ObjectDB/resources-in-use diagnostics.
Their underlying engine cause is **[Unverified]**; exit code and frontend recovery
are directly verified.

The original HUD smoke assertion raced _process. It now waits up to five frames
for the same exact score equality, rather than asserting at a pre-process signal.

## Controls

backyardbash.gptk is copied from the firmware default, with game-specific changes.

| Handheld | Key | Action |
| --- | --- | --- |
| D-pad / analog | arrows | Navigate; steer; up/down drive/reverse |
| A | Enter | Confirm, join, ready, replay; accelerate while driving |
| B | Backspace | Back/cancel; brake/reverse while driving |
| X | Space | Horn |
| Y | C | Confirm customization |
| Start | P | Pause/resume |
| Select | Escape | Save and quit from every state |
| L1 / R1 | Q / E | Previous/next topper in customization |
| L2 / R2 | S / W | Reverse/accelerate |
| L3 / R3 | Space / C | Horn / confirm customization |

Up also accepts W in menus because the earlier default mapping's Up observation
was inconclusive. **[Unverified]** That hardware-specific discrepancy is not resolved.

## Rebuild (WSL/Linux)

Requires Python 3.10+, patch, and the official Linux x86_64 Godot 4.1.3 editor.
Verify the editor ZIP against the upstream SHA512-SUMS.txt before extracting.
build.py also checks its exact version and fingerprints the original input files.

```sh
python3 build.py /path/to/original/source /path/to/NEW/output /path/to/Godot_v4.1.3-stable_linux.x86_64
```

The destination must not exist and must be outside the original. The script copies
the project, applies port.patch, imports, bakes audio, exports game.pck, and tests
that exported pack. Original game assets and family recordings are not included
in this repository; they are copied locally from the authorized original.

The tested deployed pack SHA-256 is:
```text
5e7dab0e58ae9fee563287f1ce3cbdc6d7af8fb319e3b932755ec56ae153cfe2
```
Pack output is not claimed to be byte-reproducible across project paths/import
caches. The independent fresh-copy build has its own checksum.

## Device layout and testing

Place game.pck, backyardbash.gptk, run-frt41.sh and test-frt41.sh in
/storage/roms/ports/backyardbash/frt41/. Keep existing frt/ runtime and lib/ files.
Scripts must use LF line endings. Use cmd.exe for Windows SSH redirection.

```sh
systemd-run --unit=bb-frt41-test --quiet sh /storage/roms/ports/backyardbash/frt41/test-frt41.sh
```

The wrapper stops and restores EmulationStation and limits testing to 90 seconds.
It uses separate test-savedata. Normal saves live in frt41/savedata.
run-frt41.sh owns only its game process, gptokeyb process and private runtime mount.
It does not stop the frontend when called from Ports.

Only after testing, back up and replace the game's existing
ports_scripts/Monster Truck Backyard Bash.sh with the two-line launcher here.
Never edit ports_scripts/gamelist.xml. The deployment verified its SHA-256 unchanged.

Rollback on the tested device: copy frt41/original-ports-launcher.sh back over
the game's Ports launcher. Original game.pck, runtimes and source remain intact.
