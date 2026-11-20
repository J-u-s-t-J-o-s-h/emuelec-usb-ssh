#!/bin/sh
# Start USB SSH v3: USB RNDIS gadget + bundled dropbear/sftp-server (key-only) + boot-service install + read-only diagnostics.
# Payload on the card: /storage/roms/.usbssh/{dropbearmulti,sftp-server,authorized_keys,usbssh-boot.sh,usbssh.service}
base=/storage/roms/ports_scripts
report=$base/usb-ssh-report.txt
payload=/storage/roms/.usbssh
dbdir=/storage/.dropbear
gadget=/sys/kernel/config/usb_gadget/portable_arcade
rndis=$gadget/functions/rndis.usb0
config=$gadget/configs/c.1
devmac=02:77:00:00:00:02
hostmac=02:77:00:00:00:01
handheld_ip=172.31.255.2
usb_status="not started"
ssh_status="not started"
summary=/tmp/usb-ssh-summary.txt
# Set USBSSH_NO_VIEWER=1 to skip the on-screen dialog (e.g. when run over SSH).
udc=

: > "$report"
exec >> "$report" 2>&1
sec() { echo; echo "##### $1"; sync; }
note() { echo "NOTE: $1"; }

sec "0 Start (Start USB SSH v3)"
date; uname -a; id

sec "1 USB gadget"
grep -q ' /sys/kernel/config configfs ' /proc/mounts || mount -t configfs configfs /sys/kernel/config
udc=$(ls /sys/class/udc 2>/dev/null | head -n 1)
if [ -z "$udc" ]; then
  usb_status="no USB device controller"
else
  mkdir -p "$gadget"
  bound=$(cat "$gadget/UDC" 2>/dev/null)
  if [ -z "$bound" ]; then
    printf '0x0525' > "$gadget/idVendor"; printf '0xa4a2' > "$gadget/idProduct"
    printf '0x0200' > "$gadget/bcdUSB"; printf '0x0100' > "$gadget/bcdDevice"
    mkdir -p "$gadget/strings/0x409" "$config/strings/0x409" "$rndis"
    printf 'PA20261120' > "$gadget/strings/0x409/serialnumber"
    printf 'Portable Arcade' > "$gadget/strings/0x409/manufacturer"
    printf 'USB Network' > "$gadget/strings/0x409/product"
    printf 'RNDIS network' > "$config/strings/0x409/configuration"
    printf '250' > "$config/MaxPower"
    printf '%s' "$devmac" > "$rndis/dev_addr"; printf '%s' "$hostmac" > "$rndis/host_addr"
    [ -e "$config/rndis.usb0" ] || ln -s "$rndis" "$config/rndis.usb0"
    if [ -d "$rndis/os_desc/interface.rndis" ]; then
      printf '1' > "$gadget/os_desc/use"; printf '0xcd' > "$gadget/os_desc/b_vendor_code"
      printf 'MSFT100' > "$gadget/os_desc/qw_sign"
      printf 'RNDIS' > "$rndis/os_desc/interface.rndis/compatible_id"
      printf '5162001' > "$rndis/os_desc/interface.rndis/sub_compatible_id"
      [ -e "$gadget/os_desc/c.1" ] || ln -s "$config" "$gadget/os_desc/c.1"
    fi
    printf '%s' "$udc" > "$gadget/UDC" || note "UDC bind write failed"
  else
    echo "Gadget already bound: $bound"
  fi
  netif=
  for i in 1 2 3 4 5 6 7 8; do
    for p in /sys/class/net/*; do
      [ "$(cat "$p/address" 2>/dev/null)" = "$devmac" ] && netif=$(basename "$p")
    done
    [ -n "$netif" ] && break; sleep 1
  done
  if [ -n "$netif" ]; then
    ip address replace "$handheld_ip/30" dev "$netif"; ip link set "$netif" up
    usb_status="$netif up at $handheld_ip"
  else
    usb_status="gadget bound but no interface"
  fi
fi
echo "USB: $usb_status"

sec "2 SSH server (bundled dropbear, key-only)"
mkdir -p "$dbdir"
if [ -f "$payload/dropbearmulti" ]; then
  cmp -s "$payload/dropbearmulti" "$dbdir/dropbearmulti" || cp "$payload/dropbearmulti" "$dbdir/dropbearmulti"
  chmod 755 "$dbdir/dropbearmulti"
fi
if [ -f "$payload/sftp-server" ]; then
  cmp -s "$payload/sftp-server" "$dbdir/sftp-server" || cp "$payload/sftp-server" "$dbdir/sftp-server"
  chmod 755 "$dbdir/sftp-server"
fi
db=$dbdir/dropbearmulti
sha256sum "$db" "$dbdir/sftp-server" 2>&1
if [ -f "$payload/usbssh-boot.sh" ] && [ -f "$payload/usbssh.service" ]; then
  cmp -s "$payload/usbssh-boot.sh" "$dbdir/usbssh-boot.sh" || cp "$payload/usbssh-boot.sh" "$dbdir/usbssh-boot.sh"
  chmod 755 "$dbdir/usbssh-boot.sh"
  mkdir -p /storage/.config/system.d
  if ! cmp -s "$payload/usbssh.service" /storage/.config/system.d/usbssh.service; then
    cp "$payload/usbssh.service" /storage/.config/system.d/usbssh.service
    systemctl daemon-reload
  fi
  systemctl is-enabled usbssh.service >/dev/null 2>&1 || systemctl enable usbssh.service 2>&1
  echo "boot service: $(systemctl is-enabled usbssh.service 2>&1)"
fi
home=$(awk -F: '$1=="root"{print $6}' /etc/passwd); [ -n "$home" ] || home=/storage
echo "root home: $home"
mkdir -p "$home/.ssh"; chmod 700 "$home/.ssh"
if [ -f "$payload/authorized_keys" ]; then
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    grep -qxF "$k" "$home/.ssh/authorized_keys" 2>/dev/null || echo "$k" >> "$home/.ssh/authorized_keys"
  done < "$payload/authorized_keys"
fi
chmod 600 "$home/.ssh/authorized_keys" 2>/dev/null
ls -ld "$home" "$home/.ssh" "$home/.ssh/authorized_keys" 2>&1
[ -f "$dbdir/host_ed25519" ] || "$db" dropbearkey -t ed25519 -f "$dbdir/host_ed25519" 2>&1
"$db" dropbearkey -y -f "$dbdir/host_ed25519" 2>&1 | grep -i fingerprint
if [ -f "$dbdir/dropbear.pid" ]; then kill "$(cat "$dbdir/dropbear.pid")" 2>/dev/null; sleep 1; fi
"$db" dropbear -r "$dbdir/host_ed25519" -p 22 -P "$dbdir/dropbear.pid" 2>&1
sleep 2
if netstat -lnt 2>/dev/null | grep -q ':22 '; then ssh_status="listening on port 22"; else ssh_status="NOT listening"; fi
echo "SSH: $ssh_status"
netstat -lnt 2>&1

sec "3 Device-tree role for ff300000.usb"
for f in dr_mode status compatible usb-role-switch; do
  p=/proc/device-tree/usb@ff300000/$f
  if [ -e "$p" ]; then printf '%s: ' "$f"; tr '\0' ' ' < "$p"; echo; else echo "$f: (absent)"; fi
done

sec "4 UDC state, role switch, extcon, power"
for f in state current_speed maximum_speed is_otg is_a_peripheral; do
  [ -r "/sys/class/udc/$udc/$f" ] && printf '%s: %s\n' "$f" "$(cat "/sys/class/udc/$udc/$f")"
done
printf 'gadget UDC: [%s]\n' "$(cat "$gadget/UDC" 2>/dev/null)"
ls /sys/class/usb_role/ /sys/class/typec/ /sys/class/extcon/ 2>&1
for e in /sys/class/extcon/*; do [ -d "$e" ] && printf '%s %s %s\n' "$e" "$(cat "$e/name" 2>/dev/null)" "$(cat "$e/state" 2>/dev/null | tr '\n' ' ')"; done
for ps in /sys/class/power_supply/*; do [ -d "$ps" ] && printf '%s type=%s online=%s\n' "$ps" "$(cat "$ps/type" 2>/dev/null)" "$(cat "$ps/online" 2>/dev/null)"; done

sec "5 Network interfaces"
for n in /sys/class/net/*; do printf '%s addr=%s oper=%s carrier=%s\n' "$(basename "$n")" "$(cat "$n/address" 2>/dev/null)" "$(cat "$n/operstate" 2>/dev/null)" "$(cat "$n/carrier" 2>/dev/null)"; done
ls /sys/class/ieee80211/ 2>&1

sec "6 Kernel messages (USB-related, last 120)"
dmesg 2>&1 | grep -Ei 'dwc2|ff300000|udc|gadget|rndis|otg|vbus|usb|role|extcon|phy' | tail -n 120

sec "7 Other SSH servers on the system"
for b in sshd dropbear; do printf '%s: %s\n' "$b" "$(command -v $b 2>/dev/null || echo none)"; done
ls -l /usr/sbin/sshd /usr/bin/sshd 2>&1

sec "END"

{
  echo "USB:  $usb_status"
  echo "SSH:  $ssh_status"
  printf 'DT dr_mode: '; tr '\0' ' ' < /proc/device-tree/usb@ff300000/dr_mode 2>/dev/null || printf 'absent'; echo
  printf 'UDC state:  %s\n' "$(cat /sys/class/udc/$udc/state 2>/dev/null)"
  for n in /sys/class/net/*; do
    b=$(basename "$n"); [ "$b" = lo ] && continue
    printf 'net %s: %s %s\n' "$b" "$(cat "$n/operstate" 2>/dev/null)" "$(ip -4 -o addr show dev "$b" 2>/dev/null | awk '{print $4}' | tr '\n' ' ')"
  done
  echo
  echo "Full report: ports_scripts/usb-ssh-report.txt"
  echo "Leave the cable connected and tell Claude what this shows."
} > "$summary"
sync
[ -z "$USBSSH_NO_VIEWER" ] && command -v text_viewer >/dev/null 2>&1 && text_viewer "$summary" -t "USB SSH v3" -f 18 -w >/dev/null 2>&1
exit 0
