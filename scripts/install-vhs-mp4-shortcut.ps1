[CmdletBinding()]
param(
    [string]$DesktopPath = ([Environment]::GetFolderPath("DesktopDirectory"))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$launcherPath = Join-Path $PSScriptRoot "optimize-vhs-mp4-gui.bat"
$iconPath = Join-Path $projectRoot "assets\vhs-mp4-optimizer.ico"
$shortcutPath = Join-Path $DesktopPath "VHS MP4 Optimizer.lnk"

if (-not (Test-Path -LiteralPath $launcherPath)) {
    throw "Launcher nije pronadjen: $launcherPath"
}

if (-not (Test-Path -LiteralPath $iconPath)) {
    throw "Ikona nije pronadjena: $iconPath"
}

if (-not (Test-Path -LiteralPath $DesktopPath)) {
    $null = New-Item -ItemType Directory -Path $DesktopPath -Force
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcherPath
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.IconLocation = $iconPath
$shortcut.Description = "VHS MP4 Optimizer"
$shortcut.Save()

Write-Host "Shortcut: $shortcutPath"
Write-Host "Target: $launcherPath"
Write-Host "Icon: $iconPath"
