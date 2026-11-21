#!/bin/bash
# Monster Truck Backyard Bash - test launcher using PortMaster Westonpack's "crusty" layer,
# needed because this firmware's libmali (Bifrost r13p0) is GBM-only: no Wayland EGL and no
# modern GBM calls (gbm_bo_get_offset etc.). Mirrors the relevant parts of westonwrap.sh 0.2.7.1.
# Usage: run-crusty.sh [crusty_gbm|crusty_egl15compat] [seconds_to_run, 0 = until exit]
base=/storage/roms/ports/backyardbash
MODE=${1:-crusty_gbm}
SECS=${2:-0}
cd "$base" || exit 1
log="$base/launch-crusty${LOGTAG}.log"
exec >"$log" 2>&1
echo "run-crusty start $(cut -d' ' -f1 /proc/uptime)s mode=$MODE secs=$SECS"
tmp=$(mktemp -d /tmp/backyardbash.XXXXXX) || exit 1
seat= ; wm= ; game=
cleanup() {
  for p in $game $wm $seat; do kill "$p" 2>/dev/null; done
  sleep 0.5
  for p in $game $wm $seat; do kill -9 "$p" 2>/dev/null; done
  rm -f /run/seatd.sock /tmp/drmpipe; rm -rf /tmp/.X11-unix/X0 /tmp/.X0-lock
  umount "$tmp/weston" 2>/dev/null; umount "$tmp/engine" 2>/dev/null
  rmdir "$tmp/weston" "$tmp/engine" "$tmp/run" "$tmp" 2>/dev/null
  echo "run-crusty end $(cut -d' ' -f1 /proc/uptime)s"
  sync
}
trap cleanup EXIT
trap 'exit 1' INT TERM
mkdir -p "$tmp/engine" "$tmp/weston" "$tmp/run" "$base/saves" || exit 1
chmod 700 "$tmp/run"
mount -t squashfs -o loop,ro "$base/godot_4.7.1.squashfs" "$tmp/engine" || exit 1
mount -t squashfs -o loop,ro "$base/weston_pkg_0.2.squashfs" "$tmp/weston" || exit 1
engine="$tmp/engine/godot471.aarch64"
w="$tmp/weston"; l="$w/lib_aarch64"; cg="$l/graphics/crusty_gbm${CRUSTYDEBUG}"; gl="$l/graphics/$MODE${CRUSTYDEBUG}"
[ -f "$gl/libcrusty.so" ] || { echo "no such mode: $MODE"; exit 1; }
"$engine" --version

export CRUSTY_LIBGBM="$("$w/tools/findlib" libgbm.so.1)"
export CRUSTY_LIBDRM="$("$w/tools/findlib" libdrm.so)"
export CRUSTY_LIBEGL="$("$w/tools/findlib" libEGL.so)"
export CRUSTY_LIBSDL="$("$w/tools/findlib" libSDL2-2.0.so.0)"
echo "CRUSTY_LIBSDL=$CRUSTY_LIBSDL"
echo "CRUSTY_LIBGBM=$CRUSTY_LIBGBM CRUSTY_LIBDRM=$CRUSTY_LIBDRM CRUSTY_LIBEGL=$CRUSTY_LIBEGL"
export XDG_RUNTIME_DIR="$tmp/run" XKB_CONFIG_ROOT="$w/share/xkb"
export WESTON_MODULE_MAP="drm-backend.so=$l/libweston-14/drm-backend.so;gl-renderer.so=$l/libweston-14/gl-renderer.so;kiosk-shell.so=$l/weston/kiosk-shell.so;xwayland.so=$l/libweston-14/xwayland.so;"
export WESTON_DATA_DIR="$w/data" WESTON_LIBEXEC_DIR="$w/libexec"

rm -f /run/seatd.sock /tmp/drmpipe; mkfifo /tmp/drmpipe
if [ -n "$NOSEATD" ]; then
  echo "--- no seatd (LIBSEAT_BACKEND=$LIBSEAT_BACKEND)"
else
  echo "--- seatd"
  (cd "$w" && LD_LIBRARY_PATH="$l" LD_PRELOAD="$cg/libcrusty.so" exec ./seatd) &
  seat=$!
  sleep 0.5; chmod 777 /run/seatd.sock 2>/dev/null
fi

if [ -n "$XW" ]; then
  echo "--- xwayland prep"
  rm -rf /tmp/.X11-unix /tmp/.X0-lock; mkdir -p /tmp/.X11-unix; chmod 1777 /tmp/.X11-unix
  rm -rf /tmp/share /tmp/fonts; ln -s "$w/share" /tmp/share; ln -s "$w/fonts" /tmp/fonts
  export XWAYLAND_LD_LIBRARY_PATH="$l/graphics/mesa_x11_stub"
  XWARG="--xwayland"
fi
echo "--- weston"
(cd "$w" && LD_LIBRARY_PATH="$cg:$l" LD_PRELOAD="${PRELOAD_EXTRA:+$PRELOAD_EXTRA:}$cg/libcrusty.so" CRUSTY_SHOW_CURSOR=0 \
  exec ./wp_weston ${WESTON_CFG:---no-config} -B drm --drm-device=card0 --renderer=gl --shell=kiosk-shell.so -i0 -Sbackyardbash $XWARG $WESTON_EXTRA) &
wm=$!
for i in $(seq 1 100); do [ -S "$tmp/run/backyardbash" ] && break; kill -0 "$wm" 2>/dev/null || break; sleep 0.1; done
[ -S "$tmp/run/backyardbash" ] || { echo "WESTON FAILED: no wayland socket"; exit 1; }
echo "weston socket up after ${i}x0.1s"
if [ -n "$XW" ]; then
  for j in $(seq 1 100); do [ -e /tmp/.X11-unix/X0 ] && break; kill -0 "$wm" 2>/dev/null || break; sleep 0.1; done
  [ -e /tmp/.X11-unix/X0 ] || { echo "XWAYLAND FAILED: no X0 socket"; exit 1; }
  echo "xwayland X0 up after ${j}x0.1s"
fi

if [ -n "$WESTON_ONLY" ]; then echo "WESTON UP (weston-only test), holding ${SECS}s"; sleep "$SECS"; exit 0; fi
echo "--- godot ($MODE)"
export XDG_DATA_HOME="$base/saves"
if [ -n "$XW" ]; then
  DISPLAY=:0 XDG_SESSION_TYPE=x11 LD_LIBRARY_PATH="$gl:$l" LD_PRELOAD="$gl/libcrusty.so" \
    CRUSTY_WLMODE=0 CRUSTY_WLDISP=backyardbash \
    "$engine" --main-pack "$base/game.pck" --rendering-method gl_compatibility --rendering-driver ${GODOT_RDRIVER:-opengl3_es} \
    --fullscreen --audio-driver ALSA --display-driver x11 $GODOT_EXTRA -- --handheld &
else
  LD_LIBRARY_PATH="$gl:$l/extra_wayland:$l" LD_PRELOAD="$gl/libcrusty.so" \
    CRUSTY_WLMODE=0 CRUSTY_WLDISP=backyardbash WAYLAND_DISPLAY=backyardbash \
    "$engine" --main-pack "$base/game.pck" --rendering-method gl_compatibility --rendering-driver opengl3_es \
    --fullscreen --audio-driver ALSA --display-driver wayland -- --handheld &
fi
game=$!
if [ "$SECS" -gt 0 ]; then
  for i in $(seq 1 "$SECS"); do kill -0 "$game" 2>/dev/null || break; sleep 1; done
  if kill -0 "$game" 2>/dev/null; then echo "GODOT STILL RUNNING after ${SECS}s (stopping for test)"; else wait "$game"; echo "godot exited early, code $?"; fi
else
  wait "$game"; echo "godot exited, code $?"
fi
exit 0
