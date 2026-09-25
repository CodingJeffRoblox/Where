<#
  Where - publish a GitHub Release from files you've already built.

  Run it through make-release.bat (double-click), or:
    powershell -ExecutionPolicy Bypass -File scripts\make-release.ps1 [-Version 0.4.0] [-Fetch] [-Draft] [-Yes]

  What it does
    1. Works out the version (from Cargo.toml unless you pass -Version).
    2. Checks the GitHub CLI (installs it with winget if missing, then signs in).
    3. Gathers the release files into dist\v<version>\ :
         - Windows: portable zip (+ installer if Inno Setup is available) from the
           app built by start-where.bat
         - the browser extension zip
         - anything you put in release-files\  (e.g. Mac .dmg, Linux .AppImage/.deb
           built on those computers)
         - with -Fetch: the Mac and Linux files GitHub already built for this tag
    4. Reads the notes from docs\releases\v<version>.md (or release-notes-v<version>.md).
       The first "# Title" line becomes the release title.
    5. Creates the release, or updates it (title, notes, files) if it already exists.
#>
param(
  [string]$Version,
  [switch]$Fetch,
  [switch]$Draft,
  [switch]$Yes
)

# 'Continue': Windows PowerShell 5.1 treats a native tool's stderr as an error
# under 'Stop'. Failures are checked explicitly with $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Head($t) { Write-Host ""; Write-Host "  $t" -ForegroundColor White }
function Ok($t)   { Write-Host "    OK  $t" -ForegroundColor Green }
function Work($t) { Write-Host "    ..  $t" -ForegroundColor Cyan }
function Warn($t) { Write-Host "    !!  $t" -ForegroundColor Yellow }
function Fail($t) { Write-Host "    XX  $t" -ForegroundColor Red; exit 1 }
function Ask($q)  {
  if ($Yes) { return $true }
  $a = Read-Host "    $q [Y/n]"
  return ($a -eq '' -or $a -match '^[Yy]')
}

Write-Host ""
Write-Host "  W H E R E   release maker" -ForegroundColor White
Write-Host "  ---------------------------------------------------" -ForegroundColor DarkGray

# ---------------------------------------------------------------- version ----
if (-not $Version) {
  $m = Select-String -Path (Join-Path $Root 'Cargo.toml') -Pattern '^version = "(.*)"' | Select-Object -First 1
  if (-not $m) { Fail "Couldn't read the version from Cargo.toml. Pass it: make-release.bat 0.4.0" }
  $Version = $m.Matches[0].Groups[1].Value
}
$Version = $Version.TrimStart('v')
$Tag = "v$Version"
Head "Release $Tag"

# ------------------------------------------------------------- GitHub CLI ----
Head "[1/5] Checking the GitHub CLI"
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  Work "Installing the GitHub CLI..."
  winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
  $env:Path += ";$env:ProgramFiles\GitHub CLI"
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Fail "GitHub CLI installed but not found yet. Close this window and run make-release.bat again." }
}
gh auth status 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Work "Sign in to GitHub (use the CodingJeffRoblox account)..."
  gh auth login --web --git-protocol https
  if ($LASTEXITCODE -ne 0) { Fail "GitHub sign-in didn't finish." }
}
Ok "GitHub CLI ready"

# -------------------------------------------------------------- the files ----
Head "[2/5] Gathering the files"
$Dist = Join-Path $Root "dist\$Tag"
if (Test-Path $Dist) { Remove-Item -Recurse -Force $Dist }
New-Item -ItemType Directory -Force $Dist | Out-Null
$Temp = Join-Path ([IO.Path]::GetTempPath()) ("where-release-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $Temp | Out-Null

# Windows: portable zip + installer from the start-where.bat build
$WinOut = Join-Path $Root 'apps\where_flutter\build\windows\x64\runner\Release'
if (Test-Path (Join-Path $WinOut 'Where.exe')) {
  $built = (Get-Item (Join-Path $WinOut 'Where.exe')).LastWriteTime
  Work "Windows app found (built $built)"
  # A running Where locks its files, so close it before copying.
  $running = Get-Process -Name 'Where' -ErrorAction SilentlyContinue
  if ($running) {
    Work "Closing Where so its files can be updated..."
    $running | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
  }
  foreach ($name in 'where_ffi.dll', 'where-cli.exe') {
    $src = Join-Path $Root "target\release\$name"
    if (-not (Test-Path $src)) { continue }
    try { Copy-Item $src $WinOut -Force -ErrorAction Stop }
    catch { Warn "Couldn't update $name (in use?) - using the copy already next to Where.exe." }
  }
  if (-not (Test-Path (Join-Path $WinOut 'where_ffi.dll'))) { Fail "where_ffi.dll is missing next to Where.exe. Run start-where.bat first." }
  # Microsoft C++ runtime, so Where starts on PCs without the redistributable.
  foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    $src = Join-Path $env:WINDIR "System32\$dll"
    if (Test-Path $src) { Copy-Item $src $WinOut -Force }
  }
  $ext = Join-Path $WinOut 'browser-extension'
  if (Test-Path $ext) { Remove-Item -Recurse -Force $ext }
  Copy-Item -Recurse (Join-Path $Root 'browser-extension') $ext

  $stage = Join-Path $Temp 'Where'
  Copy-Item -Recurse $WinOut $stage
  Compress-Archive -Path $stage -DestinationPath (Join-Path $Dist "Where-$Version-windows-x64-portable.zip") -Force
  Ok "Where-$Version-windows-x64-portable.zip"

  $iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $iscc -and (Ask "Make the Windows installer too? This installs Inno Setup (free) once.")) {
    winget install --id JRSoftware.InnoSetup -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
    $iscc = @(
      "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
      "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
      "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  }
  if ($iscc) {
    Work "Building the installer..."
    & $iscc /Qp "/DAppVersion=$Version" "/DSourceDir=$stage" "/DOutDir=$Dist" `
      "/DIconFile=$Root\apps\where_flutter\windows\runner\resources\app_icon.ico" `
      (Join-Path $Root 'installer\windows\where.iss') | Out-Null
    if ($LASTEXITCODE -eq 0) { Ok "Where-Setup-$Version-windows-x64.exe" } else { Warn "The installer didn't build - continuing with the portable zip." }
  } else {
    Warn "Skipping the installer (Inno Setup not installed)."
  }
} else {
  Warn "No Windows build found - run start-where.bat first to include Windows files."
}

# Browser extension
Compress-Archive -Path (Join-Path $Root 'browser-extension\*') -DestinationPath (Join-Path $Dist "Where-$Version-browser-extension.zip") -Force
Ok "Where-$Version-browser-extension.zip"

# Files GitHub already built for this tag (Mac, Linux, ...)
if ($Fetch) {
  Work "Looking for GitHub's builds of $Tag..."
  $runs = gh run list --workflow release.yml --limit 30 --json databaseId,headBranch,status,conclusion | ConvertFrom-Json
  $run = $runs | Where-Object { $_.headBranch -eq $Tag -and $_.status -eq 'completed' } | Select-Object -First 1
  if (-not $run) {
    Warn "No finished build for $Tag on GitHub yet (check: gh run list --workflow release.yml)."
  } else {
    $dl = Join-Path $Temp 'ci'
    gh run download $run.databaseId --dir $dl
    $picked = 0
    Get-ChildItem -Recurse -File $dl | ForEach-Object {
      $dest = Join-Path $Dist $_.Name
      if (-not (Test-Path $dest)) { Copy-Item $_.FullName $dest; $picked++ }
    }
    Ok "Added $picked file(s) from GitHub's build (run $($run.databaseId), $($run.conclusion))"
  }
}

# Anything you built elsewhere and dropped into release-files\
$extra = Join-Path $Root 'release-files'
if (Test-Path $extra) {
  $n = 0
  Get-ChildItem -File $extra | ForEach-Object { Copy-Item $_.FullName (Join-Path $Dist $_.Name) -Force; $n++ }
  if ($n) { Ok "Added $n file(s) from release-files\" }
} else {
  New-Item -ItemType Directory -Force $extra | Out-Null
}

$files = @(Get-ChildItem -File $Dist | Sort-Object Name)
if ($files.Count -eq 0) { Fail "No files to release." }

# ------------------------------------------------------------------ notes ----
Head "[3/5] Release notes"
$notesSrc = @(
  (Join-Path $Root "docs\releases\$Tag.md"),
  (Join-Path $Root "release-notes-$Tag.md"),
  (Join-Path $env:USERPROFILE "Downloads\release-notes-$Tag.md")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$Title = "Where $Version"
$notesFile = Join-Path $Temp 'notes.md'
if ($notesSrc) {
  $lines = [IO.File]::ReadAllLines($notesSrc, [Text.Encoding]::UTF8)
  if ($lines.Count -gt 0 -and $lines[0] -match '^#\s+(.+)$') {
    $Title = $Matches[1].Trim()
    if ($lines.Count -gt 1) { $lines = $lines[1..($lines.Count - 1)] } else { $lines = @('') }
  }
  [IO.File]::WriteAllLines($notesFile, $lines, (New-Object Text.UTF8Encoding($false)))
  Ok "Using $notesSrc"
} else {
  Warn "No notes file found (docs\releases\$Tag.md) - GitHub will write notes from the commits."
  $notesFile = $null
}
Ok "Title: $Title"

# ---------------------------------------------------------------- confirm ----
Head "[4/5] About to publish"
foreach ($f in $files) { Write-Host ("      {0,-48} {1,8:N1} MB" -f $f.Name, ($f.Length / 1MB)) }
$missing = @()
if (-not ($files.Name -match 'macos')) { $missing += 'Mac' }
if (-not ($files.Name -match 'linux')) { $missing += 'Linux' }
if ($missing.Count) {
  Warn ("No " + ($missing -join ' or ') + " files. Add them to release-files\ or run: make-release.bat -Fetch")
}
if (-not (Ask "Publish these to GitHub as ${Tag}?")) { Write-Host "    Cancelled. Files are in $Dist"; exit 0 }

# ---------------------------------------------------------------- publish ----
Head "[5/5] Publishing"
$paths = $files | ForEach-Object { $_.FullName }

git ls-remote --exit-code --tags origin "refs/tags/$Tag" | Out-Null
if ($LASTEXITCODE -ne 0) {
  Warn "The tag $Tag isn't on GitHub yet."
  if (-not (Ask "Create $Tag on your current commit and push it?")) { Fail "Stopped: the release needs the $Tag tag." }
  git tag -a $Tag -m "Where $Version"
  git push origin $Tag
  if ($LASTEXITCODE -ne 0) { Fail "Couldn't push the tag." }
}

gh release view $Tag 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
  Work "Release $Tag exists - updating its title, notes and files..."
  if ($notesFile) { gh release edit $Tag --title $Title --notes-file $notesFile | Out-Null }
  else { gh release edit $Tag --title $Title | Out-Null }
  gh release upload $Tag @paths --clobber
  if ($LASTEXITCODE -ne 0) { Fail "Uploading files failed." }
} else {
  $ghArgs = @('release', 'create', $Tag) + $paths + @('--title', $Title, '--verify-tag')
  if ($notesFile) { $ghArgs += @('--notes-file', $notesFile) } else { $ghArgs += '--generate-notes' }
  if ($Draft) { $ghArgs += '--draft' }
  & gh @ghArgs
  if ($LASTEXITCODE -ne 0) { Fail "Creating the release failed." }
}

Remove-Item -Recurse -Force $Temp -ErrorAction SilentlyContinue
Ok "Published: https://github.com/CodingJeffRoblox/Where/releases/tag/$Tag"
gh release view $Tag --web | Out-Null