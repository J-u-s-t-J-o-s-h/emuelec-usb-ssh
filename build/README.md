# Building the handheld binaries

Both scripts produce byte-identical outputs (verified 2026-11-20 on two machines):

| File | SHA-256 |
| --- | --- |
| dropbearmulti | 659ccbc7c0477db5930933eb5bf55bc2892836f1aa2a835379772f0682afb897 |
| sftp-server | 35ddd94b7532601803f4b76c09fefcdd0ddd70d1878ca2b75ee76a7093e55300 |

- `build.sh` - from git tags (dropbear `DROPBEAR_2024.86` @155639d4, OpenSSH `V_9_9_P1` @53a80baa). Needs: sh, curl, python3, git, make, autoreconf (autoconf 2.71 used).
- `build-wsl.sh` - same, but sftp-server from the official `openssh-9.9p1.tar.gz` (configure pre-generated, so no autoreconf). Tarball SHA-256 seen: b343fbcdbff87f15b1986e6e15d6d4fc9a7d36066be6b7fb507087ba8f966c02. The ten sftp-related source files were hash-identical to the git tag.

Toolchain: zig 0.13.0 from PyPI (`ziglang` wheel), target `aarch64-linux-musl`, fully static, stripped.

dropbear options (`localoptions.h`): password and PAM auth compiled out (key-only), X11 forwarding off,
`SFTPSERVER_PATH "/storage/.dropbear/sftp-server"`. Multi-binary: `dropbear`, `dropbearkey`, `scp`.

Run in Linux/WSL: `sh build/build.sh` -> `/tmp/dbbuild2/out/`. Compare with `bin/SHA256SUMS`.
Note: WSL clears /tmp when it idles - copy outputs out in the same session.
