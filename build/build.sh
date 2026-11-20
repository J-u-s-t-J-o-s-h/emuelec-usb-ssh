#!/bin/sh
# Reproducible static aarch64 build: dropbear 2024.86 (key-only, SFTP path set) + OpenSSH 9.9p1 sftp-server.
# Output: /tmp/dbbuild2/out/{dropbearmulti,sftp-server}
set -e
B=/tmp/dbbuild2
rm -rf $B; mkdir -p $B/out; cd $B
URL=$(curl -sSf https://pypi.org/pypi/ziglang/0.13.0/json | python3 -c 'import sys,json; print([u["url"] for u in json.load(sys.stdin)["urls"] if "manylinux" in u["filename"] and "x86_64" in u["filename"]][0])')
curl -sSfL -o zig.whl "$URL"
python3 -m zipfile -e zig.whl zigpkg
chmod +x zigpkg/ziglang/zig
Z=$B/zigpkg/ziglang/zig
printf '#!/bin/sh\nexec %s cc -target aarch64-linux-musl "$@"\n' "$Z" > zcc
printf '#!/bin/sh\nexec %s ar "$@"\n' "$Z" > zar
chmod +x zcc zar
git -c advice.detachedHead=false clone -q --depth 1 --branch DROPBEAR_2024.86 https://github.com/mkj/dropbear.git dropbear
cd dropbear
test "$(git rev-parse HEAD)" = 155639d40113a8ffc61aff3078e49f6e20090481
printf '%s\n' '#define DROPBEAR_X11FWD 0' '#define DROPBEAR_SVR_PASSWORD_AUTH 0' '#define DROPBEAR_SVR_PAM_AUTH 0' '#define DROPBEAR_SVR_PUBKEY_AUTH 1' '#define DEFAULT_PATH "/usr/bin:/bin:/usr/sbin:/sbin:/storage/bin"' '#define SFTPSERVER_PATH "/storage/.dropbear/sftp-server"' > localoptions.h
CC=$B/zcc AR=$B/zar RANLIB=true CFLAGS="-Os" LDFLAGS="-s" ./configure --host=aarch64-linux-musl --disable-zlib --enable-static --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx --disable-pututline --disable-pututxline --disable-harden > ../db-configure.log 2>&1
make -j8 PROGRAMS="dropbear dropbearkey scp" MULTI=1 STATIC=1 > ../db-make.log 2>&1
cp dropbearmulti $B/out/
cd $B
git -c advice.detachedHead=false clone -q --depth 1 --branch V_9_9_P1 https://github.com/openssh/openssh-portable.git ossh
cd ossh
test "$(git rev-parse HEAD)" = 53a80baaebda180f46e6e8571f3ff800e1f5c496
autoreconf -i > ../ossh-autoreconf.log 2>&1
CC=$B/zcc AR=$B/zar RANLIB=true CFLAGS="-Os" LDFLAGS="-static -s" ./configure --host=aarch64-linux-musl --without-openssl --without-zlib --without-pam --without-selinux --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx --disable-pututline --disable-pututxline --without-stackprotect --without-hardening > ../ossh-configure.log 2>&1
make -j8 sftp-server > ../ossh-make.log 2>&1
cp sftp-server $B/out/
cd $B/out; ls -l; sha256sum dropbearmulti sftp-server
