#!/bin/sh
# Boot-time USB RNDIS gadget + dropbear (key-only). Log: /storage/.dropbear/boot.log
dbdir=/storage/.dropbear
log=$dbdir/boot.log
gadget=/sys/kernel/config/usb_gadget/portable_arcade
rndis=$gadget/functions/rndis.usb0
config=$gadget/configs/c.1
devmac=02:77:00:00:00:02
hostmac=02:77:00:00:00:01
exec > "$log" 2>&1
echo "usbssh-boot start: $(date) uptime=$(cut -d' ' -f1 /proc/uptime)"
grep -q ' /sys/kernel/config configfs ' /proc/mounts || mount -t configfs configfs /sys/kernel/config
udc=
for i in $(seq 1 30); do udc=$(ls /sys/class/udc 2>/dev/null | head -n 1); [ -n "$udc" ] && break; sleep 1; done
if [ -n "$udc" ] && [ -z "$(cat "$gadget/UDC" 2>/dev/null)" ]; then
  mkdir -p "$gadget/strings/0x409" "$config/strings/0x409" "$rndis"
  printf '0x0525' > "$gadget/idVendor"; printf '0xa4a2' > "$gadget/idProduct"
  printf '0x0200' > "$gadget/bcdUSB"; printf '0x0100' > "$gadget/bcdDevice"
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
  printf '%s' "$udc" > "$gadget/UDC" && echo "gadget bound to $udc"
else
  echo "udc=[$udc] existing binding=[$(cat "$gadget/UDC" 2>/dev/null)]"
fi
netif=
for i in $(seq 1 10); do
  for p in /sys/class/net/*; do [ "$(cat "$p/address" 2>/dev/null)" = "$devmac" ] && netif=$(basename "$p"); done
  [ -n "$netif" ] && break; sleep 1
done
if [ -n "$netif" ]; then ip address replace 172.31.255.2/30 dev "$netif"; ip link set "$netif" up; echo "net: $netif up"; else echo "net: no interface"; fi
if [ -f "$dbdir/dropbear.pid" ] && kill -0 "$(cat "$dbdir/dropbear.pid")" 2>/dev/null; then
  echo "dropbear already running pid $(cat "$dbdir/dropbear.pid")"
else
  [ -f "$dbdir/host_ed25519" ] || "$dbdir/dropbearmulti" dropbearkey -t ed25519 -f "$dbdir/host_ed25519"
  "$dbdir/dropbearmulti" dropbear -r "$dbdir/host_ed25519" -p 22 -P "$dbdir/dropbear.pid"
  sleep 1; echo "dropbear started pid $(cat "$dbdir/dropbear.pid" 2>/dev/null)"
fi
echo "usbssh-boot done: uptime=$(cut -d' ' -f1 /proc/uptime)"
sync
exit 0
