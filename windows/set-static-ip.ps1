# Run ONCE in an elevated PowerShell (Run as administrator) while the handheld is connected and the gadget is up.
# Finds the handheld's RNDIS adapter by its host-side MAC and gives it 172.31.255.1/30.
$ErrorActionPreference = 'Stop'
$a = Get-NetAdapter | Where-Object MacAddress -eq '02-77-00-00-00-01'
if (-not $a) { throw 'Handheld adapter (MAC 02-77-00-00-00-01) not found. Is the handheld connected and Start USB SSH run?' }
"Adapter: $($a.Name) / $($a.InterfaceDescription)"
Set-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -Dhcp Disabled
if (-not (Get-NetIPAddress -InterfaceIndex $a.ifIndex -IPAddress 172.31.255.1 -ErrorAction SilentlyContinue)) {
  New-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -IPAddress 172.31.255.1 -PrefixLength 30 | Out-Null
}
Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 | Format-Table IPAddress,PrefixLength,PrefixOrigin
