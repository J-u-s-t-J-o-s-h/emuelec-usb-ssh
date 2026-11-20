# Diagnostic: polls every 2 s and logs any PnP device or network adapter that appears, disappears or changes.
# Usage: powershell -ExecutionPolicy Bypass -File windows\watch-usb.ps1 -Minutes 20   (log: .\watch-usb.log)
param([int]$Minutes = 20, [string]$Log = (Join-Path (Get-Location) 'watch-usb.log'))
"=== watch started $(Get-Date -Format o) for $Minutes min ===" | Set-Content $Log
function Snap {
  $h = @{}
  foreach ($p in Get-PnpDevice -PresentOnly) { $h[$p.InstanceId] = "$($p.Status)|$($p.Class)|$($p.FriendlyName)" }
  foreach ($n in Get-NetAdapter -IncludeHidden) { $h["NET:" + $n.InterfaceDescription] = "$($n.Status)|$($n.Name)|$($n.MacAddress)" }
  $h
}
$prev = Snap; $end = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $end) {
  Start-Sleep -Seconds 2; $cur = Snap; $ts = Get-Date -Format 'HH:mm:ss'
  foreach ($k in $cur.Keys) {
    if (-not $prev.ContainsKey($k)) { "$ts ADDED   $k  [$($cur[$k])]" | Add-Content $Log }
    elseif ($prev[$k] -ne $cur[$k]) { "$ts CHANGED $k  [$($prev[$k])] -> [$($cur[$k])]" | Add-Content $Log }
  }
  foreach ($k in $prev.Keys) { if (-not $cur.ContainsKey($k)) { "$ts REMOVED $k  [$($prev[$k])]" | Add-Content $Log } }
  $prev = $cur
}
"=== watch ended $(Get-Date -Format o) ===" | Add-Content $Log
