# Solo Adventurer updater. Downloaded and run by UPDATE-WOW.bat in a friend's WoW folder.
# Brings Data\patch-4.MPQ and Interface\AddOns\SoloAdventurer up to date with the latest push.
param([Parameter(Mandatory = $true)][string]$GameDir)

$ErrorActionPreference = 'Stop'
$Repo = 'jwlower/SoloAdventurer-public-patcher'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

function Stop-WithMessage($msg) { Write-Host ''; Write-Host $msg -ForegroundColor Red; exit 1 }

$GameDir = (Resolve-Path $GameDir).Path.TrimEnd('\')
if (-not (Test-Path (Join-Path $GameDir 'Wow.exe'))) {
    Stop-WithMessage 'UPDATE-WOW.bat has to be in your WoW folder, next to Wow.exe. Move it there and run it again.'
}
while (Get-Process -Name 'Wow' -ErrorAction SilentlyContinue) {
    Write-Host 'WoW is running. Close the game, then press Enter.' -ForegroundColor Yellow
    [void][Console]::ReadLine()
}

# Pin everything to the latest commit so a half-cached file can never mix two versions.
try {
    $commit = Invoke-RestMethod "https://api.github.com/repos/$Repo/commits/main" -UseBasicParsing -Headers @{ 'User-Agent' = 'soloadventurer-updater' }
} catch {
    Stop-WithMessage "Couldn't reach GitHub. Check your internet connection and try again.`n($($_.Exception.Message))"
}
$sha = $commit.sha
$base = "https://raw.githubusercontent.com/$Repo/$sha"
$manifest = (Invoke-WebRequest "$base/manifest.txt" -UseBasicParsing).Content -split "`r?`n" | Where-Object { $_ -match '\S' -and $_ -notmatch '^#' }

$wanted = @{}
$changed = @()
foreach ($line in $manifest) {
    $hash, $rel = $line -split '  ', 2
    $wanted[$rel.ToLower()] = $true
    $dest = Join-Path $GameDir $rel
    if ((Test-Path $dest) -and ((Get-FileHash $dest -Algorithm SHA256).Hash -eq $hash)) { continue }

    Write-Host "  downloading $rel"
    $tmp = "$dest.download"
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    $encoded = (($rel -split '\\') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
    $url = "$base/client/$encoded"
    Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
    if ((Get-FileHash $tmp -Algorithm SHA256).Hash -ne $hash) {
        Remove-Item $tmp -Force
        Stop-WithMessage "Download of $rel was corrupted. Run the updater again."
    }
    Move-Item $tmp $dest -Force
    $changed += $rel
}

# Remove addon files Jacob deleted, so stale code can't linger.
$addonDir = Join-Path $GameDir 'Interface\AddOns\SoloAdventurer'
if (Test-Path $addonDir) {
    Get-ChildItem $addonDir -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($GameDir.Length + 1)
        if (-not $wanted.ContainsKey($rel.ToLower())) {
            Remove-Item $_.FullName -Force
            Write-Host "  removed $rel"
            $changed += $rel
        }
    }
}

Write-Host ''
if ($changed.Count -eq 0) {
    Write-Host 'You already have the latest version.' -ForegroundColor Green
} else {
    $cache = Join-Path $GameDir 'Cache'
    if (Test-Path $cache) { Remove-Item $cache -Recurse -Force; Write-Host '  cleared Cache' }
    Write-Host "Updated $($changed.Count) file(s)." -ForegroundColor Green
}

try {
    $notes = (Invoke-WebRequest "$base/CHANGES.txt" -UseBasicParsing).Content.TrimStart([char]0xFEFF) -split "`r?`n" |
        Where-Object { $_ -match '\S' } | Select-Object -First 15
    Write-Host ''
    Write-Host 'Latest changes:' -ForegroundColor Cyan
    $notes | ForEach-Object { Write-Host "  $_" }
} catch { }
