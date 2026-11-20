# Copies the USB-SSH payload and launcher onto the EmuELEC games partition (card in a PC reader).
# Usage (normal PowerShell, from the repo root):  powershell -ExecutionPolicy Bypass -File windows\install-to-card.ps1 -Drive F
param([string]$Drive = 'F', [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$pubPath = Join-Path $env:USERPROFILE '.ssh\emuelec_ed25519.pub'
if (-not (Test-Path $pubPath)) { throw "No client key. Run windows\new-key.cmd first." }

# 1. Verify binaries against bin\SHA256SUMS
foreach ($line in Get-Content (Join-Path $repo 'bin\SHA256SUMS')) {
  $want, $name = $line -split '\s+', 2
  $have = (Get-FileHash (Join-Path $repo "bin\$name")).Hash.ToLower()
  if ($have -ne $want) { throw "bin\$name hash mismatch: $have" }
  "hash OK  bin\$name"
}
if ($CheckOnly) { return }

# 2. Confirm the target really is the games partition
$vol = Get-Volume -DriveLetter $Drive
if ($vol.FileSystemLabel -ne 'EEROMS') { throw "${Drive}: is labelled '$($vol.FileSystemLabel)', not EEROMS. Aborting." }
$root = "${Drive}:\"

# 3. Back up ports_scripts
$bk = Join-Path $env:USERPROFILE ('EmuELEC-card-backup-' + (Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Force $bk | Out-Null
if (Test-Path "$root\ports_scripts") { Copy-Item "$root\ports_scripts\*" $bk -Recurse }
"backup   $bk"
$gl = "$root\ports_scripts\gamelist.xml"
$glHash = if (Test-Path $gl) { (Get-FileHash $gl).Hash } else { $null }

# 4. Payload into <card>\.usbssh (outside ports_scripts; gamelist.xml is never edited)
$pay = "$root\.usbssh"
New-Item -ItemType Directory -Force $pay | Out-Null
Copy-Item (Join-Path $repo 'bin\dropbearmulti') $pay -Force
Copy-Item (Join-Path $repo 'bin\sftp-server') $pay -Force
Copy-Item (Join-Path $repo 'handheld\usbssh-boot.sh') $pay -Force
Copy-Item (Join-Path $repo 'handheld\usbssh.service') $pay -Force
[IO.File]::WriteAllText("$pay\authorized_keys", ((Get-Content $pubPath -Raw).Trim() + "`n"), (New-Object Text.UTF8Encoding $false))

# 5. Launcher (replaces an existing file of the same name if present)
New-Item -ItemType Directory -Force "$root\ports_scripts" | Out-Null
Copy-Item (Join-Path $repo 'handheld\Start USB SSH.sh') "$root\ports_scripts\Start USB SSH.sh" -Force
Write-VolumeCache -DriveLetter $Drive

# 6. Verify what landed
$map = [ordered]@{ 'dropbearmulti' = 'bin\dropbearmulti'; 'sftp-server' = 'bin\sftp-server'; 'usbssh-boot.sh' = 'handheld\usbssh-boot.sh'; 'usbssh.service' = 'handheld\usbssh.service' }
foreach ($f in $map.Keys) {
  $ok = (Get-FileHash "$pay\$f").Hash -eq (Get-FileHash (Join-Path $repo $map[$f])).Hash
  "{0,-16} {1}" -f $f, $(if ($ok) {'copied OK'} else {'MISMATCH'})
  if (-not $ok) { throw "$f did not copy correctly" }
}
foreach ($f in "$root\ports_scripts\Start USB SSH.sh", "$pay\usbssh-boot.sh", "$pay\usbssh.service") {
  $cr = ([IO.File]::ReadAllBytes($f) | Where-Object { $_ -eq 13 }).Count
  if ($cr) { throw "$f contains Windows line endings ($cr CR bytes)" }
}
"line endings OK (LF)"
if ($glHash) { "gamelist.xml unchanged: " + ((Get-FileHash $gl).Hash -eq $glHash) }
"Done. Eject the card safely, put it in the handheld, boot, connect USB-C (data port) and run Ports > Start USB SSH once."
