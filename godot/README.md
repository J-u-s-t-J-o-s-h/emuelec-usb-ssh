# Godot on this handheld: findings and test tooling

Game: "Monster Truck Backyard Bash" (Godot **4.7**, GL Compatibility, 720x720, 3D, ~4,900 lines of GDScript,
one scene built entirely in code). Original launcher: `ports_scripts/Monster Truck Backyard Bash.sh`,
game dir `/storage/roms/ports/backyardbash/` (`game.pck`, `godot_4.7.1.squashfs`, `weston_pkg_0.2.squashfs`).

Status (2026-11-21): Weston + Xwayland route runs but is too slow to play. **FRT (Godot 4.1, direct to screen) proven:
~52 FPS steady** on a 3D smoke test. Controller input works via `gptokeyb`. Next: downgrade the game 4.7 -> 4.1.

## Root cause of the original error

`Failed to load module drm-backend.so: undefined symbol: gbm_bo_get_offset`

| Fact | Status |
| --- | --- |
| `/usr/lib/libgbm.so*`, `libEGL`, `libGLESv2` are all symlinks to Rockchip **libmali** (Bifrost r13p0, EGL 1.4) | Verified |
| libmali has only basic GBM (no `gbm_bo_get_offset`, plane/modifier calls) and **no Wayland EGL** (`wl_egl_window_create` absent) | Verified (`grep -c` on the binary) |
| `weston_pkg_0.2.squashfs` is PortMaster **Westonpack 0.2.7.1**, which ships the **crusty** shim for exactly this kind of driver | Verified (`westonwrap.sh`, `version.txt`) |
| The game launcher started `wp_weston` directly and skipped crusty, so Weston used libmali's GBM | Verified |

## What it took to get Weston + Godot up (in order)

| # | Failure | Fix |
| --- | --- | --- |
| 1 | `gbm_bo_get_offset` undefined | Put `graphics/crusty_gbm` first in `LD_LIBRARY_PATH` and preload its `libcrusty.so`; set `CRUSTY_LIBGBM/LIBDRM/LIBEGL` via the package's `tools/findlib` |
| 2 | seatd failed (`libX11.so.6` not found), Weston fell back to an embedded seat, `card0` open: EINVAL | seatd needs `lib_aarch64` on its path; later dropped seatd entirely: `LIBSEAT_BACKEND=noop` (crusty fakes DRM anyway) |
| 3 | Weston segfault right after `DRM Intercepted device open` | Crash reporter (`tools/segvtrace.c`) showed **pc=0 called from libcrusty.so**: crusty's SDL2 pointers were NULL because `/tmp/CRUSTY_LIBSDL64.so -> libSDL2-2.0.so.0` (bare name) dangled. Fix: `CRUSTY_LIBSDL=$(findlib libSDL2-2.0.so.0)` (full path) |
| 4 | Godot: `Can't get a valid initial EGL display` (Wayland driver) | **No crusty variant supports Wayland EGL clients** (`wl_egl_window` absent in all). crusty supports **X11** clients: run Weston with `--xwayland`, Godot with `--display-driver x11`, `crusty_x11egl` preload |
| 5 | ~60 s black screen at start | Godot's X11 GPU "prime" probe spawned extra Godot processes through the slow stack; `DRI_PRIME=0` skips it (black screen ~60 s -> ~20 s, user-observed) |

How crusty works here (observed in debug logs): it gives Weston a **fake DRM device** and shows Weston's output
through **SDL2 (KMSDRM)**; client rendering goes through libmali GBM and is copied into the X11/Xwayland path.

## Measured result

- Godot 4.7.1 starts, creates a GLES context, reaches its X11 window ~5 s after launch, runs indefinitely (no crash).
- User: visible game, **very laggy**. crusty's frame counter printed **0.51 FPS** (single sample at shutdown; indicative only).
- Godot `--print-fps` output was lost (stdout buffered, process killed) - real Godot FPS not yet measured.
- CPU governor `performance` @ 1.296 GHz, GPU 520 MHz: no easy clock headroom.

Inference: every frame crosses GPU -> CPU readback -> Xwayland -> Weston composite -> crusty SDL2 -> panel; that copy chain,
not the game, is the bottleneck on an RK3326.

## Tools in this folder

- `run-crusty.sh` - test launcher reproducing the relevant parts of `westonwrap.sh` without PortMaster. Lives next to the game
  on the handheld. Usage: `run-crusty.sh <crusty_mode> <seconds>`; switches (env):
  `XW=1` (Xwayland/X11 mode - the working one), `NOSEATD=1` + `LIBSEAT_BACKEND=noop`, `WESTON_CFG="-c /tmp/bb-weston.ini"`,
  `WESTON_ONLY=1`, `CRUSTYDEBUG=_debug`, `PRELOAD_EXTRA=/path/segvtrace.so`, `GODOT_EXTRA=--print-fps`, `LOGTAG=-X`
  (log: `launch-crusty<LOGTAG>.log`). Working invocation:
  `XW=1 NOSEATD=1 LIBSEAT_BACKEND=noop WESTON_CFG="-c /tmp/bb-weston.ini" DRI_PRIME=0 run-crusty.sh crusty_x11egl 90`
  (`/tmp/bb-weston.ini` = `[core]` + `[output] name=DSI-1 scale=1`). It stops EmulationStation first; restart it after.
- Run long tests **detached** so a dropped SSH session cannot strand the handheld with EmulationStation stopped:
  `systemd-run --unit=bbtest --quiet sh -c 'sh /tmp/test.sh > /tmp/test.out 2>&1'` (the firmware has no `setsid`).
- `tools/segvtrace.c` - tiny LD_PRELOAD crash reporter (pc, lr, fault address, frame walk, executable mappings).
  Build: `zig cc -target aarch64-linux-gnu.2.17 -shared -fPIC -O1 -fno-omit-frame-pointer -s -o segvtrace.so segvtrace.c`.

## Next step: FRT (direct to screen, no Weston/Xwayland/crusty)

EmulationStation already renders through SDL2 + KMSDRM + libmali on this device, the same path FRT uses (inference).
Runtimes downloaded from PortMaster's official release and md5-verified against the published `.md5` files:

| File | URL | SHA-256 |
| --- | --- | --- |
| `frt_4.1.3.squashfs` (Godot 4.1 - would allow a 4.7 -> 4.1 downgrade instead of a 4 -> 3 rewrite, if it works) | https://github.com/PortsMaster/PortMaster-Runtime/releases/download/runtimes/frt_4.1.3.squashfs | 3f827fe66741b9cee45dd4808a9d4303ca1ced3a8820084754d99b653455d07b |
| `frt_3.6.squashfs` (Godot 3.6) | https://github.com/PortsMaster/PortMaster-Runtime/releases/download/runtimes/frt_3.6.squashfs | 0907fdda3d78bad97b69ad9fe5084d016a8525a778bd382dd9a9db0f873e493e |

Upstream FRT also publishes Godot 3.6.3 arm64 builds (https://github.com/efornara/frt/releases, tag `3.6.3-1`); the
`-trixie` variants likely need a newer glibc than the handheld's 2.36 (inference, untested).

Plan: inspect both runtimes on the handheld (linked libraries, display backend), smoke-test a small 3D scene for FPS, then port
the game on a **copy** of the project (never the original source).

## FRT smoke test result (2026-11-21)

`frt_4.1.3` = Godot `4.1.3.stable` (same commit `f06b6836a` as the official 4.1.3 editor), display driver `frt`
(SDL2 + EGL/libmali + DRM; no Wayland/X11). It needs `GLIBCXX_3.4.30`: bundle Debian 12 `libstdc++6`
`12.2.0-14+deb12u1` arm64 (package SHA-256 26e138c677a985775331373828a6c286c551ff397cb735d00e2383cb273d1cb2, verified
against the official Packages index); the extracted `libstdc++.so.6.0.30` has SHA-256
532f3a12d7b8fef6cc7a064ea106b6c4ab2365674b73e743e4a385d4ffb6c8ab. Audio driver must be `SDL2` (not `ALSA`).

| Measure | Result |
| --- | --- |
| Renderer | `Mali-G31 / ARM` |
| Time to first frame | under 1 s |
| FPS, 12 rigid bodies, 720x720 | 50-54 for 44 s (log); user saw boxes falling, smooth, ~52 FPS |
| Exit | clean (`exit code 0`), EmulationStation restored |
| Controller input | Without help: **0 events** - this FRT build never opens gamepads (no `SDL_JoystickOpen`/`SDL_GameControllerOpen` imports), only keyboards. With the firmware's `gptokeyb` + `default.gptk`: **123 key events**, all buttons arrive as keys |

Tooling: `frt-smoke41/` (project, export preset), `frt-smoke-run.sh` (runner). Export with the official Godot 4.1.3
Linux editor (SHA-512 verified from godot-builds): `--headless --editor --quit` then `--headless --export-pack "Linux" smoke41.pck`.

### Input via gptokeyb (verified 2026-11-21)

Run `gptokeyb 1 frt_4.1.3 -c <file>.gptk -killsignal 15 &` before the game (same form EmulationStation uses).
`default.gptk` delivered: A=`X`, B=`Z`, X=`C`, Y=`A`, D-pad Left/Right/Down=arrows, Start=`Enter`, Select=`Escape`,
L1=`Shift`, R1=`S`, L2=`Home`, R2=`End`. D-pad Up arrived as `W` (inference: `Up` never appeared; to confirm).
Esc did **not** quit FRT (exit shortcut is something else) - the game must handle quitting.
`gptokeyb` logs `fopen(): Read-only file system` but works.

## Backyard Bash FRT port (2026-11-21)
The game now has a tested FRT 4.1.3 port and replacement launcher.
See [backyardbash-frt41/README.md](backyardbash-frt41/README.md) for the reproducible
copy-and-patch build, keyboard mapping, initial errors and device logs.
Installed-launcher samples: 30.07 FPS Car Crush, 30.11 Stunt Stars, 28.06 Castle
Crash; 24 simultaneous castle smashes fall to 20.86 FPS. Select/Escape quit and
frontend restoration are verified by automated keyboard tests.
[Unverified] Physical controls and perceived smoothness await the user's play test.
