# Jacob's side: copy the current client patch + addon into this repo, rebuild the manifest, commit and push.
# Run via D:\Games\Azeroth-core\PUBLISH-PATCH.bat
$ErrorActionPreference = 'Stop'
$Repo   = $PSScriptRoot
$Game   = 'D:\Games\Wow335-AzerothCore'
$Client = Join-Path $Repo 'client'

Set-Location $Repo

# 1. Mirror the files friends need from your own game folder.
Copy-Item (Join-Path $Game 'Data\patch-4.MPQ') (Join-Path $Client 'Data\patch-4.MPQ') -Force
$addonSrc = Join-Path $Game 'Interface\AddOns\SoloAdventurer'
$addonDst = Join-Path $Client 'Interface\AddOns\SoloAdventurer'
if (Test-Path $addonDst) { Remove-Item $addonDst -Recurse -Force }
Copy-Item $addonSrc $addonDst -Recurse

# 2. Manifest: one "SHA256  relative\path" line per file. The updater only downloads what differs.
$lines = Get-ChildItem $Client -Recurse -File | Sort-Object FullName | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash, $_.FullName.Substring($Client.Length + 1)
}
Set-Content -Path (Join-Path $Repo 'manifest.txt') -Value $lines -Encoding ASCII

git add -A client manifest.txt
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Nothing changed since the last publish. Your friends are already up to date.' -ForegroundColor Green
    exit 0
}
Write-Host 'Changed files:' -ForegroundColor Cyan
git diff --cached --name-status -- client

# 3. A one-line note friends see when they update.
Write-Host ''
$note = Read-Host 'What changed? (one line, shown to friends; Enter to skip)'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$msg = if ($note) { $note } else { 'Patch update' }
$changesFile = Join-Path $Repo 'CHANGES.txt'
$old = if (Test-Path $changesFile) { Get-Content $changesFile } else { @() }
Set-Content -Path $changesFile -Value (@("$stamp  $msg") + $old) -Encoding UTF8
git add CHANGES.txt

git commit -q -m "$msg"
if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
git push -q origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed (check your GitHub login / internet)' }
Write-Host ''
Write-Host 'Published. Friends get it next time they run UPDATE-WOW.bat.' -ForegroundColor Green
